import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/lead_service.dart';
import '../../services/rtdb_service.dart';
import '../auth/login_screen.dart';
import 'caller_shell.dart';

/// Home screen for Cold Caller (role="cold") and Warm Caller (role="warm").
/// Designed as a mobile-first layout, max width 420 px.
class CallerHomeContent extends StatefulWidget {
  const CallerHomeContent({
    super.key,
    required this.role,
  });

  /// "cold" = raw-lead caller, "warm" = callback caller.
  final String role;

  @override
  State<CallerHomeContent> createState() => _CallerHomeContentState();
}

class _CallerHomeContentState extends State<CallerHomeContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);
  static const _textPrimary = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _textHint = Color(0xFF9AA0A6);

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
            'Good Morning, ${AppSession.name.isNotEmpty ? AppSession.name : AppSession.userId} 👋',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          // Campaign subtitle
          Text(
            widget.role == 'warm'
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
                onPressed: _handleEndShift,
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('leads')
          .where('assignedTo', isEqualTo: AppSession.userId)
          .snapshots(),
      builder: (context, snapshot) {
        int callsMade = 0;
        if (snapshot.hasData) {
          callsMade = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'disposed';
          }).length;
        }

        return SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _KpiCard(
                icon: Icons.call_outlined,
                iconColor: const Color(0xFF1A73E8),
                value: callsMade.toString(),
                label: 'Calls Made',
              ),
              const SizedBox(width: 12),
              const _KpiCard(
                icon: Icons.person_add_outlined,
                iconColor: Color(0xFF34A853),
                value: '0',
                label: 'Leads Generated',
              ),
              const SizedBox(width: 12),
              const _KpiCard(
                icon: Icons.event_outlined,
                iconColor: Color(0xFFFBBC04),
                value: '0',
                label: 'Callbacks Scheduled',
              ),
              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }

  // ── Get Next Lead button ───────────────────────────────────────

  Widget _buildGetNextLead() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GetNextLeadButton(
            role: widget.role,
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tenants')
                .doc(AppSession.tenantId)
                .collection('leads')
                .where('campaignId', isEqualTo: AppSession.campaignId)
                .where('status', isEqualTo: 'raw')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Text(
                  '...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _textHint,
                    fontWeight: FontWeight.w400,
                  ),
                );
              }
              final count = snapshot.data!.size;
              return Text(
                '$count leads remaining in queue',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _textHint,
                  fontWeight: FontWeight.w400,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Recent calls ──────────────────────────────────────────────

  Widget _buildRecentCalls() {
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
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('tenants')
                .doc(AppSession.tenantId)
                .collection('leads')
                .where('assignedTo', isEqualTo: AppSession.userId)
                .where('status', isEqualTo: 'disposed')
                .orderBy('updatedAt', descending: true)
                .limit(5)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No recent calls yet.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _textHint,
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final phone = data['phone']?.toString() ?? '—';
                  final disposition =
                      data['dispositionLabel']?.toString() ?? '—';
                  return _CallLogRow(
                    log: _CallLog(
                      time: '',
                      number: phone,
                      disposition: disposition,
                      chipColor: const Color(0xFFF1F3F4),
                      textColor: const Color(0xFF5F6368),
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
  const _GetNextLeadButton({
    required this.role,
  });
  final String role;

  @override
  State<_GetNextLeadButton> createState() => _GetNextLeadButtonState();
}

class _GetNextLeadButtonState extends State<_GetNextLeadButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _loading = false;

  static const _primary = Color(0xFF1A73E8);
  static const _primaryDark = Color(0xFF1557B0);

  Future<void> _handleTap() async {
    if (_loading) return;

    if (AppSession.campaignId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No campaign assigned. Contact your manager.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final lead = await LeadService.getNextLead(
        AppSession.tenantId,
        AppSession.campaignId,
        AppSession.userId,
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
        CallerShell.shellKey.currentState?.setCurrentLead(lead);
        CallerShell.shellKey.currentState?.navigateTo(1);
      } else {
        // No lead returned
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No leads available in queue')),
        );
      }
    } catch (e) {
      print('GetNextLead error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _loading ? null : _handleTap,
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
              if (!_loading)
                BoxShadow(
                  color: _primary.withOpacity(_hovered ? 0.35 : 0.20),
                  blurRadius: _hovered ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          alignment: Alignment.center,
          child: _loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
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
