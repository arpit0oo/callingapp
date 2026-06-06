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
class _Lead {
  const _Lead({
    required this.name,
    required this.phone,
    required this.campaign,
    required this.caller,
    required this.disposition,
    required this.callTime,
  });
  final String name, phone, campaign, caller, disposition, callTime;
}

const _kLeads = [
  _Lead(name: 'Rajesh Kumar', phone: '+91 98765 43210', campaign: 'Xpert Tutor',    caller: 'Ravi Kumar',   disposition: 'Interested',      callTime: '4m 32s'),
  _Lead(name: 'Sunita Devi',  phone: '+91 87654 32109', campaign: 'Solar Campaign', caller: 'Priya Patel',  disposition: 'No Need',         callTime: '1m 12s'),
  _Lead(name: 'Amit Gupta',   phone: '+91 76543 21098', campaign: 'DSA Campaign',   caller: 'Suresh Yadav', disposition: 'WTL',             callTime: '3m 45s'),
  _Lead(name: 'Priya Singh',  phone: '+91 65432 10987', campaign: 'Xpert Tutor',    caller: 'Anjali Singh', disposition: 'DNC',             callTime: '0m 45s'),
  _Lead(name: 'Rahul Verma',  phone: '+91 54321 09876', campaign: 'Solar Campaign', caller: 'Mohit Sharma', disposition: 'Interested',      callTime: '5m 20s'),
  _Lead(name: 'Neha Patel',   phone: '+91 43210 98765', campaign: 'DSA Campaign',   caller: 'Ravi Kumar',   disposition: 'Busy',            callTime: '0m 30s'),
];

const _kCampaigns = ['All Campaigns', 'Xpert Tutor', 'Solar Campaign', 'DSA Campaign'];
const _kDispositions = ['All Dispositions', 'Interested', 'No Need', 'WTL', 'DNC', 'Busy'];

Color _dispositionColor(String d) {
  switch (d) {
    case 'Interested': return _kGreen;
    case 'DNC':        return _kRed;
    case 'WTL':        return _kBlue;
    case 'Busy':       return _kOrange;
    default:           return _kGrey;
  }
}

// ─────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────
class LeadsContent extends StatefulWidget {
  const LeadsContent({super.key});

  @override
  State<LeadsContent> createState() => _LeadsContentState();
}

class _LeadsContentState extends State<LeadsContent> {
  int _modeIndex = 0; // 0 = Audit, 1 = Search
  bool _panelOpen = false;
  _Lead? _selectedLead;

  // Audit filters
  String _filterCampaign = _kCampaigns.first;
  String _filterDisposition = _kDispositions.first;

  // Search
  String _searchQuery = '';

  List<_Lead> get _auditLeads => _kLeads.where((l) {
        final matchC = _filterCampaign == 'All Campaigns' || l.campaign == _filterCampaign;
        final matchD = _filterDisposition == 'All Dispositions' || l.disposition == _filterDisposition;
        return matchC && matchD;
      }).toList();

  List<_Lead> get _searchLeads => _searchQuery.isEmpty
      ? []
      : _kLeads.where((l) =>
          l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.phone.contains(_searchQuery)).toList();

  void _openDetail(_Lead lead) =>
      setState(() { _selectedLead = lead; _panelOpen = true; });
  void _closePanel() => setState(() => _panelOpen = false);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _kBgPage,
      child: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Top Bar ─────────────────────────
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Leads', style: _inter(20, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Audit and search processed leads',
                    style: _inter(14, color: _kTextLight)),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kTextLight,
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {},
                icon: const Icon(Icons.download, size: 17),
                label: Text('Export', style: _inter(13, weight: FontWeight.w500, color: _kTextLight)),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Mode Tabs ────────────────────────
            Container(
              decoration: _card(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Tab header
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _kBorder))),
                  child: Row(children: [
                    _ModeTab(label: 'Lead Audit',  index: 0, activeIndex: _modeIndex,
                        onTap: () => setState(() => _modeIndex = 0)),
                    _ModeTab(label: 'Lead Search', index: 1, activeIndex: _modeIndex,
                        onTap: () => setState(() => _modeIndex = 1)),
                  ]),
                ),

                // Tab body
                if (_modeIndex == 0) _AuditBody(
                  leads: _auditLeads,
                  filterCampaign: _filterCampaign,
                  filterDisposition: _filterDisposition,
                  onCampaignChanged: (v) => setState(() => _filterCampaign = v!),
                  onDispositionChanged: (v) => setState(() => _filterDisposition = v!),
                  onView: _openDetail,
                ) else _SearchBody(
                  query: _searchQuery,
                  leads: _searchLeads,
                  onQueryChanged: (v) => setState(() => _searchQuery = v),
                  onView: _openDetail,
                ),
              ]),
            ),
            const SizedBox(height: 28),
          ]),
        ),

        // ── Dim overlay ──────────────────────
        if (_panelOpen)
          GestureDetector(
            onTap: _closePanel,
            child: Container(color: Colors.black.withOpacity(0.18)),
          ),

        // ── Slide panel ──────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: 0, bottom: 0,
          right: _panelOpen ? 0 : -460,
          child: _LeadDetailPanel(lead: _selectedLead, onClose: _closePanel),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Mode Tab
// ─────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.index,
      required this.activeIndex, required this.onTap});
  final String label;
  final int index, activeIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = index == activeIndex;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _kBlue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(label,
            style: _inter(14,
                weight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? _kBlue : _kTextLight)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Audit Body
// ─────────────────────────────────────────────
class _AuditBody extends StatelessWidget {
  const _AuditBody({
    required this.leads,
    required this.filterCampaign,
    required this.filterDisposition,
    required this.onCampaignChanged,
    required this.onDispositionChanged,
    required this.onView,
  });
  final List<_Lead> leads;
  final String filterCampaign, filterDisposition;
  final ValueChanged<String?> onCampaignChanged, onDispositionChanged;
  final ValueChanged<_Lead> onView;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Filter row
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(children: [
          _FilterDropdown(value: filterCampaign,    items: _kCampaigns,    onChanged: onCampaignChanged),
          const SizedBox(width: 12),
          _FilterDropdown(value: filterDisposition, items: _kDispositions, onChanged: onDispositionChanged),
          const SizedBox(width: 12),
          // Dummy date range
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kTextLight,
              side: const BorderSide(color: _kBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text('Jun 1 – Jun 6', style: _inter(13, color: _kTextLight)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      const Divider(color: _kBorder, height: 1),
      _LeadTable(leads: leads, onView: onView),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Search Body
// ─────────────────────────────────────────────
class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.query,
    required this.leads,
    required this.onQueryChanged,
    required this.onView,
  });
  final String query;
  final List<_Lead> leads;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_Lead> onView;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SizedBox(
          height: 48,
          child: TextField(
            onChanged: onQueryChanged,
            style: _inter(14),
            decoration: InputDecoration(
              hintText: 'Search by name or phone number...',
              hintStyle: _inter(14, color: _kGrey),
              prefixIcon: const Icon(Icons.search, size: 20, color: _kGrey),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              filled: true, fillColor: _kBgPage,
            ),
          ),
        ),
      ),
      if (query.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 56),
          child: Column(children: [
            Icon(Icons.manage_search, size: 48, color: _kGrey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text('Enter a name or phone to search',
                style: _inter(14, color: _kGrey)),
          ]),
        )
      else ...[
        const Divider(color: _kBorder, height: 1),
        _LeadTable(leads: leads, onView: onView),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────
//  Lead Table
// ─────────────────────────────────────────────
class _LeadTable extends StatelessWidget {
  const _LeadTable({required this.leads, required this.onView});
  final List<_Lead> leads;
  final ValueChanged<_Lead> onView;

  static const _columns = [
    'Lead Name', 'Phone', 'Campaign', 'Caller',
    'Disposition', 'Call Time', 'Actions',
  ];

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No leads found.', style: _inter(14, color: _kGrey))),
      );
    }
    return LayoutBuilder(builder: (_, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            columnSpacing: 24,
            headingTextStyle: _inter(12, weight: FontWeight.w600, color: _kTextLight),
            dataTextStyle: _inter(13),
            columns: _columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: leads.map((l) => _buildRow(l)).toList(),
          ),
        ),
      );
    });
  }

  DataRow _buildRow(_Lead l) {
    final dColor = _dispositionColor(l.disposition);
    return DataRow(cells: [
      DataCell(Text(l.name, style: _inter(13, weight: FontWeight.w500))),
      DataCell(Text(l.phone, style: _inter(13, color: _kTextLight))),
      DataCell(Text(l.campaign)),
      DataCell(Row(children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: _kBlue.withOpacity(0.12),
          child: Text(l.caller[0], style: _inter(10, weight: FontWeight.w600, color: _kBlue)),
        ),
        const SizedBox(width: 8),
        Text(l.caller),
      ])),
      DataCell(StatusBadge(label: l.disposition, color: dColor)),
      DataCell(Text(l.callTime, style: _inter(13, color: _kTextLight))),
      DataCell(_ViewBtn(onTap: () => onView(l))),
    ]);
  }
}

// ─────────────────────────────────────────────
//  View button
// ─────────────────────────────────────────────
class _ViewBtn extends StatefulWidget {
  const _ViewBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ViewBtn> createState() => _ViewBtnState();
}

class _ViewBtnState extends State<_ViewBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? _kBlue.withOpacity(0.10) : _kBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('View', style: _inter(12, weight: FontWeight.w600, color: _kBlue)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Lead Detail Panel
// ─────────────────────────────────────────────
class _LeadDetailPanel extends StatelessWidget {
  const _LeadDetailPanel({required this.lead, required this.onClose});
  final _Lead? lead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = lead;
    return Container(
      width: 440,
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
            Text('Lead Detail', style: _inter(17, weight: FontWeight.w600)),
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

        Expanded(
          child: l == null
              ? Center(child: Text('No lead selected.', style: _inter(14, color: _kGrey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Lead identity ──────────────────
                    Text(l.name, style: _inter(18, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(l.phone, style: _inter(13, color: _kGrey)),
                    const SizedBox(height: 14),
                    Row(children: [
                      _PanelBadge(label: l.campaign, color: _kBlue),
                      const SizedBox(width: 8),
                      _PanelBadge(label: l.disposition, color: _dispositionColor(l.disposition)),
                    ]),
                    const SizedBox(height: 24),

                    // ── Call Information ───────────────
                    _SectionLabel('Call Information'),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.4,
                      children: [
                        _InfoBox(label: 'Caller',        value: l.caller),
                        _InfoBox(label: 'Call Duration', value: l.callTime),
                        _InfoBox(label: 'Call Date',     value: 'Jun 6, 2026'),
                        _InfoBox(label: 'Attempts',      value: '2'),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Form Data ─────────────────────
                    _SectionLabel('Form Data'),
                    const SizedBox(height: 10),
                    _FormDataRow(label: 'Full Name',      value: l.name),
                    _FormDataRow(label: 'City',           value: 'Mumbai'),
                    _FormDataRow(label: 'Monthly Income', value: '₹45,000'),
                    _FormDataRow(label: 'Interest Level', value: 'High'),
                    const SizedBox(height: 24),

                    // ── Notes ─────────────────────────
                    _SectionLabel('Caller Notes'),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kBgPage,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Text(
                        'Customer expressed strong interest in the product. Requested a follow-up call next week. Preferred time: 6–8 PM.',
                        style: _inter(13, color: _kText),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Call History ──────────────────
                    _SectionLabel('Call History'),
                    const SizedBox(height: 10),
                    _CallHistoryRow(date: 'Jun 5, 2026 – 03:20 PM', disposition: 'Busy',      color: _kOrange),
                    _CallHistoryRow(date: 'Jun 4, 2026 – 11:45 AM', disposition: 'No Answer', color: _kGrey),
                  ]),
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Panel sub-widgets
// ─────────────────────────────────────────────
class _PanelBadge extends StatelessWidget {
  const _PanelBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: _inter(11, weight: FontWeight.w600, color: color)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label, style: _inter(13, weight: FontWeight.w600)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _kBorder)),
      ]);
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kBgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: _inter(10, color: _kGrey)),
        const SizedBox(height: 3),
        Text(value, style: _inter(13, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _FormDataRow extends StatelessWidget {
  const _FormDataRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text(label, style: _inter(12, color: _kTextLight)),
        ),
        Expanded(child: Text(value, style: _inter(13, weight: FontWeight.w500))),
      ]),
    );
  }
}

class _CallHistoryRow extends StatelessWidget {
  const _CallHistoryRow({required this.date, required this.disposition, required this.color});
  final String date, disposition;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        const Icon(Icons.history, size: 15, color: _kGrey),
        const SizedBox(width: 8),
        Expanded(child: Text(date, style: _inter(12, color: _kTextLight))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(disposition, style: _inter(10, weight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Filter dropdown helper
// ─────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: _inter(13),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kTextLight),
          onChanged: onChanged,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        ),
      ),
    );
  }
}
