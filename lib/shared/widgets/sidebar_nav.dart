import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single nav entry definition for the sidebar.
class SidebarNavEntry {
  const SidebarNavEntry(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Full left sidebar — 240 px wide, fixed.
/// Calls [onItemSelected] with the tapped index; navigation decisions
/// are left entirely to the parent (AdminShell via IndexedStack).
class SidebarNav extends StatelessWidget {
  const SidebarNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  static const _kBlue = Color(0xFF1A73E8);
  static const _kGrey = Color(0xFF80868B);
  static const _kSidebarBorder = Color(0xFFE8EAED);
  static const _kTextLight = Color(0xFF5F6368);

  static const _navItems = [
    SidebarNavEntry('Dashboard', Icons.dashboard_outlined),
    SidebarNavEntry('Campaigns', Icons.campaign_outlined),
    SidebarNavEntry('Users', Icons.people_outline),
    SidebarNavEntry('CSV Upload', Icons.upload_file_outlined),
    SidebarNavEntry('Settings', Icons.settings_outlined),
    SidebarNavEntry('Disposition', Icons.rule_outlined),
  ];

  TextStyle _inter(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF202124),
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _kSidebarBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CA',
                    style: _inter(12,
                        weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Text('CallingApp',
                    style: _inter(16, weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Nav items ──────────────────────────
          ..._navItems.asMap().entries.map((e) {
            final isSelected = e.key == selectedIndex;
            return _SidebarNavItem(
              entry: e.value,
              isSelected: isSelected,
              onTap: () => onItemSelected(e.key),
            );
          }),
          const Spacer(),
          // ── User footer ────────────────────────
          const Divider(color: _kSidebarBorder, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _kBlue.withOpacity(0.15),
                  child: Text(
                    'A',
                    style:
                        _inter(14, weight: FontWeight.w600, color: _kBlue),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin User',
                        style: _inter(13, weight: FontWeight.w600)),
                    Text('Company Admin',
                        style: _inter(11, color: _kGrey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private nav item tile ────────────────────────────────────────────────────
class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final SidebarNavEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  static const _kBlue = Color(0xFF1A73E8);
  static const _kTextLight = Color(0xFF5F6368);

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _kBlue : _kTextLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? _kBlue.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? const Border(left: BorderSide(color: _kBlue, width: 3))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(isSelected ? 13 : 16, 10, 12, 10),
          child: Row(
            children: [
              Icon(entry.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                entry.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
