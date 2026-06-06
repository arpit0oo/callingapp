import 'package:flutter/material.dart';

import '../../shared/widgets/sidebar_nav.dart';
import 'dashboard_screen.dart';
import 'campaign_screen.dart';
import 'form_builder_screen.dart';
import 'csv_upload_screen.dart';

/// Single persistent shell for all Company Admin screens.
/// The sidebar renders once; screen content switches via [IndexedStack].
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

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
                DashboardContent(),    // index 0
                CampaignContent(),     // index 1
                FormBuilderContent(),  // index 2
                CsvUploadContent(),    // index 3
              ],
            ),
          ),
        ],
      ),
    );
  }
}
