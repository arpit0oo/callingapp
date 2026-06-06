import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Home screen for Cold Caller (role="cold") and Warm Caller (role="warm").
/// Designed as a mobile-first layout, max width 420 px.
class CallerHomeContent extends StatelessWidget {
  const CallerHomeContent({super.key, required this.role});

  /// "cold" = raw-lead caller, "warm" = callback caller.
  final String role;

  // ── Colors ────────────────────────────────────────────────────
  static const _primary = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);
  static const _textPrimary = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _textHint = Color(0xFF9AA0A6);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Blue gradient header ───────────────────────────────
          _buildHeader(),

          // ── KPI cards ─────────────────────────────────────────
          const SizedBox(height: 20),
          _buildKpiSection(),

          // ── Get Next Lead button ───────────────────────────────
          const SizedBox(height: 24),
          _buildGetNextLead(),

          // ── Recent calls ──────────────────────────────────────
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
          // Greeting
          Text(
            'Good Morning, Ravi 👋',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          // Campaign subtitle
          Text(
            role == 'warm'
                ? 'Callbacks — Xpert Tutor'
                : 'Xpert Tutor Campaign',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 16),

          // Shift status row
          Row(
            children: [
              // Green dot
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF34A853),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shift Active — 3h 42m',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              // End Shift button
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70, width: 1.2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'End Shift',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KPI cards ─────────────────────────────────────────────────

  Widget _buildKpiSection() {
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: const [
          _KpiCard(
            icon: Icons.call_outlined,
            iconColor: Color(0xFF1A73E8),
            value: '45',
            label: 'Calls Made',
          ),
          SizedBox(width: 12),
          _KpiCard(
            icon: Icons.person_add_outlined,
            iconColor: Color(0xFF34A853),
            value: '8',
            label: 'Leads Generated',
          ),
          SizedBox(width: 12),
          _KpiCard(
            icon: Icons.event_outlined,
            iconColor: Color(0xFFFBBC04),
            value: '3',
            label: 'Callbacks Scheduled',
          ),
          SizedBox(width: 16),
        ],
      ),
    );
  }

  // ── Get Next Lead button ───────────────────────────────────────

  Widget _buildGetNextLead() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GetNextLeadButton(role: role),
          const SizedBox(height: 8),
          Text(
            role == 'warm'
                ? '12 callbacks remaining in queue'
                : '47 leads remaining in queue',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _textHint,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent calls ──────────────────────────────────────────────

  Widget _buildRecentCalls() {
    final calls = role == 'warm'
        ? const [
            _CallLog(time: '09:14', number: '+91 98765 43210', disposition: 'Interested',    chipColor: Color(0xFFE6F4EA), textColor: Color(0xFF137333)),
            _CallLog(time: '09:32', number: '+91 87654 32109', disposition: 'Reschedule',    chipColor: Color(0xFFE8F0FE), textColor: Color(0xFF1A73E8)),
            _CallLog(time: '09:51', number: '+91 76543 21098', disposition: 'Not Interested', chipColor: Color(0xFFF1F3F4), textColor: Color(0xFF5F6368)),
            _CallLog(time: '10:08', number: '+91 65432 10987', disposition: 'DNC',           chipColor: Color(0xFFFCE8E6), textColor: Color(0xFFD93025)),
          ]
        : const [
            _CallLog(time: '09:14', number: '+91 98765 43210', disposition: 'Interested', chipColor: Color(0xFFE6F4EA), textColor: Color(0xFF137333)),
            _CallLog(time: '09:32', number: '+91 87654 32109', disposition: 'No Answer',  chipColor: Color(0xFFF1F3F4), textColor: Color(0xFF5F6368)),
            _CallLog(time: '09:51', number: '+91 76543 21098', disposition: 'WTL',        chipColor: Color(0xFFE8F0FE), textColor: Color(0xFF1A73E8)),
            _CallLog(time: '10:08', number: '+91 65432 10987', disposition: 'Busy',       chipColor: Color(0xFFFEF3E2), textColor: Color(0xFFE37400)),
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Calls',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...calls.map((c) => _CallLogRow(log: c)),
        ],
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
            offset: const Offset(0, 3),
          ),
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
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124),
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9AA0A6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Get Next Lead button with hover/press animation
// ─────────────────────────────────────────────────────────────────────────────

class _GetNextLeadButton extends StatefulWidget {
  const _GetNextLeadButton({required this.role});
  final String role;

  @override
  State<_GetNextLeadButton> createState() => _GetNextLeadButtonState();
}

class _GetNextLeadButtonState extends State<_GetNextLeadButton> {
  bool _hovered = false;
  bool _pressed = false;

  static const _primary = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {},
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
          child: Text(
            widget.role == 'warm' ? 'Get Next Callback →' : 'Get Next Lead →',
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
// Call log data model
// ─────────────────────────────────────────────────────────────────────────────

class _CallLog {
  const _CallLog({
    required this.time,
    required this.number,
    required this.disposition,
    required this.chipColor,
    required this.textColor,
  });

  final String time;
  final String number;
  final String disposition;
  final Color chipColor;
  final Color textColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Call log row widget
// ─────────────────────────────────────────────────────────────────────────────

class _CallLogRow extends StatelessWidget {
  const _CallLogRow({required this.log});
  final _CallLog log;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time
          SizedBox(
            width: 42,
            child: Text(
              log.time,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9AA0A6),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Divider dot
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EAED),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Phone number
          Expanded(
            child: Text(
              log.number,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF202124),
              ),
            ),
          ),

          // Disposition chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: log.chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              log.disposition,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: log.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
