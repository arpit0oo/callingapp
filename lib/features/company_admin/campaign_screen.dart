import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/campaign_service.dart';
import '../../shared/widgets/status_badge.dart';
import 'admin_shell.dart';
import 'campaign_settings_screen.dart';
import 'form_builder_screen.dart';

// ─────────────────────────────────────────────
//  Colour constants
// ─────────────────────────────────────────────
const _kBgPage = Color(0xFFF8F9FA);
const _kBlue = Color(0xFF1A73E8);
const _kGreen = Color(0xFF34A853);
const _kGrey = Color(0xFF80868B);
const _kText = Color(0xFF202124);
const _kTextLight = Color(0xFF5F6368);
const _kBorder = Color(0xFFE8EAED);
const _kCardShadow = Color(0x14000000);

TextStyle _inter(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _kText,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

BoxDecoration _card({double radius = 8}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: _kCardShadow, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );

// ─────────────────────────────────────────────
//  Dummy fallback data (shown when Firestore has 0 docs)
// ─────────────────────────────────────────────
class _Campaign {
  const _Campaign({
    required this.name,
    required this.status,
    required this.manager,
    required this.rawLeads,
    required this.createdDate,
  });
  final String name;
  final String status;
  final String manager;
  final String rawLeads;
  final String createdDate;
}

const _kDummyCampaigns = [
  _Campaign(
    name: 'Xpert Tutor',
    status: 'active',
    manager: 'Amit',
    rawLeads: '12,500',
    createdDate: 'Jan 12, 2025',
  ),
  _Campaign(
    name: 'Solar Campaign',
    status: 'active',
    manager: 'Rahul',
    rawLeads: '5,600',
    createdDate: 'Feb 3, 2025',
  ),
  _Campaign(
    name: 'DSA Campaign',
    status: 'paused',
    manager: 'Neha',
    rawLeads: '18,200',
    createdDate: 'Mar 1, 2025',
  ),
];

const _kManagers = ['Amit', 'Rahul', 'Neha'];
const _kStatuses = ['active', 'paused'];
const _kFilterTabs = ['All', 'active', 'paused'];

// ─────────────────────────────────────────────
//  Campaign Content
// ─────────────────────────────────────────────
class CampaignContent extends StatefulWidget {
  const CampaignContent({super.key});

  @override
  State<CampaignContent> createState() => _CampaignContentState();
}

class _CampaignContentState extends State<CampaignContent> {
  // ── Filter / search ──────────────────────────
  int _activeFilter = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── New Campaign dialog ──────────────────────
  Future<void> _showNewCampaignDialog() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('New Campaign', style: _inter(17, weight: FontWeight.w600)),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            style: _inter(14),
            decoration: InputDecoration(
              hintText: 'Enter campaign name',
              hintStyle: _inter(13, color: _kGrey),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBlue, width: 1.5),
              ),
              filled: true,
              fillColor: _kBgPage,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: _inter(13, color: _kTextLight)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Create',
                style: _inter(13, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await CampaignService.createCampaign(AppSession.tenantId, {
        'name': nameCtrl.text.trim(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': AppSession.userId,
      });
    }
    nameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBgPage,
      child: StreamBuilder<QuerySnapshot>(
        stream: CampaignService.getCampaigns(AppSession.tenantId),
        builder: (context, snap) {
          // Resolve docs or fallback dummy data
          final bool isFirestore =
              snap.hasData && snap.data!.docs.isNotEmpty;
          final bool useDummy =
              !snap.hasData || snap.data!.docs.isEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ───────────────────────────
                Row(
                  children: [
                    Text('Campaigns',
                        style: _inter(20, weight: FontWeight.w700)),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _showNewCampaignDialog,
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: Text(
                        'New Campaign',
                        style: _inter(13,
                            weight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Campaign List Card ────────────────
                Container(
                  decoration: _card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Search + filters ──────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                                style: _inter(13),
                                decoration: InputDecoration(
                                  hintText: 'Search campaigns...',
                                  hintStyle: _inter(13, color: _kGrey),
                                  prefixIcon: const Icon(Icons.search,
                                      size: 18, color: _kGrey),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _kBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        const BorderSide(color: _kBorder),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: _kBlue, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FA),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children:
                                  _kFilterTabs.asMap().entries.map((e) {
                                final isActive = e.key == _activeFilter;
                                final label = e.value == 'All'
                                    ? 'All'
                                    : e.value == 'active'
                                        ? 'Active'
                                        : 'Paused';
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _activeFilter = e.key),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _kBlue
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isActive
                                            ? _kBlue
                                            : _kBorder,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: _inter(12,
                                          weight: FontWeight.w500,
                                          color: isActive
                                              ? Colors.white
                                              : _kTextLight),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: _kBorder, height: 1),

                      // ── Loading indicator ──────────────
                      if (snap.connectionState ==
                              ConnectionState.waiting &&
                          !snap.hasData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                              child: CircularProgressIndicator()),
                        )

                      // ── Error state ────────────────────
                      else if (snap.hasError)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'Failed to load campaigns.',
                              style: _inter(14, color: _kGrey),
                            ),
                          ),
                        )

                      // ── Firestore rows or dummy fallback
                      else if (isFirestore)
                        _FirestoreTable(
                          docs: _applyFilter(snap.data!.docs),
                        )
                      else
                        _DummyTable(
                          campaigns: _applyDummyFilter(_kDummyCampaigns),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot> _applyFilter(
      List<QueryDocumentSnapshot> docs) {
    final tab = _kFilterTabs[_activeFilter];
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      final status = (data['status'] as String? ?? '').toLowerCase();
      final name = (data['name'] as String? ?? '').toLowerCase();
      final matchFilter = tab == 'All' || status == tab;
      final matchSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  List<_Campaign> _applyDummyFilter(List<_Campaign> list) {
    final tab = _kFilterTabs[_activeFilter];
    return list.where((c) {
      final matchFilter = tab == 'All' || c.status == tab;
      final matchSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }
}

// ─────────────────────────────────────────────
//  Firestore Table
// ─────────────────────────────────────────────
class _FirestoreTable extends StatelessWidget {
  const _FirestoreTable({required this.docs});
  final List<QueryDocumentSnapshot> docs;

  static const _columns = [
    'Campaign Name',
    'Status',
    'Raw Leads',
    'Actions',
  ];

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child: Text('No campaigns found.',
                style: _inter(14, color: _kGrey))),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              columnSpacing: 24,
              headingTextStyle:
                  _inter(12, weight: FontWeight.w600, color: _kTextLight),
              dataTextStyle: _inter(13),
              columns:
                  _columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: docs.map((doc) => _buildRow(context, doc)).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildRow(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? '—';
    final status = (data['status'] as String? ?? 'active').toLowerCase();
    final rawLeads = data['rawQueueCount']?.toString() ?? '0';
    final isPaused = status == 'paused';

    return DataRow(cells: [
      DataCell(Text(name, style: _inter(13, weight: FontWeight.w500))),
      DataCell(StatusBadge(
        label: isPaused ? 'Paused' : 'Active',
        color: isPaused ? _kGrey : _kGreen,
      )),
      DataCell(Text(rawLeads)),
      DataCell(_FirestoreActionButtons(
        doc: doc,
        isPaused: isPaused,
      )),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Firestore Action Buttons
// ─────────────────────────────────────────────
class _FirestoreActionButtons extends StatelessWidget {
  const _FirestoreActionButtons({
    required this.doc,
    required this.isPaused,
  });

  final QueryDocumentSnapshot doc;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pencil — navigate to FormBuilderContent with campaignId
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Form',
          color: _kBlue,
          onTap: () {
            // TODO: Pass campaignId to FormBuilderContent once it accepts the parameter
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: FormBuilderContent(),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        // Gear — navigate to CampaignSettingsContent with campaignId
        _IconBtn(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          color: _kTextLight,
          onTap: () {
            // TODO: Pass campaignId to CampaignSettingsContent once it accepts the parameter
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: CampaignSettingsContent(),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        // Pause / Resume
        _IconBtn(
          icon: isPaused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline,
          tooltip: isPaused ? 'Resume' : 'Pause',
          color: isPaused ? _kGreen : const Color(0xFFFA7B17),
          onTap: () {
            final newStatus = isPaused ? 'active' : 'paused';
            CampaignService.setCampaignStatus(
              AppSession.tenantId,
              doc.id,
              newStatus,
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Dummy Table (fallback when Firestore is empty)
// ─────────────────────────────────────────────
class _DummyTable extends StatelessWidget {
  const _DummyTable({required this.campaigns});
  final List<_Campaign> campaigns;

  static const _columns = [
    'Campaign Name',
    'Status',
    'Assigned Manager',
    'Raw Leads',
    'Created Date',
    'Actions',
  ];

  @override
  Widget build(BuildContext context) {
    if (campaigns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child: Text('No campaigns found.',
                style: _inter(14, color: _kGrey))),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              columnSpacing: 24,
              headingTextStyle:
                  _inter(12, weight: FontWeight.w600, color: _kTextLight),
              dataTextStyle: _inter(13),
              columns:
                  _columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: campaigns.map((c) => _buildRow(c)).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildRow(_Campaign c) {
    final isActive = c.status == 'active';
    return DataRow(cells: [
      DataCell(Text(c.name, style: _inter(13, weight: FontWeight.w500))),
      DataCell(StatusBadge(
        label: isActive ? 'Active' : 'Paused',
        color: isActive ? _kGreen : _kGrey,
      )),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: _kBlue.withOpacity(0.12),
          child: Text(c.manager[0],
              style: _inter(11, weight: FontWeight.w600, color: _kBlue)),
        ),
        const SizedBox(width: 8),
        Text(c.manager),
      ])),
      DataCell(Text(c.rawLeads)),
      DataCell(Text(c.createdDate, style: _inter(13, color: _kTextLight))),
      // Dummy action buttons (no-op)
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              color: _kBlue,
              onTap: () {}),
          const SizedBox(width: 4),
          _IconBtn(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              color: _kTextLight,
              onTap: () {}),
          const SizedBox(width: 4),
          _IconBtn(
            icon: isActive
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            tooltip: isActive ? 'Pause' : 'Resume',
            color: isActive ? const Color(0xFFFA7B17) : _kGreen,
            onTap: () {},
          ),
        ],
      )),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Shared icon button
// ─────────────────────────────────────────────
class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withOpacity(0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 18, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small form helpers (kept for potential future
//  use of the slide panel)
// ─────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: _inter(12, weight: FontWeight.w600, color: _kTextLight));
  }
}

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: _inter(13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _inter(13, color: _kGrey),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBlue, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: _inter(13),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: _kTextLight),
          onChanged: onChanged,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(item.toString(), style: _inter(13)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
