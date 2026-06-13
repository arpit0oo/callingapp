
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/firestore_service.dart';
import '../../services/rtdb_service.dart';
import '../../shared/widgets/recent_call_row.dart';
import '../auth/login_screen.dart';
import 'caller_shell.dart';

/// Home screen for Cold Caller (role="cold_caller") and Warm Caller (role="warm_caller").
/// Designed as a mobile-first layout, max width 420 px.
class CallerHomeContent extends StatefulWidget {
  const CallerHomeContent({super.key, required this.role});

  /// "cold_caller" = raw-lead caller, "warm_caller" = callback caller.
  final String role;

  @override
  State<CallerHomeContent> createState() => _CallerHomeContentState();
}

class _CallerHomeContentState extends State<CallerHomeContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary      = Color(0xFF1A73E8);
  static const _primaryDark  = Color(0xFF1557B0);
  static const _textPrimary  = Color(0xFF202124);
  static const _textHint     = Color(0xFF9AA0A6);

  // ── Shift start time (fetched once from RTDB) ─────────────────
  DateTime? _shiftStarted;
  /// Local-clock anchor captured the moment shiftStarted arrives from RTDB.
  /// Both this and the logout DateTime.now() use the device clock, so drift
  /// caused by server/device time skew cancels out completely.
  DateTime? _shiftLocalAnchor;

  Future<void> _loadShiftStarted() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('caller_state/${AppSession.tenantId}/${AppSession.userId}')
          .get();
      if (!mounted) return;
      final data = snap.value as Map<dynamic, dynamic>?;
      final startedMs = data?['shiftStarted'] as int?;
      if (startedMs != null) {
        final localAnchor = DateTime.now(); // capture local clock immediately
        setState(() {
          _shiftStarted = DateTime.fromMillisecondsSinceEpoch(startedMs);
          _shiftLocalAnchor = localAnchor;
        });
      }
    } catch (e) {
      debugPrint('ShiftTimer error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadShiftStarted();
  }

  // ── Start Calling ─────────────────────────────────────────────
  Future<void> _handleStartCalling() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Start Calling Session?',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: const Color(0xFF202124)),
        ),
        content: Text(
          'Your session timer will start and you will be tracked. Ready to go?',
          style: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFF5F6368)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Not Yet',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5F6368)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Start Calling',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A73E8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await RtdbService.updateCallerState(
      AppSession.tenantId,
      AppSession.userId,
      {
        'status': 'in_session',
        'sessionStarted': ServerValue.timestamp,
        'lastSeen': ServerValue.timestamp,
      },
    );
    if (!mounted) return;
    CallerShell.shellKey.currentState?.navigateTo(1);
  }

  // ── End Shift ─────────────────────────────────────────────────
  Future<void> _handleEndShift() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End Shift?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF202124))),
        content: Text('Are you sure you want to end your shift?',
            style: GoogleFonts.inter(
                fontSize: 14, color: const Color(0xFF5F6368))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5F6368))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('End Shift',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD93025))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await RtdbService.updateCallerState(
      AppSession.tenantId,
      AppSession.userId,
      {'status': 'offline', 'lastSeen': ServerValue.timestamp},
    );

    // ── Read shiftStarted from RTDB ───────────────────────────
    int shiftStartedMs = 0;
    try {
      final snap = await RtdbService.getCallerState(
          AppSession.tenantId, AppSession.userId);
      final rtdbData = snap.value as Map<dynamic, dynamic>?;
      shiftStartedMs = (rtdbData?['shiftStarted'] as int?) ?? 0;
    } catch (_) {}

    // ── Write shift summary to caller_activity ────────────────
    try {
      final now = DateTime.now();
      final dateKey =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final shiftStartTs = shiftStartedMs > 0
          ? Timestamp.fromMillisecondsSinceEpoch(shiftStartedMs)
          : Timestamp.fromDate(now);
      final durationSeconds = _shiftLocalAnchor != null
          ? now.difference(_shiftLocalAnchor!).inSeconds
          : shiftStartedMs > 0
              ? now
                  .difference(DateTime.fromMillisecondsSinceEpoch(shiftStartedMs))
                  .inSeconds
              : 0;
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('caller_activity')
          .doc('${AppSession.userId}_$dateKey')
          .set({
        'shifts': FieldValue.arrayUnion([
          {
            'shiftStart': shiftStartTs,
            'shiftEnd': Timestamp.fromDate(now),
            'durationSeconds': durationSeconds,
          }
        ]),
      }, SetOptions(merge: true));
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildKpiSection(),
          const SizedBox(height: 24),
          _buildStartCallingSection(),
          const SizedBox(height: 24),
          _buildRecentCalls(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good Morning, ${AppSession.name.isNotEmpty ? AppSession.name : AppSession.userId} 👋',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            widget.role == 'warm_caller'
                ? 'Callbacks — Xpert Tutor'
                : 'Xpert Tutor Campaign',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF34A853), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _shiftStarted != null
                    ? _ShiftTimerText(shiftStarted: _shiftStarted!)
                    : Text(
                        'Shift Active',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      ),
              ),
              OutlinedButton(
                onPressed: _handleEndShift,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text('End Shift',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI section ───────────────────────────────────────────────
  // Reads callsMade, converted, callbacks from caller_stats/{userId}.
  Widget _buildKpiSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('caller_stats')
          .doc(AppSession.userId)
          .snapshots(),
      builder: (context, snapshot) {
        final data =
            (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
        final callsMade   = (data['callsMade']  as num?)?.toInt() ?? 0;
        final converted   = (data['converted']  as num?)?.toInt() ?? 0;
        final callbacks   = (data['callbacks']  as num?)?.toInt() ?? 0;

        return SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _KpiCard(
                  icon: Icons.call_outlined,
                  iconColor: const Color(0xFF1A73E8),
                  value: '$callsMade',
                  label: 'Calls Made'),
              const SizedBox(width: 12),
              _KpiCard(
                  icon: Icons.person_add_outlined,
                  iconColor: const Color(0xFF34A853),
                  value: '$converted',
                  label: 'Leads Generated'),
              const SizedBox(width: 12),
              _KpiCard(
                  icon: Icons.event_outlined,
                  iconColor: const Color(0xFFFBBC04),
                  value: '$callbacks',
                  label: 'Callbacks Scheduled'),
              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }

  // ── Start Calling section ─────────────────────────────────────
  Widget _buildStartCallingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StartCallingButton(
              role: widget.role, onTap: _handleStartCalling),
          const SizedBox(height: 8),
          // Queue count — live stream, role-based (mirrors CallingDashboard logic)
          if (widget.role == AppRoles.coldCaller)
            StreamBuilder<DocumentSnapshot>(
              stream: AppSession.campaignId.isEmpty
                  ? null
                  : FirestoreService.rawNumbersDoc(
                      AppSession.tenantId,
                      AppSession.campaignId,
                      'unfiltered',
                    ).snapshots(),
              builder: (context, snap) {
                int q = 0;
                if (snap.hasData && snap.data!.exists) {
                  final data =
                      snap.data!.data() as Map<String, dynamic>? ?? {};
                  q = (data['numbers'] as List<dynamic>?)?.length ?? 0;
                }
                return Text(
                  snap.hasData ? '$q leads remaining in queue' : '...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _textHint,
                      fontWeight: FontWeight.w400),
                );
              },
            )
          else if (widget.role == AppRoles.warmCaller)
            StreamBuilder<DocumentSnapshot>(
              stream: AppSession.campaignId.isEmpty
                  ? null
                  : FirestoreService.warmNumbersDoc(
                      AppSession.tenantId,
                      AppSession.campaignId,
                      'callback',
                    ).snapshots(),
              builder: (context, callbackSnap) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: AppSession.campaignId.isEmpty
                      ? null
                      : FirestoreService.warmNumbersDoc(
                          AppSession.tenantId,
                          AppSession.campaignId,
                          'retry',
                        ).snapshots(),
                  builder: (context, retrySnap) {
                    int q = 0;
                    final hasBoth =
                        callbackSnap.hasData && retrySnap.hasData;
                    if (hasBoth) {
                      if (callbackSnap.data!.exists) {
                        final d = callbackSnap.data!.data()
                                as Map<String, dynamic>? ??
                            {};
                        q += (d['numbers'] as List<dynamic>?)?.length ?? 0;
                      }
                      if (retrySnap.data!.exists) {
                        final d = retrySnap.data!.data()
                                as Map<String, dynamic>? ??
                            {};
                        q += (d['numbers'] as List<dynamic>?)?.length ?? 0;
                      }
                    }
                    return Text(
                      hasBoth ? '$q leads remaining in queue' : '...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textHint,
                          fontWeight: FontWeight.w400),
                    );
                  },
                );
              },
            )
          else
            Text(
              '— leads remaining in queue',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _textHint,
                  fontWeight: FontWeight.w400),
            ),
        ],
      ),
    );
  }

  // ── Recent Calls ──────────────────────────────────────────────
  // Reads the recentCalls array from caller_stats/{userId}.
  Widget _buildRecentCalls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Calls',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tenants')
                .doc(AppSession.tenantId)
                .collection('caller_stats')
                .doc(AppSession.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }

              final data =
                  (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
              final rawList = data['recentCalls'];
              final entries = rawList is List
                  ? rawList.cast<Map<dynamic, dynamic>>()
                  : <Map<dynamic, dynamic>>[];

              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No recent calls yet.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: _textHint)),
                );
              }

              return Column(
                children: entries.take(5).map((raw) {
                  final entry = Map<String, dynamic>.from(raw);
                  final phone       = entry['phone']?.toString() ?? '—';
                  final disposition = entry['disposition']?.toString() ?? '—';
                  final time        = entry['time']?.toString() ?? '';

                  // Reads from the global map pre-fetched at login.
                  // Falls back to default gray if not found.
                  const _defaultFg = Color(0xFF5F6368);
                  final chipFg = AppSession.dispositionColors[disposition.toLowerCase()] ??
                      _defaultFg;
                  final chipBg = chipFg.withOpacity(0.12);

                  return RecentCallRow(
                    call: CallData(
                      time: time,
                      number: phone,
                      disposition: disposition,
                      chipBg: chipBg,
                      chipFg: chipFg,
                      duration: '',
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shift timer text — isolated StatefulWidget to avoid rebuilding parent tree
// ─────────────────────────────────────────────────────────────────────────────

class _ShiftTimerText extends StatefulWidget {
  const _ShiftTimerText({required this.shiftStarted});
  final DateTime shiftStarted;

  @override
  State<_ShiftTimerText> createState() => _ShiftTimerTextState();
}

class _ShiftTimerTextState extends State<_ShiftTimerText> {
  late Timer _timer;
  late Duration _elapsed;

  /// The server-side shift start timestamp (kept for reference only).
  late DateTime _serverStart;

  /// Local clock reading captured at the moment initState runs.
  /// All elapsed calculations use this anchor to avoid device/server clock drift.
  late DateTime _localAnchor;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h}h ${m}m ${s}s';
  }

  @override
  void initState() {
    super.initState();
    _serverStart  = widget.shiftStarted; // server timestamp — not used for elapsed
    _localAnchor  = DateTime.now();      // local clock at widget creation
    _elapsed      = Duration.zero;       // start from 0, not from server skew
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Always diff against the local anchor — immune to device/server skew.
          _elapsed = DateTime.now().difference(_localAnchor);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Shift Active — ${_fmt(_elapsed)}',
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Calling button with hover/press animation
// ─────────────────────────────────────────────────────────────────────────────

class _StartCallingButton extends StatefulWidget {
  const _StartCallingButton({required this.role, required this.onTap});
  final String role;
  final VoidCallback onTap;

  @override
  State<_StartCallingButton> createState() => _StartCallingButtonState();
}

class _StartCallingButtonState extends State<_StartCallingButton> {
  bool _hovered = false;
  bool _pressed = false;

  static const _primary     = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown:  (_) => setState(() => _pressed = true),
        onTapUp:    (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 56,
          decoration: BoxDecoration(
            color: _pressed
                ? _primaryDark
                : _hovered
                    ? const Color(0xFF1669D0)
                    : _primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(_hovered ? 0.35 : 0.20),
                blurRadius: _hovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_in_talk_outlined,
                  size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                widget.role == 'warm_caller'
                    ? 'Start Calling — Callbacks →'
                    : 'Start Calling →',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI card
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124),
                      height: 1.1)),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9AA0A6))),
            ],
          ),
        ],
      ),
    );
  }
}
