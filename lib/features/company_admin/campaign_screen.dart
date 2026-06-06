import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/status_badge.dart';
import 'admin_shell.dart';

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
//  Dummy data model
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
  final String status; // 'Active' | 'Paused' | 'Archived'
  final String manager;
  final String rawLeads;
  final String createdDate;
}

const _kAllCampaigns = [
  _Campaign(
    name: 'Xpert Tutor',
    status: 'Active',
    manager: 'Amit',
    rawLeads: '12,500',
    createdDate: 'Jan 12, 2025',
  ),
  _Campaign(
    name: 'Solar Campaign',
    status: 'Active',
    manager: 'Rahul',
    rawLeads: '5,600',
    createdDate: 'Feb 3, 2025',
  ),
  _Campaign(
    name: 'DSA Campaign',
    status: 'Paused',
    manager: 'Neha',
    rawLeads: '18,200',
    createdDate: 'Mar 1, 2025',
  ),
  _Campaign(
    name: 'New Batch',
    status: 'Active',
    manager: 'Amit',
    rawLeads: '3,400',
    createdDate: 'May 20, 2025',
  ),
];

const _kManagers = ['Amit', 'Rahul', 'Neha'];
const _kStatuses = ['Active', 'Paused'];
const _kFilterTabs = ['All', 'Active', 'Paused', 'Archived'];

// ─────────────────────────────────────────────
//  Campaign Content
// ─────────────────────────────────────────────
class CampaignContent extends StatefulWidget {
  const CampaignContent({super.key});

  @override
  State<CampaignContent> createState() => _CampaignContentState();
}

class _CampaignContentState extends State<CampaignContent> {
  // ── Panel state ──────────────────────────────
  bool _panelOpen = false;
  bool _isEditMode = false;
  _Campaign? _editingCampaign;

  // ── Filter / search ──────────────────────────
  int _activeFilter = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Panel form controllers ───────────────────
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _selectedManager = _kManagers.first;
  String _selectedStatus = _kStatuses.first;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<_Campaign> get _filtered {
    final tab = _kFilterTabs[_activeFilter];
    return _kAllCampaigns.where((c) {
      final matchFilter = tab == 'All' || c.status == tab;
      final matchSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  void _openCreate() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _selectedManager = _kManagers.first;
    _selectedStatus = _kStatuses.first;
    setState(() {
      _isEditMode = false;
      _editingCampaign = null;
      _panelOpen = true;
    });
  }

  void _openEdit(_Campaign c) {
    _nameCtrl.text = c.name;
    _descCtrl.text = '';
    _selectedManager = c.manager;
    _selectedStatus = c.status;
    setState(() {
      _isEditMode = true;
      _editingCampaign = c;
      _panelOpen = true;
    });
  }

  void _closePanel() => setState(() => _panelOpen = false);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBgPage,
      child: Stack(
        children: [
          _MainContent(
            campaigns: _filtered,
            activeFilter: _activeFilter,
            searchCtrl: _searchCtrl,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onFilterChanged: (i) => setState(() => _activeFilter = i),
            onNewCampaign: _openCreate,
            onEdit: _openEdit,
          ),
          // ── Dim overlay ──────────────────────────
          if (_panelOpen)
            GestureDetector(
              onTap: _closePanel,
              child: Container(color: Colors.black.withOpacity(0.18)),
            ),
          // ── Slide panel ──────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            right: _panelOpen ? 0 : -440,
            child: _SlidePanel(
              isEditMode: _isEditMode,
              nameCtrl: _nameCtrl,
              descCtrl: _descCtrl,
              selectedManager: _selectedManager,
              selectedStatus: _selectedStatus,
              onManagerChanged: (v) => setState(() => _selectedManager = v!),
              onStatusChanged: (v) => setState(() => _selectedStatus = v!),
              onClose: _closePanel,
              onCancel: _closePanel,
              onSave: _closePanel,
              onOpenFormBuilder: () {
                _closePanel();
                AdminShell.shellKey.currentState?.navigateTo(5);
              },
              onOpenDisposition: () {
                _closePanel();
                AdminShell.shellKey.currentState?.navigateTo(6);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Main Content
// ─────────────────────────────────────────────
class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.campaigns,
    required this.activeFilter,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onNewCampaign,
    required this.onEdit,
  });

  final List<_Campaign> campaigns;
  final int activeFilter;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onFilterChanged;
  final VoidCallback onNewCampaign;
  final ValueChanged<_Campaign> onEdit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Bar ───────────────────────────
          Row(
            children: [
              Text('Campaigns', style: _inter(20, weight: FontWeight.w700)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onNewCampaign,
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: onSearchChanged,
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
                              borderSide: const BorderSide(color: _kBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _kBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: _kBlue, width: 1.5),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Filter tabs
                      Row(
                        children: _kFilterTabs.asMap().entries.map((e) {
                          final isActive = e.key == activeFilter;
                          return GestureDetector(
                            onTap: () => onFilterChanged(e.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _kBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      isActive ? _kBlue : _kBorder,
                                ),
                              ),
                              child: Text(
                                e.value,
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

                // ── Table ─────────────────────────
                _CampaignTable(campaigns: campaigns, onEdit: onEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Campaign Table
// ─────────────────────────────────────────────
class _CampaignTable extends StatelessWidget {
  const _CampaignTable({required this.campaigns, required this.onEdit});

  final List<_Campaign> campaigns;
  final ValueChanged<_Campaign> onEdit;

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
              style: _inter(14, color: _kGrey)),
        ),
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
    final isActive = c.status == 'Active';
    return DataRow(cells: [
      // Campaign Name
      DataCell(Text(c.name, style: _inter(13, weight: FontWeight.w500))),
      // Status — reused shared StatusBadge
      DataCell(StatusBadge(
        label: c.status,
        color: isActive ? _kGreen : _kGrey,
      )),
      // Manager
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
      // Raw Leads
      DataCell(Text(c.rawLeads)),
      // Created Date
      DataCell(Text(c.createdDate, style: _inter(13, color: _kTextLight))),
      // Actions
      DataCell(_ActionButtons(campaign: c, onEdit: onEdit)),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Action Buttons (Edit / Settings / Pause|Resume)
// ─────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.campaign, required this.onEdit});

  final _Campaign campaign;
  final ValueChanged<_Campaign> onEdit;

  @override
  Widget build(BuildContext context) {
    final isPaused = campaign.status == 'Paused';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          color: _kBlue,
          onTap: () => onEdit(campaign),
        ),
        const SizedBox(width: 4),
        // Settings
        _IconBtn(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          color: _kTextLight,
          onTap: () {},
        ),
        const SizedBox(width: 4),
        // Pause / Resume
        _IconBtn(
          icon: isPaused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline,
          tooltip: isPaused ? 'Resume' : 'Pause',
          color: isPaused ? _kGreen : const Color(0xFFFA7B17),
          onTap: () {},
        ),
      ],
    );
  }
}

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
//  Slide Panel (Create / Edit)
// ─────────────────────────────────────────────
class _SlidePanel extends StatelessWidget {
  _SlidePanel({
    required this.isEditMode,
    required this.nameCtrl,
    required this.descCtrl,
    required this.selectedManager,
    required this.selectedStatus,
    required this.onManagerChanged,
    required this.onStatusChanged,
    required this.onClose,
    required this.onCancel,
    required this.onSave,
    required this.onOpenFormBuilder,
    required this.onOpenDisposition,
  });

  final bool isEditMode;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String selectedManager;
  final String selectedStatus;
  final ValueChanged<String?> onManagerChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onClose;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onOpenFormBuilder;
  final VoidCallback onOpenDisposition;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 24,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Panel header ──────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  isEditMode ? 'Edit Campaign' : 'Create Campaign',
                  style: _inter(17, weight: FontWeight.w600),
                ),
                const Spacer(),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 20, color: _kTextLight),
                  ),
                ),
              ],
            ),
          ),

          // ── Form ─────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campaign Name
                  _FieldLabel('Campaign Name'),
                  const SizedBox(height: 6),
                  _OutlinedField(
                    controller: nameCtrl,
                    hint: 'Enter campaign name',
                  ),
                  const SizedBox(height: 20),

                  // Select Manager
                  _FieldLabel('Select Manager'),
                  const SizedBox(height: 6),
                  _StyledDropdown<String>(
                    value: selectedManager,
                    items: _kManagers,
                    onChanged: onManagerChanged,
                  ),
                  const SizedBox(height: 20),

                  // Status
                  _FieldLabel('Status'),
                  const SizedBox(height: 6),
                  _StyledDropdown<String>(
                    value: selectedStatus,
                    items: _kStatuses,
                    onChanged: onStatusChanged,
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _FieldLabel('Description'),
                  const SizedBox(height: 6),
                  _OutlinedField(
                    controller: descCtrl,
                    hint: 'Enter campaign description...',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),

          // ── Edit-mode quick actions ───────────
          if (isEditMode) ...[
            const SizedBox(height: 16),
            const Divider(color: _kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Open Form Builder — solid blue filled
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: onOpenFormBuilder,
                      icon: const Icon(Icons.dynamic_form_outlined,
                          size: 17, color: Colors.white),
                      label: Text('Open Form Builder',
                          style: _inter(13,
                              weight: FontWeight.w500, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Disposition Settings — white bg, grey border
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _kTextLight,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: _kBorder),
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: onOpenDisposition,
                      icon: const Icon(Icons.tune, size: 17, color: _kTextLight),
                      label: Text('Disposition Settings',
                          style: _inter(13,
                              weight: FontWeight.w500, color: _kTextLight)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Footer buttons ────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kTextLight,
                      side: const BorderSide(color: _kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onCancel,
                    child: Text('Cancel',
                        style: _inter(13, weight: FontWeight.w500,
                            color: _kTextLight)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onSave,
                    child: Text('Save Campaign',
                        style: _inter(13,
                            weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Small form helpers
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
