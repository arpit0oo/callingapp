import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/rtdb_service.dart';
import 'home_screen.dart';
import 'calling_workspace_screen.dart';
import 'performance_screen.dart';

/// Mobile shell for Cold Caller / Warm Caller roles.
/// [role] must be "cold" or "warm".
/// Renders a bottom navigation bar with 2 visible tabs (Home, Performance)
/// and an [IndexedStack] body with 3 children:
///   index 0 = Home, index 1 = Workspace (hidden from nav), index 2 = Performance.
/// [navigateTo](1) from the Get Next Lead button switches to the Workspace.
class CallerShell extends StatefulWidget {
  const CallerShell({super.key, required this.role});

  /// "cold" = raw-lead caller, "warm" = callback caller.
  final String role;

  /// Global key — lets any widget call [CallerShellState.navigateTo].
  static final GlobalKey<CallerShellState> shellKey =
      GlobalKey<CallerShellState>();

  @override
  State<CallerShell> createState() => CallerShellState();
}

class CallerShellState extends State<CallerShell> {
  int _selectedIndex = 0;

  /// Current lead being worked on by the caller.
  Map<String, dynamic>? _currentLead;

  /// Called from home_screen after getNextLead() returns a lead.
  void setCurrentLead(Map<String, dynamic>? lead) {
    setState(() => _currentLead = lead);
  }

  @override
  void initState() {
    super.initState();
    RtdbService.updateCallerState(AppSession.tenantId, AppSession.userId, {
      'status': 'idle',
      'currentLeadId': '',
      'lastSeen': ServerValue.timestamp,
    });
  }

  @override
  void dispose() {
    RtdbService.updateCallerState(AppSession.tenantId, AppSession.userId, {
      'status': 'offline',
      'lastSeen': ServerValue.timestamp,
    });
    super.dispose();
  }

  // ── Colors ────────────────────────────────────────────────────
  static const _selectedColor = Color(0xFF1A73E8);
  static const _unselectedColor = Color(0xFF9AA0A6);

  /// Programmatically switch to any tab by index.
  void navigateTo(int index) => setState(() => _selectedIndex = index);

  // ── Nav-bar items (visible tabs only — Workspace is hidden) ──
  // Each entry pairs the display data with the IndexedStack index it targets.
  static const _navBarItems = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      stackIndex: 0,
    ),
    _NavItem(
      label: 'Performance',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
      stackIndex: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                // ── Body ─────────────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      CallerHomeContent(role: widget.role),
                      CallingWorkspaceContent(
                        role: widget.role,
                        currentLead: _currentLead,
                      ),
                      PerformanceContent(role: widget.role),
                    ],
                  ),
                ),

                // ── Bottom navigation bar ─────────────────────────
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8EAED), width: 1),
        ),
      ),
      child: Row(
        children: _navBarItems.map((item) {
          final selected = _selectedIndex == item.stackIndex;
          return Expanded(
            child: InkWell(
              onTap: () => navigateTo(item.stackIndex),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    size: 24,
                    color: selected ? _selectedColor : _unselectedColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? _selectedColor : _unselectedColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data class for nav items
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.stackIndex,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  /// The [IndexedStack] index this tab switches to.
  final int stackIndex;
}
