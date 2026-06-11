// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/campaign_service.dart';
import '../../services/lead_service.dart';
import '../../shared/widgets/status_badge.dart';

// ── colours ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF1A73E8);
const _kGreen  = Color(0xFF34A853);
const _kRed    = Color(0xFFEA4335);
const _kOrange = Color(0xFFFA7B17);
const _kGrey   = Color(0xFF80868B);
const _kText   = Color(0xFF202124);
const _kTextL  = Color(0xFF5F6368);
const _kBorder = Color(0xFFE8EAED);
const _kBg     = Color(0xFFF8F9FA);
const _kShadow = Color(0x14000000);

TextStyle _t(double s, {FontWeight w = FontWeight.w400, Color c = _kText}) =>
    GoogleFonts.inter(fontSize: s, fontWeight: w, color: c);

BoxDecoration _card({double r = 12}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r),
      boxShadow: const [BoxShadow(color: _kShadow, blurRadius: 8, offset: Offset(0, 2))],
    );

// ── number cleaning ───────────────────────────────────────────────────────────
String _clean(String raw) {
  String s = raw.replaceAll(RegExp(r'(?:ext|x)\S*', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\D'), '');
  if (s.length == 12 && s.startsWith('91')) s = s.substring(2);
  else if (s.length == 11 && s.startsWith('0')) s = s.substring(1);
  else if (s.length >= 13 && s.startsWith('091')) s = s.substring(3);
  return s;
}

bool _valid(String s) => RegExp(r'^[6-9]\d{9}$').hasMatch(s);

// ── main widget ───────────────────────────────────────────────────────────────
class CsvUploadContent extends StatefulWidget {
  const CsvUploadContent({super.key});
  @override
  State<CsvUploadContent> createState() => _State();
}

class _State extends State<CsvUploadContent> {
  // input mode
  int _mode = 0; // 0=csv 1=paste

  // csv mode
  String _fileName = '';
  List<String> _rawLines = [];

  // paste mode
  final _pasteCtrl = TextEditingController();

  // campaign
  String? _campaignId;
  String? _campaignName;

  // processed
  List<String> _validNums = [];
  int _invalidCount = 0;
  int _dupCount = 0;
  int _dncCount = 0;
  bool _processed = false;
  bool _processing = false;

  // upload
  String _uploadState = 'idle'; // idle | loading | success

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  // ── pick CSV via dart:html ────────────────────────────────────────────────
  void _pickFile() {
    final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
    input.click();
    input.onChange.listen((e) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoad.listen((_) {
        final content = reader.result as String;
        final lines = content.split(RegExp(r'\r?\n'));
        setState(() {
          _fileName = file.name;
          _rawLines = lines;
          _processed = false;
          _validNums = [];
        });
        _process(lines);
      });
    });
  }

  // ── process numbers ───────────────────────────────────────────────────────
  Future<void> _process(List<String> rawLines) async {
    setState(() => _processing = true);

    // collect raw values: CSV = col A skip header; paste = split by comma/newline
    List<String> rawValues;
    if (_mode == 0) {
      rawValues = rawLines.skip(1).map((l) => l.split(',').first.trim()).where((v) => v.isNotEmpty).toList();
    } else {
      rawValues = _pasteCtrl.text.split(RegExp(r'[,\n\r]+')).map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
    }

    // clean + categorise
    final seen = <String>{};
    final dups = <String>{};
    final cleaned = <String>[];

    for (final raw in rawValues) {
      final c = _clean(raw);
      if (!_valid(c)) continue;
      if (seen.contains(c)) { dups.add(c); } else { seen.add(c); cleaned.add(c); }
    }

    final invalid = rawValues.length - seen.length - dups.length;

    // DNC check
    int dncCount = 0;
    final validAfterDnc = <String>[];
    final db = FirebaseFirestore.instance;
    final tid = AppSession.tenantId;

    for (final num in cleaned) {
      final doc = await db.collection('tenants').doc(tid).collection('suppression_list').doc(num).get();
      if (doc.exists) { dncCount++; } else { validAfterDnc.add(num); }
    }

    if (mounted) {
      setState(() {
        _validNums   = validAfterDnc;
        _invalidCount = invalid < 0 ? 0 : invalid;
        _dupCount     = dups.length;
        _dncCount     = dncCount;
        _processed    = true;
        _processing   = false;
      });
    }
  }

  // ── upload ────────────────────────────────────────────────────────────────
  Future<void> _upload() async {
    if (_validNums.isEmpty || _campaignId == null) return;
    setState(() => _uploadState = 'loading');

    final db  = FirebaseFirestore.instance;
    final tid = AppSession.tenantId;
    final uid = AppSession.userId;

    try {
      // Insert all valid numbers into the raw_numbers bucket via LeadService.
      await LeadService.batchInsertLeads(tid, _campaignId!, _validNums);

      // Update campaign stats (creates the doc if it doesn't exist yet).
      await db
          .collection('tenants')
          .doc(tid)
          .collection('campaigns')
          .doc(_campaignId)
          .collection('stats')
          .doc('summary')
          .set({
            'totalUploaded':  FieldValue.increment(_validNums.length),
            'queueRemaining': FieldValue.increment(_validNums.length),
          }, SetOptions(merge: true));

      // activity log
      final src = _mode == 0 ? _fileName : 'paste';
      await db.collection('tenants').doc(tid).collection('activity_logs').add({
        'action':    'csv_upload',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'fileName':   src,
          'totalRows':  (_validNums.length + _invalidCount + _dupCount + _dncCount),
          'validCount': _validNums.length,
          'campaignId': _campaignId,
          'campaignName': _campaignName,
          'uploadedBy': uid,
          'status':     'Completed',
        },
      });

      if (mounted) setState(() => _uploadState = 'success');
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() { _uploadState = 'idle'; _processed = false; _fileName = ''; _pasteCtrl.clear(); _validNums = []; });
    } catch (_) {
      if (mounted) setState(() => _uploadState = 'idle');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CSV Upload', style: _t(20, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Upload lead databases to your campaigns', style: _t(14, c: _kTextL)),
            const SizedBox(height: 28),
            _buildInputCard(),
            const SizedBox(height: 24),
            if (_processed || _processing) _buildValidationCard(),
            const SizedBox(height: 28),
            _buildHistorySection(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── input card ────────────────────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // mode toggle
          Container(
            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
            child: Row(children: [
              _modeTab(0, Icons.upload_file_outlined, 'CSV File'),
              _modeTab(1, Icons.content_paste_outlined, 'Paste Numbers'),
            ]),
          ),
          const SizedBox(height: 20),

          if (_mode == 0) _buildDropZone() else _buildPasteArea(),
          const SizedBox(height: 14),

          Row(children: [
            const Icon(Icons.info_outline, size: 13, color: _kGrey),
            const SizedBox(width: 5),
            Text(_mode == 0 ? 'Reads Column A only — header row skipped — Max 10 MB' : 'Paste comma or newline separated numbers', style: _t(12, c: _kGrey)),
          ]),
          const SizedBox(height: 20),

          // campaign dropdown
          Text('Upload to Campaign', style: _t(13, w: FontWeight.w600, c: _kTextL)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: CampaignService.getCampaigns(AppSession.tenantId),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (_campaignId != null && docs.isNotEmpty) {
                final ids = docs.map((d) => d.id).toList();
                if (!ids.contains(_campaignId)) _campaignId = null;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kBorder)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _campaignId,
                    isExpanded: true,
                    style: _t(13),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kTextL),
                    hint: Text('Select Campaign', style: _t(13, c: _kGrey)),
                    onChanged: (v) {
                      if (v == null) return;
                      final doc = docs.firstWhere((d) => d.id == v);
                      final data = doc.data() as Map<String, dynamic>;
                      setState(() { _campaignId = v; _campaignName = data['name'] ?? v; });
                    },
                    items: docs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return DropdownMenuItem(value: d.id, child: Text(data['name'] ?? d.id, style: _t(13)));
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

  Widget _modeTab(int idx, IconData icon, String label) {
    final sel = _mode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _mode = idx; _processed = false; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: sel ? Colors.white : _kTextL),
            const SizedBox(width: 6),
            Text(label, style: _t(13, w: FontWeight.w500, c: sel ? Colors.white : _kTextL)),
          ]),
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    final hasFile = _fileName.isNotEmpty;
    return GestureDetector(
      onTap: _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasFile ? _kGreen.withOpacity(0.04) : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasFile ? _kGreen : _kBlue.withOpacity(0.35), width: 2),
        ),
        child: hasFile
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.description_outlined, size: 40, color: _kGreen),
                const SizedBox(height: 10),
                Text(_fileName, style: _t(14, w: FontWeight.w600, c: _kGreen)),
                const SizedBox(height: 4),
                Text('${_rawLines.length - 1} rows detected', style: _t(12, c: _kGrey)),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _pickFile, style: OutlinedButton.styleFrom(foregroundColor: _kGrey, side: const BorderSide(color: _kBorder)), child: Text('Change File', style: _t(12, c: _kGrey))),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.cloud_upload_outlined, size: 56, color: _kBlue.withOpacity(0.55)),
                const SizedBox(height: 12),
                Text('Drag & drop or click to browse', style: _t(15, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('CSV files only', style: _t(13, c: _kGrey)),
              ]),
      ),
    );
  }

  Widget _buildPasteArea() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
        child: TextField(
          controller: _pasteCtrl,
          maxLines: 6,
          style: _t(13),
          decoration: InputDecoration(
            hintText: '9876543210, 8765432109\n7654321098\n...',
            hintStyle: _t(13, c: _kGrey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () {
            if (_pasteCtrl.text.trim().isEmpty) return;
            setState(() { _processed = false; _rawLines = []; _fileName = ''; });
            _process([]);
          },
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: Text('Validate Numbers', style: _t(13, w: FontWeight.w500, c: Colors.white)),
        ),
      ),
    ]);
  }

  // ── validation card ───────────────────────────────────────────────────────
  Widget _buildValidationCard() {
    if (_processing) {
      return Container(
        decoration: _card(),
        padding: const EdgeInsets.all(32),
        child: const Center(child: Column(children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Checking suppression list…'),
        ])),
      );
    }

    final total = _validNums.length + _invalidCount + _dupCount + _dncCount;
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // file row
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.description_outlined, size: 22, color: _kGreen)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_mode == 0 ? _fileName : 'Pasted Input', style: _t(14, w: FontWeight.w600)),
            Text('$total numbers processed', style: _t(12, c: _kGrey)),
          ])),
          const Icon(Icons.check_circle_rounded, size: 20, color: _kGreen),
        ]),
        const SizedBox(height: 20),

        // stat chips
        Row(children: [
          _chip(Icons.check_circle_outline, 'Valid',     '${_validNums.length}', _kGreen),
          const SizedBox(width: 10),
          _chip(Icons.cancel_outlined,      'Invalid',   '$_invalidCount',       _kRed),
          const SizedBox(width: 10),
          _chip(Icons.content_copy_outlined, 'Duplicate', '$_dupCount',          _kOrange),
          const SizedBox(width: 10),
          _chip(Icons.block_outlined,       'DNC',       '$_dncCount',           _kGrey),
        ]),
        const SizedBox(height: 20),

        // upload button
        _buildUploadButton(),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: _t(15, w: FontWeight.w700, c: color)),
          Text(label, style: _t(11, c: color.withOpacity(0.8))),
        ]),
      ]),
    ),
  );

  Widget _buildUploadButton() {
    final enabled = _validNums.isNotEmpty && _campaignId != null;
    final isLoading = _uploadState == 'loading';
    final isSuccess = _uploadState == 'success';
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: isSuccess ? _kGreen : (enabled ? _kBlue : _kGrey.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: (enabled && !isLoading && !isSuccess) ? _upload : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? const SizedBox(key: ValueKey('l'), width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
              : isSuccess
                  ? Row(key: const ValueKey('s'), mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text('Upload Successful!', style: _t(14, w: FontWeight.w600, c: Colors.white)),
                    ])
                  : Row(key: const ValueKey('i'), mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.upload_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(enabled ? 'Upload ${_validNums.length} Valid Leads' : 'Select a campaign to upload', style: _t(14, w: FontWeight.w600, c: Colors.white)),
                    ]),
        ),
      ),
    );
  }

  // ── recent uploads ─────────────────────────────────────────────────────────
  Widget _buildHistorySection() {
    final db  = FirebaseFirestore.instance;
    final tid = AppSession.tenantId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.history_outlined, size: 18, color: _kTextL),
        const SizedBox(width: 8),
        Text('Recent Uploads', style: _t(16, w: FontWeight.w600)),
      ]),
      const SizedBox(height: 14),
      StreamBuilder<QuerySnapshot>(
        stream: db.collection('tenants').doc(tid).collection('activity_logs')
            .where('action', isEqualTo: 'csv_upload')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Container(
              decoration: _card(),
              padding: const EdgeInsets.all(40),
              child: Center(child: Text('No uploads yet', style: _t(14, c: _kGrey))),
            );
          }
          return Container(
            decoration: _card(),
            child: LayoutBuilder(builder: (ctx, con) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: con.maxWidth),
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 56,
                  columnSpacing: 20,
                  headingTextStyle: _t(12, w: FontWeight.w600, c: _kTextL),
                  dataTextStyle: _t(13),
                  columns: const [
                    DataColumn(label: Text('File Name')),
                    DataColumn(label: Text('Campaign')),
                    DataColumn(label: Text('Total Rows')),
                    DataColumn(label: Text('Valid')),
                    DataColumn(label: Text('Uploaded By')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: docs.map((doc) {
                    final m = (doc.data() as Map<String, dynamic>)['metadata'] as Map<String, dynamic>? ?? {};
                    final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                    final date = ts != null
                        ? '${ts.toDate().day} ${_month(ts.toDate().month)} ${ts.toDate().year}'
                        : '—';
                    final status = m['status'] as String? ?? 'Completed';
                    Color sc;
                    switch (status) {
                      case 'Completed': sc = _kGreen; break;
                      case 'Processing': sc = _kOrange; break;
                      default: sc = _kRed;
                    }
                    final uploader = (m['uploadedBy'] as String? ?? '—');
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        const Icon(Icons.description_outlined, size: 16, color: _kGrey),
                        const SizedBox(width: 6),
                        Text(m['fileName'] as String? ?? '—', style: _t(13, w: FontWeight.w500)),
                      ])),
                      DataCell(Text(m['campaignName'] as String? ?? '—')),
                      DataCell(Text('${m['totalRows'] ?? '—'}')),
                      DataCell(Text('${m['validCount'] ?? '—'}')),
                      DataCell(Row(children: [
                        CircleAvatar(radius: 12, backgroundColor: _kBlue.withOpacity(0.12),
                            child: Text(uploader.isNotEmpty ? uploader[0].toUpperCase() : '?', style: _t(10, w: FontWeight.w600, c: _kBlue))),
                        const SizedBox(width: 6),
                        Text(uploader),
                      ])),
                      DataCell(Text(date, style: _t(13, c: _kTextL))),
                      DataCell(StatusBadge(label: status, color: sc)),
                    ]);
                  }).toList(),
                ),
              ),
            )),
          );
        },
      ),
    ]);
  }

  String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}
