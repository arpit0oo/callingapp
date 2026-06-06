import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/alert_row.dart';
import '../../shared/widgets/kpi_card.dart';
import '../../shared/widgets/status_badge.dart';

// ─────────────────────────────────────────────
//  Colour + style constants (file-private)
// ─────────────────────────────────────────────
const _kBgPage = Color(0xFFF8F9FA);
const _kBlue = Color(0xFF1A73E8);
const _kGreen = Color(0xFF34A853);
const _kOrange = Color(0xFFFA7B17);
const _kRed = Color(0xFFEA4335);
const _kGrey = Color(0xFF80868B);
const _kText = Color(0xFF202124);
const _kTextLight = Color(0xFF5F6368);
const _kSidebarBorder = Color(0xFFE8EAED);
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
//  Dummy data
// ─────────────────────────────────────────────
const _kKpis = [
  _KpiData('Active Campaigns', '8', Icons.campaign_outlined, _kBlue),
  _KpiData('Leads Processed Today', '5,200', Icons.trending_up, _kGreen),
  _KpiData('Interested Leads Today', '320', Icons.star_outline, _kOrange),
  _KpiData('Pending Callbacks', '1,200', Icons.phone_callback_outlined, _kRed),
];

const _kCampaigns = [
  _CampaignRow('Xpert Tutor', true, '12,500', '340', '87'),
  _CampaignRow('Solar Campaign', true, '5,600', '110', '23'),
  _CampaignRow('DSA Campaign', false, '18,200', '870', '112'),
];

const _kManagers = [
  _ManagerRow('Amit', 3, 120),
  _ManagerRow('Rahul', 2, 75),
  _ManagerRow('Neha', 3, 135),
];

const _kAlerts = [
  _AlertData('Solar Campaign — Warm Queue Backlog', '2h ago'),
  _AlertData('DSA Campaign — Conversion Dropped', '2h ago'),
  _AlertData('Tutor Campaign — Database Exhausting', '2h ago'),
];

// ─────────────────────────────────────────────
//  Dashboard Content
// ─────────────────────────────────────────────

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) => _MainContent();
}

// ─────────────────────────────────────────────
//  Main Content (private — used by DashboardContent)
// ─────────────────────────────────────────────
class _MainContent extends StatelessWidget {
  _MainContent();

  final String _today = () {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }();

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
              Text('Dashboard', style: _inter(20, weight: FontWeight.w700)),
              const Spacer(),
              Text(_today, style: _inter(13, color: _kTextLight)),
              const SizedBox(width: 16),
              Tooltip(
                message: 'Notifications',
                child: Icon(Icons.notifications_none_outlined,
                    size: 22, color: _kTextLight),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Section 1: KPI Strip ──────────────
          _KpiStrip(),
          const SizedBox(height: 28),

          // ── Section 2: Campaign Portfolio ─────
          _CampaignPortfolioCard(),
          const SizedBox(height: 28),

          // ── Section 3: Two-column row ─────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: _ManagerPerformanceCard()),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: _HealthAlertsCard()),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  KPI Strip — uses extracted KpiCard
// ─────────────────────────────────────────────
class _KpiStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: _kKpis.map((kpi) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: kpi == _kKpis.last ? 0 : 16),
            child: KpiCard(
              title: kpi.label,
              value: kpi.value,
              icon: kpi.icon,
              iconColor: kpi.color,
              iconBgColor: kpi.color.withOpacity(0.12),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  Campaign Portfolio — uses extracted StatusBadge
// ─────────────────────────────────────────────
class _CampaignPortfolioCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Campaign Portfolio',
                style: _inter(16, weight: FontWeight.w600)),
          ),
          const Divider(color: _kSidebarBorder, height: 1),
          _buildTable(),
        ],
      ),
    );
  }

  Widget _buildTable() {
    const columns = [
      'Campaign Name',
      'Status',
      'Raw Pending',
      'Warm Pending',
      'Interested Leads',
      'Actions',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 52,
              columnSpacing: 24,
              headingTextStyle:
                  _inter(12, weight: FontWeight.w600, color: _kTextLight),
              dataTextStyle: _inter(13),
              columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: _kCampaigns.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row.name,
                      style: _inter(13, weight: FontWeight.w500))),
                  // ── Extracted StatusBadge ──────
                  DataCell(StatusBadge(
                    label: row.isActive ? 'Active' : 'Paused',
                    color: row.isActive ? _kGreen : _kGrey,
                  )),
                  DataCell(Text(row.rawPending)),
                  DataCell(Text(row.warmPending)),
                  DataCell(Text(row.interestedLeads)),
                  DataCell(
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _kBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        backgroundColor: _kBlue.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {},
                      child: Text('View',
                          style: _inter(12, weight: FontWeight.w500)),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Manager Performance
// ─────────────────────────────────────────────
class _ManagerPerformanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const columns = ['Manager Name', 'Assigned Campaigns', 'Leads Generated'];
    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Manager Performance',
                style: _inter(16, weight: FontWeight.w600)),
          ),
          const Divider(color: _kSidebarBorder, height: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 52,
                    columnSpacing: 24,
                    headingTextStyle: _inter(12,
                        weight: FontWeight.w600, color: _kTextLight),
                    dataTextStyle: _inter(13),
                    columns: columns
                        .map((c) => DataColumn(label: Text(c)))
                        .toList(),
                    rows: _kManagers.map((m) {
                      return DataRow(cells: [
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _kBlue.withOpacity(0.12),
                              child: Text(
                                m.name[0],
                                style: _inter(12,
                                    weight: FontWeight.w600, color: _kBlue),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(m.name,
                                style: _inter(13, weight: FontWeight.w500)),
                          ],
                        )),
                        DataCell(Text(m.campaigns.toString())),
                        DataCell(Text(m.leads.toString())),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Health Alerts — uses extracted AlertRow
// ─────────────────────────────────────────────
class _HealthAlertsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 18, color: _kText),
              const SizedBox(width: 8),
              Text('Alerts', style: _inter(16, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: _kSidebarBorder),
          // ── Extracted AlertRow ─────────────────
          ..._kAlerts.map(
            (a) => AlertRow(message: a.message, timeAgo: a.timestamp),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Immutable data holders (file-private)
// ─────────────────────────────────────────────
class _KpiData {
  const _KpiData(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _CampaignRow {
  const _CampaignRow(this.name, this.isActive, this.rawPending,
      this.warmPending, this.interestedLeads);
  final String name;
  final bool isActive;
  final String rawPending;
  final String warmPending;
  final String interestedLeads;
}

class _ManagerRow {
  const _ManagerRow(this.name, this.campaigns, this.leads);
  final String name;
  final int campaigns;
  final int leads;
}

class _AlertData {
  const _AlertData(this.message, this.timestamp);
  final String message;
  final String timestamp;
}
