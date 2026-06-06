import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/status_badge.dart';

// ─────────────────────────────────────────────
//  Colour constants
// ─────────────────────────────────────────────
const _kBlue = Color(0xFF1A73E8);
const _kGreen = Color(0xFF34A853);
const _kOrange = Color(0xFFFA7B17);
const _kRed = Color(0xFFEA4335);
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
class _Caller {
  const _Caller({
    required this.name,
    required this.campaign,
    required this.status,
    required this.callsToday,
    required this.leadsToday,
    required this.avgHandle,
  });
  final String name, campaign, status, callsToday, leadsToday, avgHandle;
}

const _kCallers = [
  _Caller(name: 'Ravi Kumar',   campaign: 'Xpert Tutor',    status: 'Calling', callsToday: '45', leadsToday: '8',  avgHandle: '4m 20s'),
  _Caller(name: 'Priya Patel',  campaign: 'Solar Campaign', status: 'Idle',    callsToday: '32', leadsToday: '5',  avgHandle: '3m 45s'),
  _Caller(name: 'Suresh Yadav', campaign: 'Xpert Tutor',    status: 'Calling', callsToday: '67', leadsToday: '12', avgHandle: '5m 10s'),
  _Caller(name: 'Anjali Singh', campaign: 'DSA Campaign',   status: 'Break',   callsToday: '28', leadsToday: '4',  avgHandle: '4m 05s'),
  _Caller(name: 'Mohit Sharma', campaign: 'Solar Campaign', status: 'Calling', callsToday: '51', leadsToday: '9',  avgHandle: '3m 55s'),
];

const _kCampaigns = ['Xpert Tutor', 'Solar Campaign', 'DSA Campaign'];
const _kFilterTabs = ['All', 'Active', 'On Break', 'Offline'];

// Dummy recent-activity rows shown in the detail panel
const _kActivity = [
  _ActivityRow('09:14 AM', '+91 98765 43210', 'Interested'),
  _ActivityRow('09:32 AM', '+91 87654 32109', 'Not Interested'),
  _ActivityRow('09:51 AM', '+91 76543 21098', 'Callback'),
  _ActivityRow('10:08 AM', '+91 65432 10987', 'Busy'),
  _ActivityRow('10:25 AM', '+91 54321 09876', 'Interested'),
];

class _ActivityRow {
  const _ActivityRow(this.time, this.phone, this.disposition);
  final String time, phone, disposition;
}

// ─────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────
class CallerManagementContent extends StatefulWidget {
  const CallerManagementContent({super.key});

  @override
  State<CallerManagementContent> createState() =>
      _CallerManagementContentState();
}

class _CallerManagementContentState extends State<CallerManagementContent> {
  int _filterIndex = 0;
  String _search = '';
  bool _panelOpen = false;
  _Caller? _selectedCaller;
  String _panelCampaign = _kCampaigns.first;

  List<_Caller> get _filtered {
    final tab = _kFilterTabs[_filterIndex];
    return _kCallers.where((c) {
      final matchTab = tab == 'All' ||
          (tab == 'Active' && c.status == 'Calling') ||
          (tab == 'On Break' && c.status == 'Break') ||
          (tab == 'Offline' && c.status == 'Idle');
      final matchSearch = _search.isEmpty ||
          c.name.toLowerCase().contains(_search.toLowerCase());
      return matchTab && matchSearch;
    }).toList();
  }

  void _openDetail(_Caller caller) {
    setState(() {
      _selectedCaller = caller;
      _panelCampaign = caller.campaign;
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
          // ── Main scrollable content ───────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Bar ───────────────────────
                Row(children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Callers',
                          style: _inter(20, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Manage and assign callers to campaigns',
                          style: _inter(14, color: _kTextLight)),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text('Assign Caller',
                        style: _inter(13,
                            weight: FontWeight.w600, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Stats Row ─────────────────────
                Row(children: [
                  _StatCard(
                    label: 'Active Callers',
                    value: '12',
                    icon: Icons.headset_mic_outlined,
                    accentColor: _kGreen,
                  ),
                  const SizedBox(width: 16),
                  _StatCard(
                    label: 'On Break',
                    value: '3',
                    icon: Icons.coffee_outlined,
                    accentColor: _kOrange,
                  ),
                  const SizedBox(width: 16),
                  _StatCard(
                    label: 'Offline',
                    value: '5',
                    icon: Icons.person_off_outlined,
                    accentColor: _kGrey,
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Caller Table Card ─────────────
                Container(
                  decoration: _card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search + filter row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40,
                              child: TextField(
                                onChanged: (v) =>
                                    setState(() => _search = v),
                                style: _inter(13),
                                decoration: InputDecoration(
                                  hintText: 'Search callers...',
                                  hintStyle: _inter(13, color: _kGrey),
                                  prefixIcon: const Icon(Icons.search,
                                      size: 18, color: _kGrey),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          const BorderSide(color: _kBorder)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          const BorderSide(color: _kBorder)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: _kBlue, width: 1.5)),
                                  filled: true,
                                  fillColor: _kBgPage,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Filter tabs
                            Row(
                              children:
                                  _kFilterTabs.asMap().entries.map((e) {
                                final active = e.key == _filterIndex;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _filterIndex = e.key),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? _kBlue
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border: Border.all(
                                          color:
                                              active ? _kBlue : _kBorder),
                                    ),
                                    child: Text(e.value,
                                        style: _inter(12,
                                            weight: FontWeight.w500,
                                            color: active
                                                ? Colors.white
                                                : _kTextLight)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: _kBorder, height: 1),
                      _CallerTable(
                        callers: _filtered,
                        onView: _openDetail,
                        onReassign: _openDetail,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),

          // ── Dim overlay ──────────────────────
          if (_panelOpen)
            GestureDetector(
              onTap: _closePanel,
              child:
                  Container(color: Colors.black.withOpacity(0.18)),
            ),

          // ── Slide panel ──────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            right: _panelOpen ? 0 : -460,
            child: _CallerDetailPanel(
              caller: _selectedCaller,
              selectedCampaign: _panelCampaign,
              onCampaignChanged: (v) =>
                  setState(() => _panelCampaign = v!),
              onClose: _closePanel,
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
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });
  final String label, value;
  final IconData icon;
  final Color accentColor;

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
              color: accentColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.25)),
            ),
            child: Icon(icon, size: 20, color: accentColor),
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
//  Caller Table
// ─────────────────────────────────────────────
class _CallerTable extends StatelessWidget {
  const _CallerTable({
    required this.callers,
    required this.onView,
    required this.onReassign,
  });
  final List<_Caller> callers;
  final ValueChanged<_Caller> onView;
  final ValueChanged<_Caller> onReassign;

  static const _columns = [
    'Caller',
    'Assigned Campaign',
    'Status',
    'Calls Today',
    'Leads Today',
    'Avg Handle Time',
    'Actions',
  ];

  @override
  Widget build(BuildContext context) {
    if (callers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
            child: Text('No callers found.',
                style: _inter(14, color: _kGrey))),
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
            headingTextStyle:
                _inter(12, weight: FontWeight.w600, color: _kTextLight),
            dataTextStyle: _inter(13),
            columns:
                _columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: callers.map((c) => _buildRow(c)).toList(),
          ),
        ),
      );
    });
  }

  DataRow _buildRow(_Caller c) {
    final statusColor = _statusColor(c.status);
    return DataRow(cells: [
      // Caller: avatar + name
      DataCell(Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _kBlue.withOpacity(0.12),
          child: Text(c.name[0],
              style: _inter(13, weight: FontWeight.w600, color: _kBlue)),
        ),
        const SizedBox(width: 10),
        Text(c.name, style: _inter(13, weight: FontWeight.w500)),
      ])),
      // Campaign
      DataCell(Text(c.campaign, style: _inter(13, color: _kTextLight))),
      // Status badge
      DataCell(StatusBadge(label: c.status, color: statusColor)),
      // Calls Today
      DataCell(Text(c.callsToday)),
      // Leads Today
      DataCell(Text(c.leadsToday,
          style: _inter(13, weight: FontWeight.w600, color: _kGreen))),
      // Avg Handle Time
      DataCell(Text(c.avgHandle, style: _inter(13, color: _kTextLight))),
      // Actions
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(
            icon: Icons.visibility_outlined,
            tooltip: 'View Detail',
            color: _kBlue,
            onTap: () => onView(c),
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.swap_horiz_outlined,
            tooltip: 'Reassign',
            color: _kTextLight,
            onTap: () => onReassign(c),
          ),
        ],
      )),
    ]);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Calling':
        return _kGreen;
      case 'Break':
        return _kOrange;
      default:
        return _kGrey;
    }
  }
}

// ─────────────────────────────────────────────
//  Caller Detail Panel
// ─────────────────────────────────────────────
class _CallerDetailPanel extends StatelessWidget {
  const _CallerDetailPanel({
    required this.caller,
    required this.selectedCampaign,
    required this.onCampaignChanged,
    required this.onClose,
  });

  final _Caller? caller;
  final String selectedCampaign;
  final ValueChanged<String?> onCampaignChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = caller;
    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x20000000),
              blurRadius: 24,
              offset: Offset(-4, 0)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ───────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          decoration:
              const BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder))),
          child: Row(children: [
            Text('Caller Detail', style: _inter(17, weight: FontWeight.w600)),
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

        // ── Scrollable body ──────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: c == null
                ? Center(
                    child:
                        Text('No caller selected.', style: _inter(14, color: _kGrey)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Avatar + Name + Role ─────────────
                      Center(
                        child: Column(children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: _kBlue.withOpacity(0.12),
                            child: Text(c.name[0],
                                style: _inter(22,
                                    weight: FontWeight.w700, color: _kBlue)),
                          ),
                          const SizedBox(height: 10),
                          Text(c.name,
                              style: _inter(16, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kGrey.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Cold Caller',
                                style: _inter(11,
                                    weight: FontWeight.w500, color: _kGrey)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // ── Reassign Campaign dropdown ────────
                      Text('Assigned Campaign',
                          style: _inter(12,
                              weight: FontWeight.w600, color: _kTextLight)),
                      const SizedBox(height: 6),
                      _Dropdown(
                        value: selectedCampaign,
                        items: _kCampaigns,
                        onChanged: onCampaignChanged,
                      ),
                      const SizedBox(height: 24),

                      // ── Stats grid (2×2) ──────────────────
                      Text('Today\'s Stats',
                          style: _inter(13, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          _StatBox(
                              label: 'Calls Today',
                              value: c.callsToday,
                              color: _kBlue),
                          _StatBox(
                              label: 'Leads Today',
                              value: c.leadsToday,
                              color: _kGreen),
                          _StatBox(
                              label: 'Avg Handle Time',
                              value: c.avgHandle,
                              color: _kOrange),
                          _StatBox(
                              label: 'Shift Duration',
                              value: '5h 42m',
                              color: _kTextLight),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Recent Activity ───────────────────
                      Text('Recent Activity',
                          style: _inter(13, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      ..._kActivity.map((a) => _ActivityTile(row: a)),
                    ],
                  ),
          ),
        ),

        // ── Footer ───────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration:
              const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kRed,
                side: const BorderSide(color: _kRed),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onClose,
              child: Text('Remove from Campaign',
                  style:
                      _inter(13, weight: FontWeight.w600, color: _kRed)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  2×2 Stat Box
// ─────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style:
                  _inter(18, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: _inter(11, color: _kTextLight)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Activity Tile
// ─────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.row});
  final _ActivityRow row;

  Color _dispositionColor(String d) {
    switch (d) {
      case 'Interested':
        return _kGreen;
      case 'Not Interested':
        return _kRed;
      case 'Callback':
        return _kBlue;
      case 'Busy':
        return _kOrange;
      default:
        return _kGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _dispositionColor(row.disposition);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Time
        SizedBox(
          width: 72,
          child: Text(row.time,
              style: _inter(11, color: _kGrey)),
        ),
        // Phone icon + number
        const Icon(Icons.phone_outlined, size: 14, color: _kGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(row.phone, style: _inter(12, color: _kText)),
        ),
        // Disposition badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(row.disposition,
              style: _inter(10, weight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Shared helpers
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

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

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
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: _inter(13),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: _kTextLight),
          onChanged: onChanged,
          items: items
              .map((i) =>
                  DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
        ),
      ),
    );
  }
}
