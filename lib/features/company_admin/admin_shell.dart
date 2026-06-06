import 'package:flutter/material.dart';

import '../../shared/widgets/sidebar_nav.dart';
import 'dashboard_screen.dart';
import 'campaign_screen.dart';
import 'user_management_screen.dart';
import 'csv_upload_screen.dart';
import 'form_builder_screen.dart';
import 'campaign_settings_screen.dart';

/// Single persistent shell for all Company Admin screens.
/// The sidebar renders once; screen content switches via [IndexedStack].
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  /// Global key — lets any widget call [AdminShellState.navigateTo].
  static final GlobalKey<AdminShellState> shellKey =
      GlobalKey<AdminShellState>();

  @override
  State<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends State<AdminShell> {
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
          SidebarNav(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
          ),
          // ── Content area ─────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                DashboardContent(),         // index 0 — Dashboard
                CampaignContent(),          // index 1 — Campaigns
                UserManagementContent(),    // index 2 — Users
                CsvUploadContent(),         // index 3 — CSV Upload
                SizedBox.shrink(),          // index 4 — Settings (placeholder)
                FormBuilderContent(),       // index 5 — Form Builder
                CampaignSettingsContent(),  // index 6 — Campaign Settings
              ],
            ),
          ),
        ],
      ),
    );
  }
}
