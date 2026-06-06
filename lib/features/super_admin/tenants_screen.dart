import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Super Admin — Tenant management screen.
class TenantsContent extends StatefulWidget {
  const TenantsContent({super.key});

  @override
  State<TenantsContent> createState() => _TenantsContentState();
}

class _TenantsContentState extends State<TenantsContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary      = Color(0xFF1A73E8);
  static const _textPrimary  = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _border       = Color(0xFFE8EAED);
  static const _bg           = Color(0xFFF8F9FA);

  // ── State ─────────────────────────────────────────────────────
  String _filterTab = 'All';
  String _search    = '';
  _TenantRow? _selected;

  static const _tabs = ['All', 'Active', 'Trial', 'Suspended'];

  // ── Dummy data ────────────────────────────────────────────────
  static const _allTenants = <_TenantRow>[
    _TenantRow(
      company: 'Xpert Tutor',
      plan: 'Pro',
      campaigns: 8,
      totalLeads: '1,20,000',
      activeCallers: 45,
      status: 'Active',
      joined: 'Jan 2025',
    ),
    _TenantRow(
      company: 'Solar Solutions',
      plan: 'Starter',
      campaigns: 3,
      totalLeads: '28,000',
      activeCallers: 12,
      status: 'Active',
      joined: 'Mar 2025',
    ),
    _TenantRow(
      company: 'DSA Finance',
      plan: 'Pro',
      campaigns: 5,
      totalLeads: '85,000',
      activeCallers: 28,
      status: 'Trial',
      joined: 'Apr 2025',
    ),
    _TenantRow(
      company: 'EduCare India',
      plan: 'Starter',
      campaigns: 2,
      totalLeads: '12,000',
      activeCallers: 8,
      status: 'Suspended',
      joined: 'Feb 2025',
    ),
  ];

  List<_TenantRow> get _filtered {
    return _allTenants.where((t) {
      final matchTab = _filterTab == 'All' || t.status == _filterTab;
      final matchSearch = t.company
          .toLowerCase()
          .contains(_search.toLowerCase());
      return matchTab && matchSearch;
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Main content ─────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildTableCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Slide panel ──────────────────────────────────────────
        if (_selected != null) _buildSlidePanel(_selected!),
      ],
    );
  }

  // ── Top bar ───────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Row(
        children: [
          Text('Tenants',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const Spacer(),
          _PrimaryButton(
            label: '+ New Tenant',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────

  Widget _buildStatsRow() {
    const stats = [
      _StatCard(label: 'Total Tenants',  value: '14', icon: Icons.business_outlined,        iconColor: Color(0xFF1A73E8)),
      _StatCard(label: 'Active',         value: '11', icon: Icons.check_circle_outline,      iconColor: Color(0xFF34A853)),
      _StatCard(label: 'Trial',          value: '2',  icon: Icons.hourglass_empty_outlined,  iconColor: Color(0xFFFBBC04)),
      _StatCard(label: 'Suspended',      value: '1',  icon: Icons.block_outlined,            iconColor: Color(0xFFD93025)),
    ];
    return Row(
      children: stats
          .map((s) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: s,
                ),
              ))
          .toList(),
    );
  }

  // ── Table card ────────────────────────────────────────────────

  Widget _buildTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + filter tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Search
                SizedBox(
                  width: 240,
                  height: 36,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search tenants…',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF9AA0A6)),
                      prefixIcon: const Icon(Icons.search,
                          size: 16, color: Color(0xFF9AA0A6)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFE8EAED)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFFE8EAED)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Filter tabs
                ..._tabs.map((t) => _FilterTab(
                      label: t,
                      selected: _filterTab == t,
                      onTap: () => setState(() => _filterTab = t),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Table header
          _buildTableHeader(),
          const Divider(color: Color(0xFFE8EAED), height: 1),

          // Rows
          ..._filtered.map((row) => _buildTableRow(row)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const cols = [
      'Company', 'Plan', 'Campaigns', 'Total Leads',
      'Active Callers', 'Status', 'Joined', 'Actions'
    ];
    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: cols.map((c) => _headerCell(c)).toList(),
      ),
    );
  }

  Widget _headerCell(String label) {
    return Expanded(
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
              letterSpacing: 0.3)),
    );
  }

  Widget _buildTableRow(_TenantRow row) {
    final isActive = _selected?.company == row.company;
    return GestureDetector(
      onTap: () => setState(
          () => _selected = isActive ? null : row),
      child: Container(
        color: isActive
            ? _primary.withOpacity(0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Company
            Expanded(
              child: Text(row.company,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
            ),
            // Plan badge
            Expanded(child: _PlanBadge(plan: row.plan)),
            // Campaigns
            Expanded(
              child: Text('${row.campaigns}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textSecondary)),
            ),
            // Total Leads
            Expanded(
              child: Text(row.totalLeads,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textSecondary)),
            ),
            // Active Callers
            Expanded(
              child: Text('${row.activeCallers}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textSecondary)),
            ),
            // Status
            Expanded(child: _StatusBadge(status: row.status)),
            // Joined
            Expanded(
              child: Text(row.joined,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textSecondary)),
            ),
            // Actions
            Expanded(
              child: Row(
                children: [
                  _ActionLink(
                    label: 'View',
                    color: _primary,
                    onTap: () =>
                        setState(() => _selected = row),
                  ),
                  const SizedBox(width: 12),
                  _ActionLink(
                    label: row.status == 'Active'
                        ? 'Suspend'
                        : 'Activate',
                    color: row.status == 'Active'
                        ? const Color(0xFFD93025)
                        : const Color(0xFF34A853),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Slide panel ───────────────────────────────────────────────

  Widget _buildSlidePanel(_TenantRow row) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFE8EAED)))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.company,
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary)),
                      const SizedBox(height: 4),
                      _PlanBadge(plan: row.plan),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 20, color: Color(0xFF5F6368)),
                  onPressed: () =>
                      setState(() => _selected = null),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats 2×2 grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _PanelStat(
                          label: 'Campaigns',
                          value: '${row.campaigns}',
                          icon: Icons.campaign_outlined,
                          iconColor: _primary),
                      _PanelStat(
                          label: 'Total Leads',
                          value: row.totalLeads,
                          icon: Icons.contacts_outlined,
                          iconColor: const Color(0xFF34A853)),
                      _PanelStat(
                          label: 'Active Callers',
                          value: '${row.activeCallers}',
                          icon: Icons.headset_mic_outlined,
                          iconColor: const Color(0xFF9334E6)),
                      _PanelStat(
                          label: 'Monthly Usage',
                          value: '86%',
                          icon: Icons.data_usage_outlined,
                          iconColor: const Color(0xFFE37400)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status + joined
                  Row(
                    children: [
                      Text('Status: ',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: _textSecondary)),
                      _StatusBadge(status: row.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Joined: ${row.joined}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: _textSecondary)),
                  const SizedBox(height: 24),

                  // Login as Admin button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.login, size: 16),
                      label: Text('Login as Admin',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Suspend / Activate outlined button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: Icon(
                          row.status == 'Active'
                              ? Icons.block_outlined
                              : Icons.check_circle_outline,
                          size: 16),
                      label: Text(
                          row.status == 'Active'
                              ? 'Suspend Tenant'
                              : 'Activate Tenant',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: row.status == 'Active'
                            ? const Color(0xFFD93025)
                            : const Color(0xFF34A853),
                        side: BorderSide(
                          color: row.status == 'Active'
                              ? const Color(0xFFD93025)
                              : const Color(0xFF34A853),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124),
                      height: 1.1)),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9AA0A6))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel stat tile (for slide panel 2×2 grid)
// ─────────────────────────────────────────────────────────────────────────────

class _PanelStat extends StatelessWidget {
  const _PanelStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: iconColor),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124),
                      height: 1.1)),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF9AA0A6))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.plan});
  final String plan;

  @override
  Widget build(BuildContext context) {
    final isPro = plan == 'Pro';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPro
            ? const Color(0xFFE8F0FE)
            : const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(plan,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPro
                  ? const Color(0xFF1A73E8)
                  : const Color(0xFF5F6368))),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  static const _map = {
    'Active':    (Color(0xFFE6F4EA), Color(0xFF137333)),
    'Trial':     (Color(0xFFFEF3E2), Color(0xFFE37400)),
    'Suspended': (Color(0xFFFCE8E6), Color(0xFFD93025)),
  };

  @override
  Widget build(BuildContext context) {
    final colors = _map[status] ?? (const Color(0xFFF1F3F4), const Color(0xFF5F6368));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.$2)),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A73E8)
              : const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : const Color(0xFF5F6368))),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF1557B0)
                : const Color(0xFF1A73E8),
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

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _TenantRow {
  const _TenantRow({
    required this.company,
    required this.plan,
    required this.campaigns,
    required this.totalLeads,
    required this.activeCallers,
    required this.status,
    required this.joined,
  });

  final String company;
  final String plan;
  final int    campaigns;
  final String totalLeads;
  final int    activeCallers;
  final String status;
  final String joined;
}
