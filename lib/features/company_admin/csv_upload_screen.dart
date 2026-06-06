import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/status_badge.dart';

// ─────────────────────────────────────────────
//  Colour constants
// ─────────────────────────────────────────────
const _kBlue = Color(0xFF1A73E8);
const _kGreen = Color(0xFF34A853);
const _kRed = Color(0xFFEA4335);
const _kOrange = Color(0xFFFA7B17);
const _kGrey = Color(0xFF80868B);
const _kText = Color(0xFF202124);
const _kTextLight = Color(0xFF5F6368);
const _kBorder = Color(0xFFE8EAED);
const _kCardShadow = Color(0x14000000);
const _kBgPage = Color(0xFFF8F9FA);

TextStyle _inter(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _kText,
}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

BoxDecoration _card({double radius = 12}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: _kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
      ],
    );

// ─────────────────────────────────────────────
//  Dummy data
// ─────────────────────────────────────────────
const _kCampaigns = [
  'Xpert Tutor',
  'Solar Campaign',
  'DSA Campaign',
];

const _kPreviewRows = [
  ['1', 'Arjun Sharma', '+91 98001 12345', 'Mumbai'],
  ['2', 'Priya Mehta', '+91 99102 67890', 'Delhi'],
  ['3', 'Rahul Verma', '+91 97890 23456', 'Bengaluru'],
  ['4', 'Sneha Kapoor', '+91 96001 78901', 'Hyderabad'],
  ['5', 'Vikram Singh', '+91 95234 34567', 'Pune'],
];

class _HistoryRow {
  const _HistoryRow({
    required this.fileName,
    required this.campaign,
    required this.totalRows,
    required this.valid,
    required this.uploadedBy,
    required this.date,
    required this.status,
  });
  final String fileName;
  final String campaign;
  final String totalRows;
  final String valid;
  final String uploadedBy;
  final String date;
  final String status; // 'Completed' | 'Processing' | 'Failed'
}

const _kHistory = [
  _HistoryRow(
    fileName: 'leads_may_batch.csv',
    campaign: 'Xpert Tutor',
    totalRows: '3,200',
    valid: '3,100',
    uploadedBy: 'Admin User',
    date: 'May 28, 2025',
    status: 'Completed',
  ),
  _HistoryRow(
    fileName: 'solar_leads_q2.csv',
    campaign: 'Solar Campaign',
    totalRows: '1,800',
    valid: '1,640',
    uploadedBy: 'Admin User',
    date: 'Jun 2, 2025',
    status: 'Processing',
  ),
  _HistoryRow(
    fileName: 'dsa_june_raw.csv',
    campaign: 'DSA Campaign',
    totalRows: '950',
    valid: '0',
    uploadedBy: 'Admin User',
    date: 'Jun 5, 2025',
    status: 'Failed',
  ),
];

// ─────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────
class CsvUploadContent extends StatefulWidget {
  const CsvUploadContent({super.key});

  @override
  State<CsvUploadContent> createState() => _CsvUploadContentState();
}

class _CsvUploadContentState extends State<CsvUploadContent> {
  String _selectedCampaign = _kCampaigns.first;
  bool _previewExpanded = false;

  // Upload button state: 'idle' | 'loading' | 'success'
  String _uploadState = 'idle';

  Future<void> _handleUpload() async {
    setState(() => _uploadState = 'loading');
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _uploadState = 'success');
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _uploadState = 'idle');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBgPage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ───────────────────────────
            Text('CSV Upload',
                style: _inter(20, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Upload lead databases to your campaigns',
                style: _inter(14, color: _kTextLight)),
            const SizedBox(height: 28),

            // ── Section 1: Upload Card ─────────────
            _UploadCard(
              selectedCampaign: _selectedCampaign,
              onCampaignChanged: (v) =>
                  setState(() => _selectedCampaign = v!),
            ),
            const SizedBox(height: 24),

            // ── Section 2: Validation Preview ──────
            _ValidationSection(
              previewExpanded: _previewExpanded,
              onTogglePreview: () =>
                  setState(() => _previewExpanded = !_previewExpanded),
              uploadState: _uploadState,
              onUpload: _handleUpload,
            ),
            const SizedBox(height: 28),

            // ── Section 3: Upload History ──────────
            _UploadHistorySection(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Section 1 — Upload Card
// ─────────────────────────────────────────────
class _UploadCard extends StatefulWidget {
  const _UploadCard({
    required this.selectedCampaign,
    required this.onCampaignChanged,
  });

  final String selectedCampaign;
  final ValueChanged<String?> onCampaignChanged;

  @override
  State<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<_UploadCard> {
  bool _dropHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dashed drop zone ──────────────────
          MouseRegion(
            onEnter: (_) => setState(() => _dropHovered = true),
            onExit: (_) => setState(() => _dropHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _dropHovered
                    ? _kBlue.withOpacity(0.04)
                    : const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dropHovered
                      ? _kBlue
                      : _kBlue.withOpacity(0.35),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 64,
                      color: _dropHovered ? _kBlue : _kBlue.withOpacity(0.55)),
                  const SizedBox(height: 12),
                  Text(
                    'Drag & drop your CSV file here',
                    style: _inter(16,
                        weight: FontWeight.w600,
                        color: _dropHovered ? _kBlue : _kText),
                  ),
                  const SizedBox(height: 6),
                  Text('or', style: _inter(14, color: _kGrey)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kBlue,
                      side: const BorderSide(color: _kBlue),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {}, // UI-only
                    child: Text('Browse File',
                        style: _inter(13,
                            weight: FontWeight.w500, color: _kBlue)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Hint text ─────────────────────────
          Row(
            children: [
              const Icon(Icons.info_outline, size: 13, color: _kGrey),
              const SizedBox(width: 5),
              Text(
                'Supported format: CSV only — Max file size: 10MB',
                style: _inter(12, color: _kGrey),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Campaign selector ─────────────────
          Text('Upload to Campaign',
              style: _inter(13, weight: FontWeight.w600, color: _kTextLight)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _kBgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: widget.selectedCampaign,
                isExpanded: true,
                style: _inter(13),
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: _kTextLight),
                hint: Text('Select Campaign to upload to',
                    style: _inter(13, color: _kGrey)),
                onChanged: widget.onCampaignChanged,
                items: _kCampaigns
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: _inter(13)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Section 2 — Validation Preview
// ─────────────────────────────────────────────
class _ValidationSection extends StatelessWidget {
  const _ValidationSection({
    required this.previewExpanded,
    required this.onTogglePreview,
    required this.uploadState,
    required this.onUpload,
  });

  final bool previewExpanded;
  final VoidCallback onTogglePreview;
  final String uploadState;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── File selected row ─────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_outlined,
                    size: 22, color: _kGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('leads_database_june.csv',
                        style: _inter(14, weight: FontWeight.w600)),
                    Text('2,450 rows detected',
                        style: _inter(12, color: _kGrey)),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: _kGreen),
            ],
          ),
          const SizedBox(height: 20),

          // ── Validation stat chips ─────────────
          Row(
            children: [
              _StatChip(
                icon: Icons.check_circle_outline,
                label: 'Valid',
                value: '2,380',
                color: _kGreen,
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.cancel_outlined,
                label: 'Invalid',
                value: '45',
                color: _kRed,
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.content_copy_outlined,
                label: 'Duplicate',
                value: '18',
                color: _kOrange,
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.block_outlined,
                label: 'DNC',
                value: '7',
                color: _kGrey,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Preview Data expandable ───────────
          GestureDetector(
            onTap: onTogglePreview,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kBgPage,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart_outlined,
                      size: 16, color: _kTextLight),
                  const SizedBox(width: 8),
                  Text('Preview Data (first 5 rows)',
                      style: _inter(13,
                          weight: FontWeight.w500, color: _kTextLight)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: previewExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: _kTextLight),
                  ),
                ],
              ),
            ),
          ),

          // Preview table (animated)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _PreviewTable(),
            crossFadeState: previewExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 20),

          // ── Upload button ─────────────────────
          _UploadButton(state: uploadState, onTap: onUpload),
        ],
      ),
    );
  }
}

// Stat chip
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: _inter(15,
                        weight: FontWeight.w700, color: color)),
                Text(label,
                    style: _inter(11, color: color.withOpacity(0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Preview table
class _PreviewTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headers = ['#', 'Name', 'Phone', 'City'];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Table(
          border: TableBorder.symmetric(
            inside: const BorderSide(color: _kBorder),
          ),
          columnWidths: const {
            0: FixedColumnWidth(48),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(2.5),
            3: FlexColumnWidth(2),
          },
          children: [
            // Header row
            TableRow(
              decoration: const BoxDecoration(color: _kBgPage),
              children: headers
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(h,
                            style: _inter(12,
                                weight: FontWeight.w600,
                                color: _kTextLight)),
                      ))
                  .toList(),
            ),
            // Data rows
            ..._kPreviewRows.map((row) => TableRow(
                  children: row
                      .map((cell) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Text(cell, style: _inter(13)),
                          ))
                      .toList(),
                )),
          ],
        ),
      ),
    );
  }
}

// Upload button with state
class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.state, required this.onTap});
  final String state; // 'idle' | 'loading' | 'success'
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSuccess = state == 'success';
    final isLoading = state == 'loading';

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isSuccess ? _kGreen : _kBlue,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: isLoading ? null : onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.2),
                )
              : isSuccess
                  ? Row(
                      key: const ValueKey('success'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Upload Successful!',
                            style: _inter(14,
                                weight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    )
                  : Row(
                      key: const ValueKey('idle'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_rounded,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Upload 2,380 Valid Leads',
                            style: _inter(14,
                                weight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Section 3 — Upload History
// ─────────────────────────────────────────────
class _UploadHistorySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_outlined,
                size: 18, color: _kTextLight),
            const SizedBox(width: 8),
            Text('Recent Uploads',
                style: _inter(16, weight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: _card(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 56,
                    columnSpacing: 20,
                    headingTextStyle: _inter(12,
                        weight: FontWeight.w600, color: _kTextLight),
                    dataTextStyle: _inter(13),
                    columns: const [
                      DataColumn(label: Text('File Name')),
                      DataColumn(label: Text('Campaign')),
                      DataColumn(label: Text('Total Rows')),
                      DataColumn(label: Text('Valid')),
                      DataColumn(label: Text('Uploaded By')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: _kHistory.map((row) {
                      Color statusColor;
                      switch (row.status) {
                        case 'Completed':
                          statusColor = _kGreen;
                        case 'Processing':
                          statusColor = _kOrange;
                        default:
                          statusColor = _kRed;
                      }
                      return DataRow(cells: [
                        DataCell(Row(children: [
                          const Icon(Icons.description_outlined,
                              size: 16, color: _kGrey),
                          const SizedBox(width: 6),
                          Text(row.fileName,
                              style: _inter(13,
                                  weight: FontWeight.w500)),
                        ])),
                        DataCell(Text(row.campaign)),
                        DataCell(Text(row.totalRows)),
                        DataCell(Text(row.valid)),
                        DataCell(Row(children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: _kBlue.withOpacity(0.12),
                            child: Text('A',
                                style: _inter(10,
                                    weight: FontWeight.w600,
                                    color: _kBlue)),
                          ),
                          const SizedBox(width: 6),
                          Text(row.uploadedBy),
                        ])),
                        DataCell(Text(row.date,
                            style: _inter(13, color: _kTextLight))),
                        DataCell(StatusBadge(
                          label: row.status,
                          color: statusColor,
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
