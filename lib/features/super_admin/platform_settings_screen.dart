import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Super Admin — Platform Settings screen content.
/// Web layout, two-column split. Sidebar is provided by SuperAdminShell.
class PlatformSettingsContent extends StatefulWidget {
  const PlatformSettingsContent({super.key});

  @override
  State<PlatformSettingsContent> createState() =>
      _PlatformSettingsContentState();
}

class _PlatformSettingsContentState extends State<PlatformSettingsContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary      = Color(0xFF1A73E8);
  static const _textPrimary  = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _border       = Color(0xFFE8EAED);
  static const _bg           = Color(0xFFF8F9FA);
  static const _red          = Color(0xFFD93025);

  // ── Feature flags state ───────────────────────────────────────
  final _flags = <String, bool>{
    'Webhook Integration'     : true,
    'CSV Upload'              : true,
    'Call Recording'          : false,
    'Warm Queue'              : true,
    'DNC Suppression'         : true,
    'Multi-Campaign Callers'  : false,
  };

  static const _flagDescriptions = <String, String>{
    'Webhook Integration'    : 'Send real-time lead events to external URLs',
    'CSV Upload'             : 'Allow admins to bulk-upload lead CSV files',
    'Call Recording'         : 'Record and archive all caller sessions',
    'Warm Queue'             : 'Enable warm callback queue across campaigns',
    'DNC Suppression'        : 'Auto-filter Do-Not-Call numbers from leads',
    'Multi-Campaign Callers' : 'Let callers work across multiple campaigns',
  };

  // ── Announcement state ────────────────────────────────────────
  final _announcementCtrl = TextEditingController(
    text:
        'System maintenance scheduled for June 10, 2025 at 2:00 AM IST',
  );
  bool _showBanner = true;

  @override
  void dispose() {
    _announcementCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Left column ───────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      _buildPlanConfigCard(),
                      const SizedBox(height: 20),
                      _buildFeatureFlagsCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // ── Right column ──────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      _buildPlatformStatsCard(),
                      const SizedBox(height: 20),
                      _buildAnnouncementCard(),
                      const SizedBox(height: 20),
                      _buildDangerZoneCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Platform Settings',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 3),
          Text('Global configuration for all tenants',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _textSecondary)),
        ],
      ),
    );
  }

  // ── Plan Configuration card ───────────────────────────────────

  Widget _buildPlanConfigCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Plan Configuration'),
          const SizedBox(height: 16),
          _PlanRow(
            name: 'Starter',
            maxCampaigns: 3,
            maxCallers: 10,
            price: '₹2,999/mo',
            nameColor: const Color(0xFF5F6368),
            nameBg: const Color(0xFFF1F3F4),
            onEdit: () {},
          ),
          const SizedBox(height: 10),
          _PlanRow(
            name: 'Pro',
            maxCampaigns: 10,
            maxCallers: 50,
            price: '₹7,999/mo',
            nameColor: const Color(0xFF1A73E8),
            nameBg: const Color(0xFFE8F0FE),
            onEdit: () {},
          ),
        ],
      ),
    );
  }

  // ── Feature Flags card ────────────────────────────────────────

  Widget _buildFeatureFlagsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Feature Flags'),
          const SizedBox(height: 12),
          ..._flags.entries.map((entry) {
            final desc = _flagDescriptions[entry.key] ?? '';
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary)),
                            const SizedBox(height: 2),
                            Text(desc,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _textSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: entry.value,
                        onChanged: (v) =>
                            setState(() => _flags[entry.key] = v),
                        activeColor: _primary,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
                if (entry.key != _flags.keys.last)
                  const Divider(color: Color(0xFFE8EAED), height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Platform Stats card ───────────────────────────────────────

  Widget _buildPlatformStatsCard() {
    const stats = [
      ('Total Tenants',         '14'),
      ('Total Campaigns',       '47'),
      ('Total Leads Processed', '2.4M'),
      ('Active Callers Right Now', '156'),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Platform Stats'),
          const SizedBox(height: 12),
          ...stats.asMap().entries.map((e) {
            final isLast = e.key == stats.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.value.$1,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: _textSecondary)),
                      ),
                      Text(e.value.$2,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary)),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(color: Color(0xFFE8EAED), height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Announcement Banner card ──────────────────────────────────

  Widget _buildAnnouncementCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Announcement Banner'),
          const SizedBox(height: 14),

          // Multiline text input
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _announcementCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(
                  fontSize: 13, color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter announcement message…',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF9AA0A6)),
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Show banner toggle
          Row(
            children: [
              Expanded(
                child: Text('Show banner to all users',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary)),
              ),
              Switch(
                value: _showBanner,
                onChanged: (v) => setState(() => _showBanner = v),
                activeColor: _primary,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Save button
          _FullWidthButton(
            label: 'Save Announcement',
            color: _primary,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ── Danger Zone card ──────────────────────────────────────────

  Widget _buildDangerZoneCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
        // Red left accent border
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Red left border strip
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFD93025),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Danger Zone',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _red)),
                    const SizedBox(height: 16),

                    // Reset All Demo Data
                    _DangerRow(
                      title: 'Reset All Demo Data',
                      description:
                          'Clears all dummy records across all tenants',
                      buttonLabel: 'Reset Demo Data',
                      onTap: () {},
                    ),
                    const Divider(color: Color(0xFFE8EAED), height: 24),

                    // Force Logout All Users
                    _DangerRow(
                      title: 'Force Logout All Users',
                      description:
                          'Immediately invalidates all active sessions',
                      buttonLabel: 'Force Logout',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan row widget
// ─────────────────────────────────────────────────────────────────────────────

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.name,
    required this.maxCampaigns,
    required this.maxCallers,
    required this.price,
    required this.nameColor,
    required this.nameBg,
    required this.onEdit,
  });

  final String name;
  final int maxCampaigns;
  final int maxCallers;
  final String price;
  final Color nameColor;
  final Color nameBg;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Plan badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: nameBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(name,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: nameColor)),
          ),
          const SizedBox(width: 16),

          // Specs
          _Spec(label: 'Campaigns', value: '$maxCampaigns'),
          const SizedBox(width: 16),
          _Spec(label: 'Callers', value: '$maxCallers'),
          const SizedBox(width: 16),
          _Spec(label: 'Price', value: price),

          const Spacer(),

          // Edit button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8EAED)),
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        size: 13, color: Color(0xFF5F6368)),
                    const SizedBox(width: 4),
                    Text('Edit',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5F6368))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                color: const Color(0xFF9AA0A6),
                fontWeight: FontWeight.w500)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF202124))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Danger row widget
// ─────────────────────────────────────────────────────────────────────────────

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF202124))),
              const SizedBox(height: 2),
              Text(description,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF5F6368))),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFD93025),
            side: const BorderSide(color: Color(0xFFD93025)),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(buttonLabel,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF202124)));
  }
}

class _FullWidthButton extends StatefulWidget {
  const _FullWidthButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_FullWidthButton> createState() => _FullWidthButtonState();
}

class _FullWidthButtonState extends State<_FullWidthButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF1557B0)
                : widget.color,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(widget.label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ),
    );
  }
}
