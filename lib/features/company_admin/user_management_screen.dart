import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:callingapp/services/app_session.dart';
import 'package:callingapp/services/user_service.dart';
import 'package:callingapp/services/campaign_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/services.dart';
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

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

String _displayRole(String role) {
  final r = role.toLowerCase().trim();
  if (r == 'manager') return 'Manager';
  if (r == 'cold_caller' || r == 'cold') return 'Cold Caller';
  if (r == 'warm_caller' || r == 'warm') return 'Warm Caller';
  return 'Cold Caller'; // fallback to avoid crash
}

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
    this.docId = '',
  });
  final String name, email, role, campaign, status, lastActive, phone;
  final String docId;
}

const _kCampaignsFallback = ['Xpert Tutor', 'Solar Campaign', 'DSA Campaign'];
const _kRoles = ['Manager', 'Cold Caller', 'Warm Caller'];
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
  String _editingDocId = '';

  // Form controllers
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole     = _kRoles.first;
  String _selectedCampaign = _kCampaignsFallback.first;
  String _selectedStatus   = _kStatuses.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }



  void _openCreate() {
    _nameCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _passwordCtrl.clear();
    _obscurePassword = true;
    _selectedRole     = _kRoles.first;
    _selectedCampaign = _kCampaignsFallback.first;
    _selectedStatus   = _kStatuses.first;
    setState(() { _isEditMode = false; _editingUser = null; _editingDocId = ''; _panelOpen = true; });
  }

  void _openEdit(_User u) {
    _nameCtrl.text  = u.name;
    _emailCtrl.text = u.email;
    // Strip non-digits so the digits-only phone field accepts it
    _phoneCtrl.text = u.phone.replaceAll(RegExp(r'\D'), '');
    _passwordCtrl.clear(); // password not shown / edited in edit mode
    _selectedRole     = u.role;
    _selectedCampaign = u.campaign == '\u2014' ? _kCampaignsFallback.first : u.campaign;
    _selectedStatus   = u.status;
    setState(() { _isEditMode = true; _editingUser = u; _editingDocId = u.docId; _panelOpen = true; });
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
                StreamBuilder<QuerySnapshot>(
                  stream: UserService.getUsers(AppSession.tenantId),
                  builder: (context, snapshot) {
                    int totalUsers = 0;
                    int activeManagers = 0;
                    int activeCallers = 0;

                    if (snapshot.hasData) {
                      final docs = snapshot.data!.docs;
                      totalUsers = docs.length;
                      for (final doc in docs) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final role = (data['role'] as String? ?? '').toLowerCase();
                        final status = (data['status'] as String? ?? '').toLowerCase();

                        if (role == 'manager' && status == 'active') {
                          activeManagers++;
                        } else if ((role == 'cold_caller' || role == 'warm_caller') && status == 'active') {
                          activeCallers++;
                        }
                      }
                    }

                    return Row(children: [
                      _StatCard(
                        label: 'Total Users',
                        value: totalUsers.toString(),
                        icon: Icons.people_outline,
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        label: 'Active Managers',
                        value: activeManagers.toString(),
                        icon: Icons.manage_accounts_outlined,
                      ),
                      const SizedBox(width: 16),
                      _StatCard(
                        label: 'Active Callers',
                        value: activeCallers.toString(),
                        icon: Icons.headset_mic_outlined,
                      ),
                    ]);
                  },
                ),
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
                    StreamBuilder<QuerySnapshot>(
                      stream: UserService.getUsers(AppSession.tenantId),
                      builder: (context, snapshot) {
                        final docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
                        final tab = _kFilterTabs[_filterIndex];
                        final liveDocs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final role = (data['role'] as String? ?? '').toLowerCase();
                          final name = (data['name'] as String? ?? '').toLowerCase();
                          final matchTab = tab == 'All' ||
                              (tab == 'Managers' && role == 'manager') ||
                              (tab == 'Callers' && (role == 'cold_caller' || role == 'warm_caller' || role == 'caller' || role == 'cold' || role == 'warm'));
                          final matchSearch = _search.isEmpty ||
                              name.contains(_search.toLowerCase());
                          return matchTab && matchSearch;
                        }).toList();
                        final liveUsers = liveDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final campaigns = data['assignedCampaigns'] as List<dynamic>?;
                          final campaign = (campaigns != null && campaigns.isNotEmpty)
                              ? campaigns.first.toString()
                              : '\u2014';
                          final ts = data['lastActive'] as Timestamp?;
                          final lastActive = ts != null
                              ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                              : '\u2014';
                          return _User(
                            docId: doc.id,
                            name: data['name'] as String? ?? '\u2014',
                            email: data['email'] as String? ?? '\u2014',
                            role: _displayRole(data['role'] as String? ?? 'cold_caller'),
                            campaign: campaign,
                            status: _capitalize(data['status'] as String? ?? 'inactive'),
                            lastActive: lastActive,
                            phone: data['phone'] as String? ?? '',
                          );
                        }).toList();
                        return _UserTable(users: liveUsers, onEdit: _openEdit, tenantId: AppSession.tenantId);
                      },
                    ),
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
              passwordCtrl: _passwordCtrl,
              obscurePassword: _obscurePassword,
              onObscureToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              selectedRole: _selectedRole,
              selectedCampaign: _selectedCampaign,
              selectedStatus: _selectedStatus,
              onRoleChanged: (v) => setState(() => _selectedRole = v!),
              onCampaignChanged: (v) => setState(() => _selectedCampaign = v!),
              onStatusChanged: (v) => setState(() => _selectedStatus = v!),
              onClose: _closePanel,
              onCancel: _closePanel,
              onSave: () async {
                final payload = {
                  'name': _nameCtrl.text.trim(),
                  'email': _emailCtrl.text.trim(),
                  'phone': _phoneCtrl.text.trim(),
                  'role': _selectedRole.toLowerCase().replaceAll(' ', '_'),
                  'assignedCampaigns': [_selectedCampaign],
                  'status': _selectedStatus.toLowerCase(),
                };

                if (_isEditMode && _editingDocId.isNotEmpty) {
                  // Edit path — no Auth changes, just update Firestore.
                  await UserService.updateUser(
                    AppSession.tenantId,
                    _editingDocId,
                    payload,
                  );
                } else {
                  // Create path — create Firebase Auth account first.
                  String newUid;
                  try {
                    final credential = await FirebaseAuth.instance
                        .createUserWithEmailAndPassword(
                      email: _emailCtrl.text.trim(),
                      password: _passwordCtrl.text,
                    );
                    newUid = credential.user!.uid;
                  } on FirebaseAuthException catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.message ?? 'Failed to create Auth account.',
                            style: _inter(13, color: Colors.white),
                          ),
                          backgroundColor: _kRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }
                    return; // Do not write to Firestore on Auth failure.
                  }

                  // Auth succeeded — write Firestore document with the real UID.
                  await UserService.createUser(
                    AppSession.tenantId,
                    newUid,
                    {
                      'createdAt': FieldValue.serverTimestamp(),
                      'tenantId': AppSession.tenantId,
                      ...payload,
                    },
                  );
                  // Patch selections that UserService.createUser may override.
                  await UserService.updateUser(
                    AppSession.tenantId,
                    newUid,
                    {
                      'assignedCampaigns': [_selectedCampaign],
                      'status': _selectedStatus.toLowerCase(),
                    },
                  );
                }
                _closePanel();
              },
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
  const _UserTable({required this.users, required this.onEdit, required this.tenantId});
  final List<_User> users;
  final ValueChanged<_User> onEdit;
  final String tenantId;

  static const _columns = ['User', 'Role', 'Assigned Campaign', 'Status', 'Last Active', 'Actions'];

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No users yet.', style: _inter(14, color: _kGrey))),
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
      DataCell(_ActionBtns(user: u, onEdit: onEdit, tenantId: tenantId)),
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
  const _ActionBtns({
    required this.user,
    required this.onEdit,
    required this.tenantId,
  });
  final _User user;
  final ValueChanged<_User> onEdit;
  final String tenantId;

  bool get _isLive => user.docId.isNotEmpty;

  Future<void> _toggleStatus(BuildContext context) async {
    if (!_isLive) return;
    final newStatus = user.status.toLowerCase() == 'active' ? 'inactive' : 'active';
    await UserService.updateUser(tenantId, user.docId, {'status': newStatus});
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!_isLive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete User', style: _inter(16, weight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
          style: _inter(13, color: _kTextLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: _inter(13, color: _kTextLight)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: _inter(13, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(user.docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = user.status.toLowerCase() == 'active';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _IconBtn(
        icon: Icons.edit_outlined,
        tooltip: 'Edit',
        color: _kBlue,
        onTap: () => onEdit(user),
      ),
      const SizedBox(width: 4),
      _IconBtn(
        icon: isActive ? Icons.person_off_outlined : Icons.person_outlined,
        tooltip: isActive ? 'Deactivate' : 'Activate',
        color: _isLive ? _kRed : _kGrey,
        onTap: () => _toggleStatus(context),
      ),
      const SizedBox(width: 4),
      _IconBtn(
        icon: Icons.delete_outline,
        tooltip: 'Delete',
        color: _isLive ? _kRed : _kGrey,
        onTap: () => _confirmDelete(context),
      ),
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
class _UserPanel extends StatefulWidget {
  const _UserPanel({
    required this.isEditMode,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onObscureToggle,
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
  final TextEditingController nameCtrl, emailCtrl, phoneCtrl, passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onObscureToggle;
  final String selectedRole, selectedCampaign, selectedStatus;
  final ValueChanged<String?> onRoleChanged, onCampaignChanged, onStatusChanged;
  final VoidCallback onClose, onCancel, onSave;

  @override
  State<_UserPanel> createState() => _UserPanelState();
}

class _UserPanelState extends State<_UserPanel> {
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  static final _emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$');

  /// Returns true if all fields are valid; populates error strings otherwise.
  bool _validate() {
    final name        = widget.nameCtrl.text.trim();
    final email       = widget.emailCtrl.text.trim();
    final password    = widget.passwordCtrl.text;
    final phoneDigits = widget.phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');

    String? nameErr  = name.isEmpty ? 'Name is required.' : null;
    String? emailErr = email.isEmpty
        ? 'Email is required.'
        : (!_emailRegex.hasMatch(email) ? 'Enter a valid email address.' : null);
    String? phoneErr = phoneDigits.length != 10 ? 'Enter exactly 10 digits.' : null;
    // Password is only required when creating a new user.
    String? passwordErr;
    if (!widget.isEditMode) {
      if (password.isEmpty) {
        passwordErr = 'Password is required.';
      } else if (password.length < 6) {
        passwordErr = 'Password must be at least 6 characters.';
      }
    }

    setState(() {
      _nameError     = nameErr;
      _emailError    = emailErr;
      _phoneError    = phoneErr;
      _passwordError = passwordErr;
    });
    return nameErr == null && emailErr == null &&
           phoneErr == null && passwordErr == null;
  }

  Widget _errorText(String? msg) => msg == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(msg, style: _inter(11, color: _kRed)),
        );

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
            Text(widget.isEditMode ? 'Edit User' : 'Add User',
                style: _inter(17, weight: FontWeight.w600)),
            const Spacer(),
            InkWell(
              onTap: widget.onClose,
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
              _OutlinedField(controller: widget.nameCtrl, hint: 'Enter full name',
                  hasError: _nameError != null),
              _errorText(_nameError),
              const SizedBox(height: 14),

              _FieldLabel('Email Address'),
              const SizedBox(height: 6),
              _OutlinedField(controller: widget.emailCtrl, hint: 'email@example.com',
                  type: TextInputType.emailAddress, hasError: _emailError != null),
              _errorText(_emailError),
              const SizedBox(height: 14),

              _FieldLabel('Phone Number'),
              const SizedBox(height: 6),
              TextField(
                controller: widget.phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: _inter(13),
                decoration: InputDecoration(
                  hintText: '10-digit mobile number',
                  hintStyle: _inter(13, color: _kGrey),
                  counterText: '',
                  errorText: null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _phoneError != null ? _kRed : _kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _phoneError != null ? _kRed : _kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _phoneError != null ? _kRed : _kBlue, width: 1.5)),
                  filled: true, fillColor: _kBgPage,
                ),
              ),
              _errorText(_phoneError),
              const SizedBox(height: 14),

              // Password field — only shown when creating a new user.
              if (!widget.isEditMode) ...[
                _FieldLabel('Password'),
                const SizedBox(height: 6),
                _OutlinedField(
                  controller: widget.passwordCtrl,
                  hint: '••••••••',
                  obscureText: widget.obscurePassword,
                  hasError: _passwordError != null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      widget.obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: _kGrey,
                    ),
                    onPressed: widget.onObscureToggle,
                    splashRadius: 20,
                  ),
                ),
                _errorText(_passwordError),
                const SizedBox(height: 14),
              ],

              _FieldLabel('Role'),
              const SizedBox(height: 6),
              _Dropdown<String>(value: widget.selectedRole, items: _kRoles, onChanged: widget.onRoleChanged),
              const SizedBox(height: 18),

              _FieldLabel('Assign Campaign'),
              const SizedBox(height: 6),
              StreamBuilder<QuerySnapshot>(
                stream: CampaignService.getCampaigns(AppSession.tenantId),
                builder: (context, snapshot) {
                  final docs = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
                  final campaigns = docs
                      .map((d) => (d.data() as Map<String, dynamic>)['name'] as String? ?? '')
                      .where((n) => n.isNotEmpty)
                      .toList();
                  final items = campaigns.isEmpty ? _kCampaignsFallback : campaigns;
                  final current = items.contains(widget.selectedCampaign) ? widget.selectedCampaign : items.first;
                  return _Dropdown<String>(value: current, items: items, onChanged: widget.onCampaignChanged);
                },
              ),
              const SizedBox(height: 18),

              _FieldLabel('Status'),
              const SizedBox(height: 6),
              _Dropdown<String>(value: widget.selectedStatus, items: _kStatuses, onChanged: widget.onStatusChanged),
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
                onPressed: widget.onCancel,
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
                onPressed: () {
                  if (_validate()) widget.onSave();
                },
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
  const _OutlinedField({
    required this.controller,
    required this.hint,
    this.type,
    this.hasError = false,
    this.obscureText = false,
    this.suffixIcon,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? type;
  final bool hasError;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? _kRed : _kBorder;
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscureText,
      style: _inter(13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _inter(13, color: _kGrey),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: hasError ? _kRed : _kBlue, width: 1.5)),
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
