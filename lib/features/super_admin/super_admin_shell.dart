import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tenants_screen.dart';
import 'platform_settings_screen.dart';

/// Single persistent shell for all Super Admin screens.
/// Web layout — sidebar + IndexedStack, same pattern as AdminShell.
class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  /// Global key — lets any widget call [SuperAdminShellState.navigateTo].
  static final GlobalKey<SuperAdminShellState> shellKey =
      GlobalKey<SuperAdminShellState>();

  @override
  State<SuperAdminShell> createState() => SuperAdminShellState();
}

class SuperAdminShellState extends State<SuperAdminShell> {
  int _selectedIndex = 0;

  /// Programmatically switch to any tab by index.
  void navigateTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // ── Sidebar — built once, never rebuilds ──
          _SuperAdminSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
          ),
          // ── Content area ─────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                TenantsContent(),           // index 0 — Tenants
                _ComingSoon(),              // index 1 — Users
                PlatformSettingsContent(),  // index 2 — Platform
                _ComingSoon(),              // index 3 — Billing
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Super Admin Sidebar (file-private)
// ─────────────────────────────────────────────────────────────────────────────

class _SuperAdminSidebar extends StatelessWidget {
  const _SuperAdminSidebar({
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  static const _kBlue         = Color(0xFF1A73E8);
  static const _kGrey         = Color(0xFF80868B);
  static const _kSidebarBorder = Color(0xFFE8EAED);

  static const _navItems = <_NavEntry>[
    _NavEntry('Tenants',  Icons.business_outlined),
    _NavEntry('Users',    Icons.manage_accounts_outlined),
    _NavEntry('Platform', Icons.settings_applications_outlined),
    _NavEntry('Billing',  Icons.receipt_long_outlined),
  ];

  TextStyle _inter(double size,
      {FontWeight weight = FontWeight.w400,
      Color color = const Color(0xFF202124)}) =>
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
          // ── Logo ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('CA',
                      style: _inter(12,
                          weight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Text('CallingApp',
                    style: _inter(16, weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Nav items ─────────────────────────────
          ..._navItems.asMap().entries.map((e) {
            final isSelected = e.key == selectedIndex;
            return _NavItem(
              entry: e.value,
              isSelected: isSelected,
              onTap: () => onItemSelected(e.key),
            );
          }),

          const Spacer(),

          // ── User footer ───────────────────────────
          const Divider(color: _kSidebarBorder, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _kBlue.withOpacity(0.15),
                  child: Text('S',
                      style: _inter(14,
                          weight: FontWeight.w600, color: _kBlue)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Super Admin',
                        style: _inter(13, weight: FontWeight.w600)),
                    Text('Platform Owner',
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

// ── Private data holder ───────────────────────────────────────────────────────
class _NavEntry {
  const _NavEntry(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ── Private nav item tile ─────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final _NavEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  static const _kBlue      = Color(0xFF1A73E8);
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
// ── Coming-soon empty state ─────────────────────────────────────────────────
class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.construction_outlined,
            size: 48,
            color: Color(0xFF9AA0A6),
          ),
          const SizedBox(height: 16),
          Text(
            'Coming Soon',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5F6368),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This section is under development',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ],
      ),
    );
  }
}
