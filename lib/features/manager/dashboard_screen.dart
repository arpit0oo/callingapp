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
const _kPurple = Color(0xFF9334E9);
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
  _KpiData('Active Callers', '12', Icons.headset_mic, _kBlue),
  _KpiData('Raw Queue Pending', '8,450', Icons.queue, _kOrange),
  _KpiData('Warm Queue Pending', '340', Icons.phone_callback, _kPurple),
  _KpiData('Leads Generated Today', '87', Icons.trending_up, _kGreen),
];

const _kCallers = [
  _CallerRow('Ravi Kumar',   'Calling', '+91 98765 43210', '45', '8'),
  _CallerRow('Priya Patel',  'Idle',    '—',               '32', '5'),
  _CallerRow('Suresh Yadav', 'Calling', '+91 87654 32109', '67', '12'),
  _CallerRow('Anjali Singh', 'Break',   '—',               '28', '4'),
  _CallerRow('Mohit Sharma', 'Calling', '+91 76543 21098', '51', '9'),
];

const _kQueues = [
  _QueueRow('Xpert Tutor',    12500, 340),
  _QueueRow('Solar Campaign',  5600, 110),
  _QueueRow('DSA Campaign',   18200, 870),
];

const _kAlerts = [
  _AlertData('DSA Campaign — Raw Queue Exhausting Soon', '15 min ago'),
  _AlertData('Suresh Yadav — Unusually high call duration detected', '42 min ago'),
];

// ─────────────────────────────────────────────
//  Public entry point
// ─────────────────────────────────────────────
class ManagerDashboardContent extends StatelessWidget {
  const ManagerDashboardContent({super.key});

  @override
  Widget build(BuildContext context) => _MainContent();
}

// ─────────────────────────────────────────────
//  Main Content
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

          // ── Section 2: Two-column row ─────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left 65% — Live Caller Activity
              Expanded(flex: 65, child: _LiveCallerCard()),
              const SizedBox(width: 20),
              // Right 35% — Queue Health + Alerts
              Expanded(flex: 35, child: _QueueHealthCard()),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  KPI Strip
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
//  Live Caller Activity Card
// ─────────────────────────────────────────────
class _LiveCallerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const columns = [
      'Caller',
      'Status',
      'Current Lead',
      'Calls Today',
      'Leads Today',
    ];

    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Text('Live Callers', style: _inter(16, weight: FontWeight.w600)),
                const SizedBox(width: 10),
                // Pulsing green dot indicator
                _PulsingDot(),
              ],
            ),
          ),
          const Divider(color: _kSidebarBorder, height: 1),
          // Data table
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
                    headingTextStyle:
                        _inter(12, weight: FontWeight.w600, color: _kTextLight),
                    dataTextStyle: _inter(13),
                    columns:
                        columns.map((c) => DataColumn(label: Text(c))).toList(),
                    rows: _kCallers.map((row) {
                      final statusColor = _statusColor(row.status);
                      return DataRow(cells: [
                        // Caller name with avatar
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _kBlue.withOpacity(0.12),
                              child: Text(
                                row.name[0],
                                style: _inter(12,
                                    weight: FontWeight.w600, color: _kBlue),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(row.name,
                                style: _inter(13, weight: FontWeight.w500)),
                          ],
                        )),
                        // Status badge
                        DataCell(StatusBadge(
                          label: row.status,
                          color: statusColor,
                        )),
                        // Current lead
                        DataCell(Text(
                          row.currentLead,
                          style: _inter(13,
                              color: row.currentLead == '—'
                                  ? _kGrey
                                  : _kText),
                        )),
                        DataCell(Text(row.callsToday)),
                        DataCell(Text(
                          row.leadsToday,
                          style: _inter(13,
                              weight: FontWeight.w600, color: _kGreen),
                        )),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Calling':
        return _kGreen;
      case 'Break':
        return _kOrange;
      default: // Idle
        return _kGrey;
    }
  }
}

// ─────────────────────────────────────────────
//  Pulsing green dot (live indicator)
// ─────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Queue Health Card (right column)
// ─────────────────────────────────────────────
class _QueueHealthCard extends StatelessWidget {
  // Max raw value across all campaigns, for normalising the progress bars.
  static const _kMaxRaw = 20000.0;
  static const _kMaxWarm = 1000.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Queue health section
        Container(
          decoration: _card(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Queue Health', style: _inter(16, weight: FontWeight.w600)),
              const SizedBox(height: 16),
              ..._kQueues.map((q) => _QueueBar(
                    name: q.campaign,
                    raw: q.raw,
                    warm: q.warm,
                    maxRaw: _kMaxRaw,
                    maxWarm: _kMaxWarm,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Alerts section
        Container(
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
              ..._kAlerts.map(
                (a) => AlertRow(message: a.message, timeAgo: a.timestamp),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Single campaign queue bar row
// ─────────────────────────────────────────────
class _QueueBar extends StatelessWidget {
  const _QueueBar({
    required this.name,
    required this.raw,
    required this.warm,
    required this.maxRaw,
    required this.maxWarm,
  });

  final String name;
  final int raw;
  final int warm;
  final double maxRaw;
  final double maxWarm;

  String _fmt(int n) {
    if (n >= 1000) {
      final k = (n / 1000).toStringAsFixed(1);
      return '${k}k';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: _inter(13, weight: FontWeight.w600, color: _kText)),
          const SizedBox(height: 6),
          // Raw bar (blue)
          _MiniBar(
            label: 'Raw',
            value: raw,
            maxValue: maxRaw,
            color: _kBlue,
            formatted: _fmt(raw),
          ),
          const SizedBox(height: 4),
          // Warm bar (green)
          _MiniBar(
            label: 'Warm',
            value: warm,
            maxValue: maxWarm,
            color: _kGreen,
            formatted: _fmt(warm),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.formatted,
  });

  final String label;
  final int value;
  final double maxValue;
  final Color color;
  final String formatted;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label,
              style: _inter(10, color: _kGrey)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            formatted,
            style: _inter(11, weight: FontWeight.w600, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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

class _CallerRow {
  const _CallerRow(
      this.name, this.status, this.currentLead, this.callsToday, this.leadsToday);
  final String name;
  final String status;
  final String currentLead;
  final String callsToday;
  final String leadsToday;
}

class _QueueRow {
  const _QueueRow(this.campaign, this.raw, this.warm);
  final String campaign;
  final int raw;
  final int warm;
}

class _AlertData {
  const _AlertData(this.message, this.timestamp);
  final String message;
  final String timestamp;
}
