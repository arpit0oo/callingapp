import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../shared/widgets/alert_row.dart';
import '../../shared/widgets/kpi_card.dart';
import '../../shared/widgets/status_badge.dart';

// ── colour constants ──────────────────────────────────────────────────────────
const _kBgPage        = Color(0xFFF8F9FA);
const _kBlue          = Color(0xFF1A73E8);
const _kGreen         = Color(0xFF34A853);
const _kOrange        = Color(0xFFFA7B17);
const _kRed           = Color(0xFFEA4335);
const _kGrey          = Color(0xFF80868B);
const _kText          = Color(0xFF202124);
const _kTextLight     = Color(0xFF5F6368);
const _kSidebarBorder = Color(0xFFE8EAED);
const _kCardShadow    = Color(0x14000000);

TextStyle _inter(double size, {FontWeight weight = FontWeight.w400, Color color = _kText}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

BoxDecoration _card({double radius = 8}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: _kCardShadow, blurRadius: 6, offset: Offset(0, 2))],
    );

// ── hardcoded fallbacks ───────────────────────────────────────────────────────
const _kFallbackCampaigns = [
  _CampaignRow('Xpert Tutor',   true,  '12,500', '340'),
  _CampaignRow('Solar Campaign',true,  '5,600',  '110'),
  _CampaignRow('DSA Campaign',  false, '18,200', '870'),
];
const _kFallbackManagers = [
  _ManagerRow('Amit',  3),
  _ManagerRow('Rahul', 2),
  _ManagerRow('Neha',  3),
];
const _kAlerts = [
  _AlertData('Solar Campaign — Warm Queue Backlog',    '2h ago'),
  _AlertData('DSA Campaign — Conversion Dropped',      '2h ago'),
  _AlertData('Tutor Campaign — Database Exhausting',   '2h ago'),
];

// ── KPI data holder ───────────────────────────────────────────────────────────
class _KpiResult {
  final int activeCampaigns;
  final int leadsToday;
  final int interestedToday;
  final int pendingCallbacks;
  const _KpiResult(this.activeCampaigns, this.leadsToday, this.interestedToday, this.pendingCallbacks);
}

// ── today range helper ────────────────────────────────────────────────────────
Timestamp _todayStart() {
  final now = DateTime.now();
  return Timestamp.fromDate(DateTime(now.year, now.month, now.day));
}
Timestamp _tomorrowStart() {
  final now = DateTime.now();
  return Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1));
}

// ── Firestore KPI fetch ───────────────────────────────────────────────────────
Future<_KpiResult> _fetchKpis(String tenantId) async {
  try {
    final db   = FirebaseFirestore.instance;
    final base = db.collection('tenants').doc(tenantId);
    final t0   = _todayStart();
    final t1   = _tomorrowStart();

    final results = await Future.wait([
      base.collection('campaigns')
          .where('status', isEqualTo: 'active')
          .count()
          .get(),
      base.collection('leads')
          .where('createdAt', isGreaterThanOrEqualTo: t0)
          .where('createdAt', isLessThan: t1)
          .count()
          .get(),
      base.collection('leads')
          .where('dispositionLabel', isEqualTo: 'Interested')
          .where('createdAt', isGreaterThanOrEqualTo: t0)
          .where('createdAt', isLessThan: t1)
          .count()
          .get(),
      base.collection('callbacks')
          .where('status', isEqualTo: 'pending')
          .count()
          .get(),
    ]);

    return _KpiResult(
      results[0].count ?? 0,
      results[1].count ?? 0,
      results[2].count ?? 0,
      results[3].count ?? 0,
    );
  } catch (_) {
    return const _KpiResult(0, 0, 0, 0);
  }
}

// ─────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});
  @override
  Widget build(BuildContext context) => _MainContent();
}

class _MainContent extends StatefulWidget {
  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> {
  late Future<_KpiResult> _kpiFuture;
  final String _today = () {
    final now = DateTime.now();
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }();

  @override
  void initState() {
    super.initState();
    _kpiFuture = _fetchKpis(AppSession.tenantId);
  }

  void _refresh() => setState(() {
    _kpiFuture = _fetchKpis(AppSession.tenantId);
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBgPage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──────────────────────────
            Row(children: [
              Text('Dashboard', style: _inter(20, weight: FontWeight.w700)),
              const Spacer(),
              Text(_today, style: _inter(13, color: _kTextLight)),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_outlined, size: 20, color: _kTextLight),
                onPressed: _refresh,
              ),
              const Icon(Icons.notifications_none_outlined, size: 22, color: _kTextLight),
            ]),
            const SizedBox(height: 24),

            // ── Section 1: KPI Strip ──────────────
            _KpiStrip(future: _kpiFuture),
            const SizedBox(height: 28),

            // ── Section 2: Campaign Portfolio ─────
            const _CampaignPortfolioCard(),
            const SizedBox(height: 28),

            // ── Section 3: Two-column row ─────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(flex: 6, child: _ManagerPerformanceCard()),
                SizedBox(width: 20),
                Expanded(flex: 4, child: _HealthAlertsCard()),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  KPI Strip — FutureBuilder
// ─────────────────────────────────────────────
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.future});
  final Future<_KpiResult> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_KpiResult>(
      future: future,
      builder: (ctx, snap) {
        final data = snap.data;
        final kpis = [
          (
            'Active Campaigns',
            snap.hasError ? '0' : (data != null ? '${data.activeCampaigns}' : '—'),
            Icons.campaign_outlined,
            _kBlue,
          ),
          (
            'Leads Processed Today',
            snap.hasError ? '0' : (data != null ? '${data.leadsToday}' : '—'),
            Icons.trending_up,
            _kGreen,
          ),
          (
            'Interested Leads Today',
            snap.hasError ? '0' : (data != null ? '${data.interestedToday}' : '—'),
            Icons.star_outline,
            _kOrange,
          ),
          (
            'Pending Callbacks',
            snap.hasError ? '0' : (data != null ? '${data.pendingCallbacks}' : '—'),
            Icons.phone_callback_outlined,
            _kRed,
          ),
        ];
        return Row(
          children: kpis.asMap().entries.map((e) {
            final i   = e.key;
            final kpi = e.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < kpis.length - 1 ? 16 : 0),
                child: Stack(children: [
                  KpiCard(
                    title:      kpi.$1,
                    value:      kpi.$2,
                    icon:       kpi.$3,
                    iconColor:  kpi.$4,
                    iconBgColor: kpi.$4.withOpacity(0.12),
                  ),
                  if (snap.connectionState == ConnectionState.waiting)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Campaign Portfolio — StreamBuilder
// ─────────────────────────────────────────────
class _CampaignPortfolioCard extends StatelessWidget {
  const _CampaignPortfolioCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Campaign Portfolio', style: _inter(16, weight: FontWeight.w600)),
          ),
          const Divider(color: _kSidebarBorder, height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tenants')
                .doc(AppSession.tenantId)
                .collection('campaigns')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              List<_CampaignRow> rows;
              if (snap.hasData && snap.data!.docs.isNotEmpty) {
                rows = snap.data!.docs.map((d) {
                  final m = d.data() as Map<String, dynamic>;
                  final raw  = m['rawQueueCount']  ?? 0;
                  final warm = m['warmQueueCount']  ?? 0;
                  return _CampaignRow(
                    m['name']   as String? ?? d.id,
                    (m['status'] as String? ?? '') == 'active',
                    '$raw',
                    '$warm',
                  );
                }).toList();
              } else {
                rows = _kFallbackCampaigns;
              }
              return _CampaignTable(rows: rows, loading: snap.connectionState == ConnectionState.waiting);
            },
          ),
        ],
      ),
    );
  }
}

class _CampaignTable extends StatelessWidget {
  const _CampaignTable({required this.rows, required this.loading});
  final List<_CampaignRow> rows;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const columns = ['Campaign Name','Status','Raw Pending','Warm Pending','Actions'];
    return Stack(children: [
      LayoutBuilder(builder: (ctx, con) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: con.maxWidth),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            headingTextStyle: _inter(12, weight: FontWeight.w600, color: _kTextLight),
            dataTextStyle: _inter(13),
            columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: rows.map((row) => DataRow(cells: [
              DataCell(Text(row.name, style: _inter(13, weight: FontWeight.w500))),
              DataCell(StatusBadge(
                label: row.isActive ? 'Active' : 'Paused',
                color: row.isActive ? _kGreen : _kGrey,
              )),
              DataCell(Text(row.rawPending)),
              DataCell(Text(row.warmPending)),
              DataCell(TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _kBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  backgroundColor: _kBlue.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {},
                child: Text('View', style: _inter(12, weight: FontWeight.w500)),
              )),
            ])).toList(),
          ),
        ),
      )),
      if (loading)
        const Positioned(top: 8, right: 12,
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Manager Performance — StreamBuilder
// ─────────────────────────────────────────────
class _ManagerPerformanceCard extends StatelessWidget {
  const _ManagerPerformanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text('Manager Performance', style: _inter(16, weight: FontWeight.w600)),
          ),
          const Divider(color: _kSidebarBorder, height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tenants')
                .doc(AppSession.tenantId)
                .collection('users')
                .where('role', isEqualTo: 'manager')
                .snapshots(),
            builder: (ctx, snap) {
              List<_ManagerRow> rows;
              if (snap.hasData && snap.data!.docs.isNotEmpty) {
                rows = snap.data!.docs.map((d) {
                  final m = d.data() as Map<String, dynamic>;
                  final assigned = (m['assignedCampaigns'] as List?)?.length ?? 0;
                  return _ManagerRow(m['name'] as String? ?? d.id, assigned);
                }).toList();
              } else {
                rows = _kFallbackManagers;
              }
              return _ManagerTable(rows: rows, loading: snap.connectionState == ConnectionState.waiting);
            },
          ),
        ],
      ),
    );
  }
}

class _ManagerTable extends StatelessWidget {
  const _ManagerTable({required this.rows, required this.loading});
  final List<_ManagerRow> rows;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const columns = ['Manager Name','Assigned Campaigns','Leads Generated'];
    return Stack(children: [
      LayoutBuilder(builder: (ctx, con) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: con.maxWidth),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 24,
            headingTextStyle: _inter(12, weight: FontWeight.w600, color: _kTextLight),
            dataTextStyle: _inter(13),
            columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
            rows: rows.map((m) => DataRow(cells: [
              DataCell(Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _kBlue.withOpacity(0.12),
                  child: Text(m.name.isNotEmpty ? m.name[0] : '?',
                      style: _inter(12, weight: FontWeight.w600, color: _kBlue)),
                ),
                const SizedBox(width: 10),
                Text(m.name, style: _inter(13, weight: FontWeight.w500)),
              ])),
              DataCell(Text('${m.campaigns}')),
              DataCell(Text('0')), // future aggregation
            ])).toList(),
          ),
        ),
      )),
      if (loading)
        const Positioned(top: 8, right: 12,
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
    ]);
  }
}

// ─────────────────────────────────────────────
//  Health Alerts — hardcoded (future feature)
// ─────────────────────────────────────────────
class _HealthAlertsCard extends StatelessWidget {
  const _HealthAlertsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active_outlined, size: 18, color: _kText),
            const SizedBox(width: 8),
            Text('Alerts', style: _inter(16, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          const Divider(color: _kSidebarBorder),
          ..._kAlerts.map((a) => AlertRow(message: a.message, timeAgo: a.timestamp)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Immutable data holders
// ─────────────────────────────────────────────
class _CampaignRow {
  const _CampaignRow(this.name, this.isActive, this.rawPending, this.warmPending);
  final String name;
  final bool   isActive;
  final String rawPending;
  final String warmPending;
}

class _ManagerRow {
  const _ManagerRow(this.name, this.campaigns);
  final String name;
  final int    campaigns;
}

class _AlertData {
  const _AlertData(this.message, this.timestamp);
  final String message;
  final String timestamp;
}
