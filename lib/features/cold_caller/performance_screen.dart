import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/rtdb_service.dart';
import '../../shared/widgets/recent_call_row.dart';
import '../auth/login_screen.dart';

/// Performance screen — shared by Cold Caller (role="cold") and Warm Caller (role="warm").
class PerformanceContent extends StatefulWidget {
  const PerformanceContent({super.key, required this.role});

  /// "cold" = raw-lead caller, "warm" = callback caller.
  final String role;

  @override
  State<PerformanceContent> createState() => _PerformanceContentState();
}

class _PerformanceContentState extends State<PerformanceContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary    = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);
  static const _textPrimary = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _bg = Color(0xFFF8F9FA);

  // ── Period dropdown ───────────────────────────────────────────
  final _periods = ['Today', 'This Week', 'This Month'];
  String _selectedPeriod = 'Today';

  // ── Loading / data state ──────────────────────────────────────
  bool _loading = true;

  // Computed KPIs
  List<_KpiData> _kpis = [];

  // Computed disposition breakdown
  List<_DispoData> _dispos = [];

  // Recent calls (last 5)
  List<CallData> _recentCalls = [];

  // ── Shift timer ───────────────────────────────────────────────
  Timer? _shiftTimer;
  String _shiftDuration = '';
  String _shiftStartLabel = '';

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Future<void> _initShiftTimer() async {
    try {
      final ref = FirebaseDatabase.instance
          .ref('caller_state/${AppSession.tenantId}/${AppSession.userId}');
      final snap = await ref.get();
      if (!mounted) return;
      final data = snap.value as Map<dynamic, dynamic>?;
      final startedMs = data?['shiftStarted'] as int?;
      if (startedMs != null) {
        final started = DateTime.fromMillisecondsSinceEpoch(startedMs);
        final hour = started.hour;
        final minute = started.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        setState(() {
          _shiftStartLabel = 'Started at $displayHour:$minute $period';
          _shiftDuration = _formatDuration(DateTime.now().difference(started));
        });
        _shiftTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          if (mounted) {
            setState(() {
              _shiftDuration =
                  _formatDuration(DateTime.now().difference(started));
            });
          }
        });
      }
    } catch (e) {
      debugPrint('ShiftTimer error: $e');
    }
  }

  // ── End Shift ─────────────────────────────────────────────────

  Future<void> _handleEndShift() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'End Shift?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: const Color(0xFF202124),
          ),
        ),
        content: Text(
          'Are you sure you want to end your shift?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF5F6368),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5F6368),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'End Shift',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD93025),
              ),
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
        'status': 'offline',
        'lastSeen': ServerValue.timestamp,
      },
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Data loading ──────────────────────────────────────────────

  /// Returns the DateTime range [from, to] for the selected period.
  (DateTime from, DateTime to) _getPeriodRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'This Week':
        return (now.subtract(const Duration(days: 7)), now);
      case 'This Month':
        return (now.subtract(const Duration(days: 30)), now);
      case 'Today':
      default:
        final todayStart = DateTime(now.year, now.month, now.day);
        return (todayStart, now);
    }
  }

  Color _dispoColor(String label) {
    final dl = label.toLowerCase();
    if (dl == 'interested') return const Color(0xFF34A853);
    if (dl == 'wtl' || dl == 'cbl') return const Color(0xFF1A73E8);
    if (dl == 'dnc') return const Color(0xFFD93025);
    return const Color(0xFF9AA0A6);
  }

  (Color, Color) _chipColors(String label) {
    final dl = label.toLowerCase();
    if (dl == 'interested') {
      return (const Color(0xFFE6F4EA), const Color(0xFF137333));
    } else if (dl == 'wtl' || dl == 'cbl') {
      return (const Color(0xFFE8F0FE), const Color(0xFF1A73E8));
    } else if (dl == 'dnc') {
      return (const Color(0xFFFCE8E6), const Color(0xFFD93025));
    } else {
      return (const Color(0xFFF1F3F4), const Color(0xFF5F6368));
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);

    try {
      final (from, to) = _getPeriodRange();

      // Query disposed leads for this user within the period
      final snapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('leads')
          .where('assignedTo', isEqualTo: AppSession.userId)
          .where('status', isEqualTo: 'disposed')
          .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('updatedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .orderBy('updatedAt', descending: true)
          .get();

      final docs = snapshot.docs;

      // ── Compute stats ────────────────────────────────────────
      final callsMade = docs.length;
      int leadsGenerated = 0;
      int callbacks = 0;
      final Map<String, int> dispoBreakdown = {};

      for (final doc in docs) {
        final data = doc.data();
        final label = (data['dispositionLabel'] as String? ?? '').trim();
        if (label.isEmpty) continue;

        // Count by disposition
        dispoBreakdown[label] = (dispoBreakdown[label] ?? 0) + 1;

        final dl = label.toLowerCase();
        if (dl == 'interested') leadsGenerated++;
        if (dl == 'wtl' || dl == 'cbl') callbacks++;
      }

      // ── Build KPI list ───────────────────────────────────────
      final List<_KpiData> kpis;
      if (widget.role == 'warm') {
        kpis = [
          _KpiData(label: 'Callbacks Made',  value: callsMade.toString(),       icon: Icons.call_outlined,         iconColor: const Color(0xFF7B61FF)),
          _KpiData(label: 'Converted',       value: leadsGenerated.toString(),  icon: Icons.person_add_outlined,   iconColor: const Color(0xFF34A853)),
          _KpiData(label: 'Rescheduled',     value: callbacks.toString(),       icon: Icons.event_outlined,        iconColor: const Color(0xFF1A73E8)),
          _KpiData(label: 'Avg Handle Time', value: '—',                        icon: Icons.timer_outlined,        iconColor: const Color(0xFF9334E6)),
          _KpiData(label: 'Talk Time',       value: '—',                        icon: Icons.headset_mic_outlined,  iconColor: const Color(0xFF7B61FF)),
          _KpiData(label: 'Conversion Rate', value: '—',                        icon: Icons.trending_up_outlined,  iconColor: const Color(0xFF34A853)),
        ];
      } else {
        kpis = [
          _KpiData(label: 'Calls Made',      value: callsMade.toString(),       icon: Icons.call_outlined,         iconColor: const Color(0xFF1A73E8)),
          _KpiData(label: 'Leads Generated', value: leadsGenerated.toString(),  icon: Icons.person_add_outlined,   iconColor: const Color(0xFF34A853)),
          _KpiData(label: 'Callbacks',       value: callbacks.toString(),       icon: Icons.event_outlined,        iconColor: const Color(0xFFFBBC04)),
          _KpiData(label: 'Avg Handle Time', value: '—',                        icon: Icons.timer_outlined,        iconColor: const Color(0xFF9334E6)),
          _KpiData(label: 'Talk Time',       value: '—',                        icon: Icons.headset_mic_outlined,  iconColor: const Color(0xFF1A73E8)),
          _KpiData(label: 'Conversion Rate', value: '—',                        icon: Icons.trending_up_outlined,  iconColor: const Color(0xFF34A853)),
        ];
      }

      // ── Build disposition breakdown ──────────────────────────
      final dispos = dispoBreakdown.entries
          .map((e) => _DispoData(
                label: e.key,
                count: e.value,
                color: _dispoColor(e.key),
              ))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      // ── Build recent calls (top 5 already ordered by updatedAt desc) ─
      final recentDocs = docs.take(5);
      final recentCalls = recentDocs.map((doc) {
        final data = doc.data();
        final phone = data['phone']?.toString() ?? '—';
        final disposition = (data['dispositionLabel']?.toString() ?? '—').trim();

        String time = '';
        final updatedAt = data['updatedAt'];
        if (updatedAt != null) {
          DateTime? dt;
          if (updatedAt is Timestamp) {
            dt = updatedAt.toDate();
          } else if (updatedAt is int) {
            dt = DateTime.fromMillisecondsSinceEpoch(updatedAt);
          }
          if (dt != null) {
            time =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        }

        final (chipBg, chipFg) = _chipColors(disposition);

        return CallData(
          time: time,
          number: phone,
          disposition: disposition,
          chipBg: chipBg,
          chipFg: chipFg,
          duration: '—',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _kpis = kpis;
        _dispos = dispos;
        _recentCalls = recentCalls;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PerformanceContent _loadStats error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _initShiftTimer();
    _loadStats();
  }

  @override
  void dispose() {
    _shiftTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildShiftCard(),
                        const SizedBox(height: 14),
                        _buildKpiGrid(),
                        const SizedBox(height: 14),
                        if (_dispos.isNotEmpty) ...[
                          _buildDispositionCard(),
                          const SizedBox(height: 14),
                        ],
                        _buildRecentCallsCard(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 56,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'My Performance',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          // Period dropdown
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE8EAED)),
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 16, color: Color(0xFF5F6368)),
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary),
                isDense: true,
                items: _periods
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  if (v != null && v != _selectedPeriod) {
                    setState(() => _selectedPeriod = v);
                    _loadStats();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shift summary card ────────────────────────────────────────

  Widget _buildShiftCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF34A853), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('Shift Active',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _shiftDuration.isNotEmpty ? _shiftDuration : '—',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _handleEndShift,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
          const SizedBox(height: 8),
          Text(
            _shiftStartLabel.isNotEmpty ? _shiftStartLabel : 'Shift start time unavailable',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.75))),
        ],
      ),
    );
  }

  // ── KPI grid (2 × 3) ─────────────────────────────────────────

  Widget _buildKpiGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kpis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, i) => _KpiCard(data: _kpis[i]),
    );
  }

  // ── Disposition breakdown card ────────────────────────────────

  Widget _buildDispositionCard() {
    final maxCount = _dispos.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Disposition Breakdown'),
          const SizedBox(height: 14),
          ..._dispos.map((d) => _DispositionRow(d: d, maxCount: maxCount)),
        ],
      ),
    );
  }

  // ── Recent calls card ─────────────────────────────────────────

  Widget _buildRecentCallsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Recent Calls'),
          const SizedBox(height: 12),
          if (_recentCalls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No recent calls for this period.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _textSecondary,
                ),
              ),
            )
          else
            ..._recentCalls.map((c) => RecentCallRow(call: c)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI card
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, size: 20, color: data.iconColor),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.value,
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124),
                      height: 1.1)),
              const SizedBox(height: 2),
              Text(data.label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF9AA0A6),
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disposition bar row
// ─────────────────────────────────────────────────────────────────────────────

class _DispositionRow extends StatelessWidget {
  const _DispositionRow({required this.d, required this.maxCount});
  final _DispoData d;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = d.count / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(d.label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5F6368))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  // Track
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Fill
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: d.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 22,
            child: Text('${d.count}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF202124))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF202124)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
}

class _DispoData {
  const _DispoData(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;
}
