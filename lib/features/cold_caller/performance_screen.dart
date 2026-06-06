import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // ── KPI data ──────────────────────────────────────────────────
  static const _coldKpis = [
    _KpiData(label: 'Calls Made',      value: '45',    icon: Icons.call_outlined,         iconColor: Color(0xFF1A73E8)),
    _KpiData(label: 'Leads Generated', value: '8',     icon: Icons.person_add_outlined,   iconColor: Color(0xFF34A853)),
    _KpiData(label: 'Callbacks',       value: '3',     icon: Icons.event_outlined,        iconColor: Color(0xFFFBBC04)),
    _KpiData(label: 'Avg Handle Time', value: '4m 20s',icon: Icons.timer_outlined,        iconColor: Color(0xFF9334E6)),
    _KpiData(label: 'Talk Time',       value: '2h 15m',icon: Icons.headset_mic_outlined,  iconColor: Color(0xFF1A73E8)),
    _KpiData(label: 'Conversion Rate', value: '17.8%', icon: Icons.trending_up_outlined,  iconColor: Color(0xFF34A853)),
  ];

  static const _warmKpis = [
    _KpiData(label: 'Callbacks Made',  value: '28',    icon: Icons.call_outlined,         iconColor: Color(0xFF7B61FF)),
    _KpiData(label: 'Converted',       value: '11',    icon: Icons.person_add_outlined,   iconColor: Color(0xFF34A853)),
    _KpiData(label: 'Rescheduled',     value: '5',     icon: Icons.event_outlined,        iconColor: Color(0xFF1A73E8)),
    _KpiData(label: 'Avg Handle Time', value: '5m 10s',icon: Icons.timer_outlined,        iconColor: Color(0xFF9334E6)),
    _KpiData(label: 'Talk Time',       value: '2h 48m',icon: Icons.headset_mic_outlined,  iconColor: Color(0xFF7B61FF)),
    _KpiData(label: 'Conversion Rate', value: '39.3%', icon: Icons.trending_up_outlined,  iconColor: Color(0xFF34A853)),
  ];

  List<_KpiData> get _kpis =>
      widget.role == 'warm' ? _warmKpis : _coldKpis;

  // ── Disposition breakdown ─────────────────────────────────────
  static const _coldDispos = [
    _DispoData(label: 'Interested', count: 8,  color: Color(0xFF34A853)),
    _DispoData(label: 'No Answer',  count: 18, color: Color(0xFF9AA0A6)),
    _DispoData(label: 'WTL',        count: 6,  color: Color(0xFF1A73E8)),
    _DispoData(label: 'Busy',       count: 7,  color: Color(0xFFE37400)),
    _DispoData(label: 'No Need',    count: 4,  color: Color(0xFF9AA0A6)),
    _DispoData(label: 'DNC',        count: 2,  color: Color(0xFFD93025)),
  ];

  static const _warmDispos = [
    _DispoData(label: 'Interested',     count: 11, color: Color(0xFF34A853)),
    _DispoData(label: 'Not Interested', count: 8,  color: Color(0xFF9AA0A6)),
    _DispoData(label: 'Reschedule',     count: 5,  color: Color(0xFF1A73E8)),
    _DispoData(label: 'DNC',            count: 4,  color: Color(0xFFD93025)),
  ];

  List<_DispoData> get _dispos =>
      widget.role == 'warm' ? _warmDispos : _coldDispos;

  // ── Recent calls ──────────────────────────────────────────────
  static const _recentCalls = [
    _CallData(time: '10:08', number: '+91 65432 10987', disposition: 'Busy',       chipBg: Color(0xFFFEF3E2), chipFg: Color(0xFFE37400), duration: '1m 02s'),
    _CallData(time: '09:51', number: '+91 76543 21098', disposition: 'WTL',        chipBg: Color(0xFFE8F0FE), chipFg: Color(0xFF1A73E8), duration: '6m 14s'),
    _CallData(time: '09:32', number: '+91 87654 32109', disposition: 'No Answer',  chipBg: Color(0xFFF1F3F4), chipFg: Color(0xFF5F6368), duration: '0m 28s'),
    _CallData(time: '09:14', number: '+91 98765 43210', disposition: 'Interested', chipBg: Color(0xFFE6F4EA), chipFg: Color(0xFF137333), duration: '5m 47s'),
    _CallData(time: '09:02', number: '+91 54321 09876', disposition: 'DNC',        chipBg: Color(0xFFFCE8E6), chipFg: Color(0xFFD93025), duration: '2m 10s'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildShiftCard(),
                  const SizedBox(height: 14),
                  _buildKpiGrid(),
                  const SizedBox(height: 14),
                  _buildDispositionCard(),
                  const SizedBox(height: 14),
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
                onChanged: (v) => setState(() => _selectedPeriod = v!),
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
                child: Text('3h 42m',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
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
          Text('Started at 09:00 AM',
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
          ..._recentCalls.map((c) => _RecentCallRow(call: c)),
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
// Recent call row
// ─────────────────────────────────────────────────────────────────────────────

class _RecentCallRow extends StatelessWidget {
  const _RecentCallRow({required this.call});
  final _CallData call;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Time
          Text(call.time,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9AA0A6))),
          const SizedBox(width: 10),
          // Phone
          Expanded(
            child: Text(call.number,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF202124))),
          ),
          // Duration
          Text(call.duration,
              style: GoogleFonts.inter(
                  fontSize: 11, color: const Color(0xFF9AA0A6))),
          const SizedBox(width: 8),
          // Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: call.chipBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(call.disposition,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: call.chipFg)),
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

class _CallData {
  const _CallData({
    required this.time,
    required this.number,
    required this.disposition,
    required this.chipBg,
    required this.chipFg,
    required this.duration,
  });
  final String time;
  final String number;
  final String disposition;
  final Color chipBg;
  final Color chipFg;
  final String duration;
}
