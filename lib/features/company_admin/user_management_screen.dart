import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/status_badge.dart';

// ─────────────────────────────────────────────
//  Colour constants
// ─────────────────────────────────────────────
const _kBlue = Color(0xFF1A73E8);
const _kRed = Color(0xFFEA4335);
const _kGreen = Color(0xFF34A853);
const _kGrey = Color(0xFF80868B);
const _kText = Color(0xFF202124);
const _kTextLight = Color(0xFF5F6368);
const _kBorder = Color(0xFFE8EAED);
const _kBgPage = Color(0xFFF8F9FA);
const _kCardShadow = Color(0x14000000);

TextStyle _inter(double size,
        {FontWeight weight = FontWeight.w400, Color color = _kText}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

BoxDecoration _card({double radius = 8}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: _kCardShadow, blurRadius: 6, offset: Offset(0, 2)),
      ],
    );

// ─────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────
class _User {
  const _User({
    required this.name,
    required this.email,
    required this.role,
    required this.campaign,
    required this.status,
    required this.lastActive,
    required this.phone,
  });
  final String name, email, role, campaign, status, lastActive, phone;
}

const _kUsers = [
  _User(name: 'Amit Sharma',  email: 'amit@callingapp.in',   role: 'Manager', campaign: 'Xpert Tutor',     status: 'Active',   lastActive: '2h ago',  phone: '+91 98001 11111'),
  _User(name: 'Rahul Verma',  email: 'rahul@callingapp.in',  role: 'Manager', campaign: 'Solar Campaign',  status: 'Active',   lastActive: '1d ago',  phone: '+91 98001 22222'),
  _User(name: 'Neha Singh',   email: 'neha@callingapp.in',   role: 'Manager', campaign: 'DSA Campaign',    status: 'Active',   lastActive: '3h ago',  phone: '+91 98001 33333'),
  _User(name: 'Ravi Kumar',   email: 'ravi@callingapp.in',   role: 'Caller',  campaign: 'Xpert Tutor',     status: 'Active',   lastActive: '30m ago', phone: '+91 98001 44444'),
  _User(name: 'Priya Patel',  email: 'priya@callingapp.in',  role: 'Caller',  campaign: 'Solar Campaign',  status: 'Inactive', lastActive: '5d ago',  phone: '+91 98001 55555'),
  _User(name: 'Suresh Yadav', email: 'suresh@callingapp.in', role: 'Caller',  campaign: 'Xpert Tutor',     status: 'Active',   lastActive: '1h ago',  phone: '+91 98001 66666'),
];

const _kCampaigns = ['Xpert Tutor', 'Solar Campaign', 'DSA Campaign'];
const _kRoles = ['Manager', 'Caller'];
const _kStatuses = ['Active', 'Inactive'];
const _kFilterTabs = ['All', 'Managers', 'Callers'];

// ─────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────
class UserManagementContent extends StatefulWidget {
  const UserManagementContent({super.key});

  @override
  State<UserManagementContent> createState() => _UserManagementContentState();
}

class _UserManagementContentState extends State<UserManagementContent> {
  int _filterIndex = 0;
  String _search = '';
  bool _panelOpen = false;
  bool _isEditMode = false;
  _User? _editingUser;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = _kRoles.first;
  String _selectedCampaign = _kCampaigns.first;
  String _selectedStatus = _kStatuses.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  List<_User> get _filtered {
    final tab = _kFilterTabs[_filterIndex];
    return _kUsers.where((u) {
      final matchTab = tab == 'All' ||
          (tab == 'Managers' && u.role == 'Manager') ||
          (tab == 'Callers' && u.role == 'Caller');
      final matchSearch = _search.isEmpty ||
          u.name.toLowerCase().contains(_search.toLowerCase());
      return matchTab && matchSearch;
    }).toList();
  }

  void _openCreate() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _selectedRole = _kRoles.first;
    _selectedCampaign = _kCampaigns.first;
    _selectedStatus = _kStatuses.first;
    setState(() { _isEditMode = false; _editingUser = null; _panelOpen = true; });
  }

  void _openEdit(_User u) {
    _nameCtrl.text = u.name;
    _emailCtrl.text = u.email;
    _phoneCtrl.text = u.phone;
    _selectedRole = u.role;
    _selectedCampaign = u.campaign;
    _selectedStatus = u.status;
    setState(() { _isEditMode = true; _editingUser = u; _panelOpen = true; });
  }

  void _closePanel() => setState(() => _panelOpen = false);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBgPage,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ───────────────────────────
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Users', style: _inter(20, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Manage managers and callers',
                        style: _inter(14, color: _kTextLight)),
                  ]),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text('Add User',
                        style: _inter(13, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Stats Row ─────────────────────────
                Row(children: [
                  _StatCard(label: 'Total Users', value: '12', icon: Icons.people_outline),
                  const SizedBox(width: 16),
                  _StatCard(label: 'Active Managers', value: '4', icon: Icons.manage_accounts_outlined),
                  const SizedBox(width: 16),
                  _StatCard(label: 'Active Callers', value: '8', icon: Icons.headset_mic_outlined),
                ]),
                const SizedBox(height: 24),

                // ── User Table Card ───────────────────
                Container(
                  decoration: _card(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Search + filter row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          height: 40,
                          child: TextField(
                            onChanged: (v) => setState(() => _search = v),
                            style: _inter(13),
                            decoration: InputDecoration(
                              hintText: 'Search users...',
                              hintStyle: _inter(13, color: _kGrey),
                              prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                              filled: true, fillColor: _kBgPage,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: _kFilterTabs.asMap().entries.map((e) {
                            final active = e.key == _filterIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _filterIndex = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: active ? _kBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: active ? _kBlue : _kBorder),
                                ),
                                child: Text(e.value,
                                    style: _inter(12, weight: FontWeight.w500,
                                        color: active ? Colors.white : _kTextLight)),
                              ),
                            );
                          }).toList(),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: _kBorder, height: 1),
                    _UserTable(users: _filtered, onEdit: _openEdit),
                  ]),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),

          // ── Dim overlay ───────────────────────
          if (_panelOpen)
            GestureDetector(
              onTap: _closePanel,
              child: Container(color: Colors.black.withOpacity(0.18)),
            ),

          // ── Slide panel ───────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: 0, bottom: 0,
            right: _panelOpen ? 0 : -440,
            child: _UserPanel(
              isEditMode: _isEditMode,
              nameCtrl: _nameCtrl,
              emailCtrl: _emailCtrl,
              phoneCtrl: _phoneCtrl,
              selectedRole: _selectedRole,
              selectedCampaign: _selectedCampaign,
              selectedStatus: _selectedStatus,
              onRoleChanged: (v) => setState(() => _selectedRole = v!),
              onCampaignChanged: (v) => setState(() => _selectedCampaign = v!),
              onStatusChanged: (v) => setState(() => _selectedStatus = v!),
              onClose: _closePanel,
              onCancel: _closePanel,
              onSave: _closePanel,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stat Card
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _card(),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kBgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Icon(icon, size: 20, color: _kTextLight),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: _inter(22, weight: FontWeight.w700)),
            Text(label, style: _inter(12, color: _kTextLight)),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  User Table
// ─────────────────────────────────────────────
class _UserTable extends StatelessWidget {
  const _UserTable({required this.users, required this.onEdit});
  final List<_User> users;
  final ValueChanged<_User> onEdit;

  static const _columns = ['User', 'Role', 'Assigned Campaign', 'Status', 'Last Active', 'Actions'];

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No users found.', style: _inter(14, color: _kGrey))),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 64,
            columnSpacing: 24,
            headingTextStyle: _inter(12, weight: FontWeight.w600, color: _kTextLight),
            dataTextStyle: _inter(13),
            columns: _columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: users.map((u) => _buildRow(u)).toList(),
          ),
        ),
      );
    });
  }

  DataRow _buildRow(_User u) {
    return DataRow(cells: [
      // User cell: avatar + name + email
      DataCell(Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _kBlue.withOpacity(0.12),
          child: Text(u.name[0], style: _inter(13, weight: FontWeight.w600, color: _kBlue)),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(u.name, style: _inter(13, weight: FontWeight.w500)),
          Text(u.email, style: _inter(11, color: _kGrey)),
        ]),
      ])),
      // Role badge
      DataCell(_RoleBadge(role: u.role)),
      // Campaign
      DataCell(Text(u.campaign)),
      // Status
      DataCell(StatusBadge(
        label: u.status,
        color: u.status == 'Active' ? _kGreen : _kGrey,
      )),
      // Last Active
      DataCell(Text(u.lastActive, style: _inter(13, color: _kTextLight))),
      // Actions
      DataCell(_ActionBtns(user: u, onEdit: onEdit)),
    ]);
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isManager = role == 'Manager';
    final color = isManager ? _kBlue : _kGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(role, style: _inter(11, weight: FontWeight.w500, color: color)),
    );
  }
}

class _ActionBtns extends StatelessWidget {
  const _ActionBtns({required this.user, required this.onEdit});
  final _User user;
  final ValueChanged<_User> onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _IconBtn(icon: Icons.edit_outlined, tooltip: 'Edit', color: _kBlue, onTap: () => onEdit(user)),
      const SizedBox(width: 4),
      _IconBtn(icon: Icons.person_off_outlined, tooltip: 'Deactivate', color: _kRed, onTap: () {}),
    ]);
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.color, required this.onTap});
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
              color: _hovered ? widget.color.withOpacity(0.10) : Colors.transparent,
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
//  Slide Panel — Add / Edit User
// ─────────────────────────────────────────────
class _UserPanel extends StatelessWidget {
  const _UserPanel({
    required this.isEditMode,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.selectedRole,
    required this.selectedCampaign,
    required this.selectedStatus,
    required this.onRoleChanged,
    required this.onCampaignChanged,
    required this.onStatusChanged,
    required this.onClose,
    required this.onCancel,
    required this.onSave,
  });

  final bool isEditMode;
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl;
  final String selectedRole, selectedCampaign, selectedStatus;
  final ValueChanged<String?> onRoleChanged, onCampaignChanged, onStatusChanged;
  final VoidCallback onClose, onCancel, onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 24, offset: Offset(-4, 0))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder))),
          child: Row(children: [
            Text(isEditMode ? 'Edit User' : 'Add User',
                style: _inter(17, weight: FontWeight.w600)),
            const Spacer(),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 20, color: _kTextLight),
              ),
            ),
          ]),
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FieldLabel('Full Name'),
              const SizedBox(height: 6),
              _OutlinedField(controller: nameCtrl, hint: 'Enter full name'),
              const SizedBox(height: 18),

              _FieldLabel('Email Address'),
              const SizedBox(height: 6),
              _OutlinedField(controller: emailCtrl, hint: 'email@example.com',
                  type: TextInputType.emailAddress),
              const SizedBox(height: 18),

              _FieldLabel('Phone Number'),
              const SizedBox(height: 6),
              _OutlinedField(controller: phoneCtrl, hint: '+91 XXXXX XXXXX',
                  type: TextInputType.phone),
              const SizedBox(height: 18),

              _FieldLabel('Role'),
              const SizedBox(height: 6),
              _Dropdown<String>(value: selectedRole, items: _kRoles, onChanged: onRoleChanged),
              const SizedBox(height: 18),

              _FieldLabel('Assign Campaign'),
              const SizedBox(height: 6),
              _Dropdown<String>(value: selectedCampaign, items: _kCampaigns, onChanged: onCampaignChanged),
              const SizedBox(height: 18),

              _FieldLabel('Status'),
              const SizedBox(height: 6),
              _Dropdown<String>(value: selectedStatus, items: _kStatuses, onChanged: onStatusChanged),
            ]),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTextLight,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onCancel,
                child: Text('Cancel', style: _inter(13, weight: FontWeight.w500, color: _kTextLight)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onSave,
                child: Text('Save User',
                    style: _inter(13, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared small form helpers
// ─────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: _inter(12, weight: FontWeight.w600, color: _kTextLight));
}

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({required this.controller, required this.hint, this.type});
  final TextEditingController controller;
  final String hint;
  final TextInputType? type;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: _inter(13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _inter(13, color: _kGrey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        filled: true, fillColor: _kBgPage,
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: _kBgPage,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          style: _inter(13),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kTextLight),
          onChanged: onChanged,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toString()))).toList(),
        ),
      ),
    );
  }
}
