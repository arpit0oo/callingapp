import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/firestore_service.dart';
import '../../services/lead_service.dart';
import '../../services/rtdb_service.dart';
import 'caller_shell.dart';
import 'calling_workspace_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Calling Session Dashboard
// ─────────────────────────────────────────────────────────────────────────────

class CallingDashboardContent extends StatefulWidget {
  const CallingDashboardContent({
    super.key,
    required this.role,
  });

  /// "cold_caller" = raw-lead caller, "warm_caller" = callback caller.
  final String role;

  /// Global key — lets CallingWorkspaceContent call [clearCurrentLead] after submit.
  static final GlobalKey<_CallingDashboardContentState> dashboardKey =
      GlobalKey<_CallingDashboardContentState>();

  @override
  State<CallingDashboardContent> createState() =>
      _CallingDashboardContentState();
}

class _CallingDashboardContentState extends State<CallingDashboardContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary     = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);
  static const _green       = Color(0xFF34A853);
  static const _red         = Color(0xFFD93025);
  static const _orange      = Color(0xFFFA7B17);
  static const _textPrimary   = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _textHint      = Color(0xFF9AA0A6);
  static const _border        = Color(0xFFE8EAED);
  static const _bg            = Color(0xFFF8F9FA);

  // ── Session timer ─────────────────────────────────────────────
  DateTime _sessionStart = DateTime.now();
  Timer? _sessionTimer;
  String _sessionLabel = '00:00';

  // ── Idle detection ────────────────────────────────────────────
  /// Timestamp of the last time the caller had an active lead.
  DateTime _lastActiveAt = DateTime.now();
  static const _warnAfter = Duration(minutes: 3);
  static const _stopAfter = Duration(minutes: 4);
  bool _showIdleWarning = false;

  // ── Session stats ─────────────────────────────────────────────
  int _callsMadeThisSession = 0;

  // ── Current lead ──────────────────────────────────────────────
  Map<String, dynamic>? _currentLead;
  bool _fetchingLead = false;
  /// Active queue bucket for warm callers: 'callback' or 'retry'.
  String _queuePreference = 'callback';

  // ── Stop state ────────────────────────────────────────────────
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _startSessionTimer();
    _writeSessionStart();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  void restartSession() {
    _sessionTimer?.cancel();
    setState(() {
      _sessionStart = DateTime.now();
      _sessionLabel = '00:00';
      _callsMadeThisSession = 0;
      _lastActiveAt = DateTime.now();
      _showIdleWarning = false;
    });
    _startSessionTimer();
    _writeSessionStart();
  }

  // ── Write RTDB on session open ────────────────────────────────
  Future<void> _writeSessionStart() async {
    await RtdbService.updateCallerState(
      AppSession.tenantId,
      AppSession.userId,
      {
        'status': 'in_session',
        'sessionStarted': ServerValue.timestamp,
        'lastSeen': ServerValue.timestamp,
      },
    );
  }

  // ── Session timer ─────────────────────────────────────────────
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_sessionStart);
      final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      final isDashboardVisible =
          CallerShell.shellKey.currentState?.currentIndex == 1;

      setState(() {
        // Always update the session elapsed-time label.
        _sessionLabel = elapsed.inHours > 0
            ? '${elapsed.inHours}:$m:$s'
            : '$m:$s';

        if (!isDashboardVisible) {
          // Caller is on another tab — reset the idle anchor so that time
          // spent away from the Dashboard doesn't count as idle time.
          _lastActiveAt = DateTime.now();
          _showIdleWarning = false;
          return; // skip idle evaluation entirely
        }

        final idle = DateTime.now().difference(_lastActiveAt);
        if (_currentLead == null) {
          _showIdleWarning = idle >= _warnAfter;
          if (idle >= _stopAfter) {
            _autoStopSession();
          }
        } else {
          _showIdleWarning = false;
        }
      });
    });
  }

  // ── Auto-stop on idle timeout ─────────────────────────────────
  Future<void> _autoStopSession() async {
    _sessionTimer?.cancel();
    await _writeSessionRecord(reason: 'idle_timeout');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session ended — idle for 4 minutes.'),
        backgroundColor: _orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    CallerShell.shellKey.currentState?.navigateTo(0);
  }

  // ── Get Next Lead ─────────────────────────────────────────────
  Future<void> _handleGetNextLead() async {
    if (_fetchingLead) return;
    if (AppSession.campaignId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No campaign assigned. Contact your manager.')),
      );
      return;
    }

    setState(() => _fetchingLead = true);
    try {
      final lead = await LeadService.getNextLead(
        AppSession.tenantId,
        AppSession.campaignId,
        AppSession.userId,
        role: AppSession.role,
        queuePreference: widget.role == AppRoles.warmCaller ? _queuePreference : null,
      );
      if (!mounted) return;

      if (lead != null) {
        final leadId = lead['id']?.toString() ?? '';
        await RtdbService.updateCallerState(
          AppSession.tenantId,
          AppSession.userId,
          {
            'status': 'calling',
            'currentLeadId': leadId,
            'lastSeen': ServerValue.timestamp,
          },
        );
        if (!mounted) return;
        setState(() {
          _currentLead = lead;
          _showIdleWarning = false;
        });
        // Also hand the lead to CallerShell so workspace is ready.
        CallerShell.shellKey.currentState?.setCurrentLead(lead);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No leads available in queue.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingLead = false);
    }
  }

  // ── Open Workspace with current lead ─────────────────────────
  void _handleOpenWorkspace() {
    if (_currentLead == null) return;
    RtdbService.updateCallerState(AppSession.tenantId, AppSession.userId, {
      'callStarted': DateTime.now().millisecondsSinceEpoch,
    });
    CallerShell.shellKey.currentState?.setCurrentLead(_currentLead);
    CallingWorkspaceContent.workspaceKey.currentState?.resetTimer();
    CallingWorkspaceContent.workspaceKey.currentState?.refreshSchema();
    CallerShell.shellKey.currentState?.navigateTo(2);
  }

  // ── Called by workspace when a lead is disposed ───────────────
  void onLeadDisposed() {
    setState(() {
      _currentLead = null;
      _callsMadeThisSession++;
      _lastActiveAt = DateTime.now();
    });
    RtdbService.updateCallerState(
      AppSession.tenantId,
      AppSession.userId,
      {
        'status': 'in_session',
        'currentLeadId': '',
        'lastSeen': ServerValue.timestamp,
      },
    );
  }

  /// Called by CallingWorkspaceContent after a successful disposition submit.
  /// Clears the locked lead card and resets idle tracking.
  void clearCurrentLead() {
    if (!mounted) return;
    setState(() {
      _currentLead = null;
      _callsMadeThisSession++;
      _lastActiveAt = DateTime.now();
      _showIdleWarning = false;
    });
  }

  // ── Stop Calling ──────────────────────────────────────────────
  Future<void> _handleStopCalling() async {
    if (_currentLead != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please submit the current lead before stopping.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stop Calling?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17,
                color: _textPrimary)),
        content: Text(
          'This will end your calling session and save your progress.',
          style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600,
                    color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Stop Calling',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                    color: _red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _sessionTimer?.cancel();

    setState(() => _stopping = true);
    await _writeSessionRecord(reason: 'manual');
    if (!mounted) return;
    await RtdbService.updateCallerState(
      AppSession.tenantId,
      AppSession.userId,
      {
        'status': 'on_shift',
        'lastSeen': ServerValue.timestamp,
      },
    );
    if (!mounted) return;
    setState(() => _stopping = false);
    CallerShell.shellKey.currentState?.navigateTo(0);
  }

  // ── Write session record to Firestore ─────────────────────────
  Future<void> _writeSessionRecord({required String reason}) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final docId = '${AppSession.userId}_$dateKey';

    final elapsed = now.difference(_sessionStart);

    await FirebaseFirestore.instance
        .collection('tenants')
        .doc(AppSession.tenantId)
        .collection('caller_activity')
        .doc(docId)
        .set({
      // ── Doc-level identifiers (stable across multiple sessions per day) ──
      'userId':     AppSession.userId,
      'tenantId':   AppSession.tenantId,
      'date':       dateKey,               // 'yyyyMMdd' — for manager date filters
      'campaignId': AppSession.campaignId,
      'updatedAt':  FieldValue.serverTimestamp(),

      // ── Append this session as an entry in the sessions array ────────────
      // arrayUnion ensures each stop/start cycle accumulates without
      // overwriting previous sessions recorded on the same day.
      'sessions': FieldValue.arrayUnion([
        {
          'sessionStart':    Timestamp.fromDate(_sessionStart),
          'sessionEnd':      Timestamp.fromDate(now),   // client time; close enough
          'durationSeconds': elapsed.inSeconds,
          'callsMade':       _callsMadeThisSession,
          'stopReason':      reason,
        }
      ]),
    }, SetOptions(merge: true));

    await RtdbService.updateCallerState(
      AppSession.tenantId,
      AppSession.userId,
      {
        'status': 'idle',
        'currentLeadId': '',
        'lastSeen': ServerValue.timestamp,
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Container(
            color: _bg,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showIdleWarning) ...[
                    _buildIdleWarning(),
                    const SizedBox(height: 16),
                  ],
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildActionCard(),
                  const SizedBox(height: 20),
                  if (_currentLead != null) _buildLockedLeadCard(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      child: Row(
        children: [
          // Session timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  _sessionLabel,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'Calling Session',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Stop button
          _stopping
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : OutlinedButton(
                  onPressed: _handleStopCalling,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'Stop Calling',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Idle warning banner ───────────────────────────────────────
  Widget _buildIdleWarning() {
    final idle = DateTime.now().difference(_lastActiveAt);
    final remaining = _stopAfter - idle;
    final remSec = remaining.inSeconds.clamp(0, 60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You\'ve been idle for a while. Session auto-stops in ${remSec}s.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _orange),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final campaignLabel = AppSession.campaignName.isNotEmpty
        ? AppSession.campaignName
        : AppSession.campaignId.isNotEmpty
            ? AppSession.campaignId
            : 'No Campaign';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.call_outlined,
            iconColor: _primary,
            value: '$_callsMadeThisSession',
            label: 'Calls This Session',
          ),
        ),
        const SizedBox(width: 12),
        // Queue count from Firestore based on role
        if (widget.role == AppRoles.coldCaller)
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: AppSession.campaignId.isEmpty
                  ? null
                  : FirestoreService.rawNumbersDoc(
                      AppSession.tenantId,
                      AppSession.campaignId,
                      'unfiltered',
                    ).snapshots(),
              builder: (context, snap) {
                String queueVal = '—';
                if (snap.hasData) {
                  if (snap.data!.exists) {
                    final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                    final list = data['numbers'] as List<dynamic>?;
                    queueVal = '${list?.length ?? 0}';
                  } else {
                    queueVal = '0';
                  }
                }
                return _StatCard(
                  icon: Icons.queue_outlined,
                  iconColor: _green,
                  value: queueVal,
                  label: 'Queue Remaining',
                );
              },
            ),
          )
        else if (widget.role == AppRoles.warmCaller)
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
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
                    String queueVal = '—';
                    if (callbackSnap.hasData && retrySnap.hasData) {
                      int cbLen = 0;
                      int retryLen = 0;

                      if (callbackSnap.data!.exists) {
                        final cbData = callbackSnap.data!.data() as Map<String, dynamic>? ?? {};
                        cbLen = (cbData['numbers'] as List<dynamic>?)?.length ?? 0;
                      }
                      if (retrySnap.data!.exists) {
                        final retryData = retrySnap.data!.data() as Map<String, dynamic>? ?? {};
                        retryLen = (retryData['numbers'] as List<dynamic>?)?.length ?? 0;
                      }

                      queueVal = '${cbLen + retryLen}';
                    }

                    return _StatCard(
                      icon: Icons.queue_outlined,
                      iconColor: _green,
                      value: queueVal,
                      label: 'Queue Remaining',
                    );
                  },
                );
              },
            ),
          )
        else
          Expanded(
            child: _StatCard(
              icon: Icons.queue_outlined,
              iconColor: _green,
              value: '—',
              label: 'Queue Remaining',
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.campaign_outlined,
            iconColor: _orange,
            value: campaignLabel,
            label: 'Campaign',
            isText: true,
          ),
        ),
      ],
    );
  }

  // ── Action card (Get Next Lead / locked state) ────────────────
  Widget _buildActionCard() {
    if (_currentLead != null) {
      // Lead already locked — show Open Workspace button
      return _buildOpenWorkspaceButton();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.role == AppRoles.warmCaller) ...[
          _buildQueueSelector(),
          const SizedBox(height: 12),
        ],
        _GetNextLeadButton(
          role: widget.role,
          queuePreference: _queuePreference,
          loading: _fetchingLead,
          onTap: _handleGetNextLead,
        ),
      ],
    );
  }

  // ── Queue selector (warm callers only) ───────────────────────
  Widget _buildQueueSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _QueueChip(
              label: 'Callbacks',
              icon: Icons.phone_callback_outlined,
              selected: _queuePreference == 'callback',
              onTap: () => setState(() => _queuePreference = 'callback'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _QueueChip(
              label: 'Retries',
              icon: Icons.replay_outlined,
              selected: _queuePreference == 'retry',
              onTap: () => setState(() => _queuePreference = 'retry'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Locked lead card ──────────────────────────────────────────
  Widget _buildLockedLeadCard() {
    final phone = _currentLead?['phone']?.toString() ?? '—';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final initials = digits.length >= 2
        ? digits.substring(digits.length - 2)
        : (digits.isNotEmpty ? digits : '?');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Lead Locked',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppSession.campaignName.isNotEmpty
                          ? AppSession.campaignName
                          : 'Campaign',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Place Call button ──────────────────────────────────────
  Widget _buildOpenWorkspaceButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _handleOpenWorkspace,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: _green.withOpacity(0.35),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_in_talk_outlined, size: 20),
            const SizedBox(width: 8),
            Text(
              'Place Call →',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Get Next Lead button
// ─────────────────────────────────────────────────────────────────────────────

class _GetNextLeadButton extends StatefulWidget {
  const _GetNextLeadButton({
    required this.role,
    required this.queuePreference,
    required this.loading,
    required this.onTap,
  });

  final String role;
  /// Used to display 'Get Next Callback' or 'Get Next Retry' for warm callers.
  final String queuePreference;
  final bool loading;
  final VoidCallback onTap;

  @override
  State<_GetNextLeadButton> createState() => _GetNextLeadButtonState();
}

class _GetNextLeadButtonState extends State<_GetNextLeadButton> {
  bool _hovered = false;
  bool _pressed = false;

  static const _primary     = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.loading
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.loading ? null : widget.onTap,
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
              if (!widget.loading)
                BoxShadow(
                  color: _primary.withOpacity(_hovered ? 0.35 : 0.20),
                  blurRadius: _hovered ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  widget.role == AppRoles.warmCaller
                      ? 'Get Next ${widget.queuePreference == 'callback' ? 'Callback' : 'Retry'} →'
                      : 'Get Next Lead →',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.isText = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  /// When true, renders [value] as smaller text (for long strings like campaign name).
  final bool isText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: isText ? 12 : 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF202124),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Queue chip (warm-caller selector)
// ─────────────────────────────────────────────────────────────────────────────

class _QueueChip extends StatelessWidget {
  const _QueueChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const _primary = Color(0xFF1A73E8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF9AA0A6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF5F6368),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
