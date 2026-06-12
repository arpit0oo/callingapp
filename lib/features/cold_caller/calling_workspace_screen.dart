import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/lead_service.dart';
import '../../services/rtdb_service.dart';
import 'calling_dashboard_screen.dart';
import 'caller_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point (used by CallerShell index 1)
// ─────────────────────────────────────────────────────────────────────────────

class CallingWorkspaceContent extends StatefulWidget {
  const CallingWorkspaceContent({
    super.key,
    required this.role,
    this.currentLead,
  });

  /// "cold" = raw leads, "warm" = callbacks.
  final String role;

  /// The lead map returned by LeadService.getNextLead(). Nullable — shown
  /// as an empty state when null.
  final Map<String, dynamic>? currentLead;

  static final GlobalKey<_CallingWorkspaceContentState> workspaceKey =
      GlobalKey<_CallingWorkspaceContentState>();

  @override
  State<CallingWorkspaceContent> createState() =>
      _CallingWorkspaceContentState();
}

class _CallingWorkspaceContentState extends State<CallingWorkspaceContent> {
  // ── Colors ────────────────────────────────────────────────────
  static const _primary = Color(0xFF1A73E8);
  static const _textPrimary = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _textHint = Color(0xFF9AA0A6);
  static const _border = Color(0xFFE8EAED);
  static const _bg = Color(0xFFF8F9FA);

  // ── Timer ─────────────────────────────────────────────────────
  int _seconds = 0;
  Timer? _timer;

  // ── Dynamic form state ────────────────────────────────────────
  /// Values for all campaign form fields, keyed by Firestore document ID.
  final Map<String, dynamic> _formData = {};
  /// TextEditingControllers for text/number fields, keyed by document ID.
  final Map<String, TextEditingController> _formControllers = {};
  /// IDs of fields where required == true (populated from Firestore schema).
  final Set<String> _requiredFields = {};
  /// IDs of required fields that were empty on the last failed submit attempt.
  final Set<String> _invalidFieldIds = {};
  /// Fetched once in initState — avoids refetching on every timer rebuild.
  Future<QuerySnapshot>? _schemaFuture;
  /// Disposition chips loaded from Firestore disposition_config sub-collection.
  Future<QuerySnapshot>? _dispositionFuture;

  // ── Notes ─────────────────────────────────────────────────────
  final _notesCtrl = TextEditingController();

  // ── Disposition state ─────────────────────────────────────────
  String? _selectedDisposition;
  /// Behavior type value read from disposition_config ('close', 'retry', etc.).
  String _selectedDispositionType = 'close';
  /// True when the selected disposition's requiresNote == true.
  bool _selectedDispositionRequiresNote = false;
  /// True when the selected disposition's requiresCallback == true.
  bool _selectedDispositionRequiresCallback = false;
  String? _cbDate;
  String? _cbTime;
  bool _showSuccess = false;
  /// Drives a red border on the notes card after a failed submit.
  bool _notesError = false;

  final _callbackDates = ['Today', 'Tomorrow', 'In 2 days', 'In 3 days'];
  final _callbackTimes = ['09:00 AM', '11:00 AM', '02:00 PM', '04:00 PM', '06:00 PM'];

  /// Parses a hex color string (e.g. "#1A73E8" or "1A73E8") into a [Color].
  /// Returns [_primary] if the string is absent or malformed.
  static Color _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF1A73E8);
    final clean = hex.startsWith('#') ? hex.substring(1) : hex;
    final padded = clean.length == 6 ? 'FF$clean' : clean;
    final value = int.tryParse(padded, radix: 16);
    return value != null ? Color(value) : const Color(0xFF1A73E8);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
    // Record call start time in RTDB.
    RtdbService.updateCallerState(AppSession.tenantId, AppSession.userId, {
      'callStarted': DateTime.now().millisecondsSinceEpoch,
    });
    // Load form schema once; FutureBuilder below caches the result.
    if (AppSession.campaignId.isNotEmpty) {
      final campaignRef = FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('campaigns')
          .doc(AppSession.campaignId);

      _schemaFuture = campaignRef
          .collection('form_schema')
          .orderBy('order')
          .get();

      _dispositionFuture = campaignRef
          .collection('disposition_config')
          .orderBy('order')
          .get();
    }
  }

  void resetTimer() {
    setState(() {
      _seconds = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesCtrl.dispose();
    for (final c in _formControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _timerLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSubmit => _selectedDisposition != null;

  // ── Helpers ───────────────────────────────────────────────────

  /// Returns the last two non-space characters of [phone] as upper-case
  /// initials for the avatar (e.g. "43210" → "10").
  String _avatarInitials(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    if (digits.isNotEmpty) return digits;
    return '?';
  }

  /// Converts an integer to an ordinal string: 1→"1st", 2→"2nd", etc.
  String _ordinal(int n) {
    if (n <= 0) return '1st';
    final suffix = (n % 100 >= 11 && n % 100 <= 13)
        ? 'th'
        : ['th', 'st', 'nd', 'rd', 'th'][n % 10 > 3 ? 0 : n % 10];
    return '$n$suffix';
  }

  void _resetForm() {
    for (final c in _formControllers.values) {
      c.clear();
    }
    setState(() {
      _formData.clear();
      _invalidFieldIds.clear();
      _notesCtrl.clear();
      _selectedDisposition = null;
      _selectedDispositionType = 'close';
      _selectedDispositionRequiresNote = false;
      _selectedDispositionRequiresCallback = false;
      _notesError = false;
      _cbDate = null;
      _cbTime = null;
      _seconds = 0;
    });
  }

  /// Converts _cbDate (e.g. 'Today', 'Tomorrow') and _cbTime (e.g. '09:00 AM')
  /// into a Firestore [Timestamp]. Falls back to now + 1 hour when either is absent.
  Timestamp _buildScheduledAtTimestamp() {
    if (_cbDate == null || _cbTime == null) {
      return Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1)));
    }
    try {
      final now = DateTime.now();
      final daysOffset = {
        'Today': 0,
        'Tomorrow': 1,
        'In 2 days': 2,
        'In 3 days': 3,
      }[_cbDate] ?? 0;
      final baseDate = DateTime(now.year, now.month, now.day + daysOffset);

      // Parse time string like '09:00 AM' or '14:00'
      final timeParts = _cbTime!.replaceAll(' AM', '').replaceAll(' PM', '').split(':');
      int hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      if (_cbTime!.contains('PM') && hour != 12) hour += 12;
      if (_cbTime!.contains('AM') && hour == 12) hour = 0;

      final scheduled = DateTime(
          baseDate.year, baseDate.month, baseDate.day, hour, minute);
      return Timestamp.fromDate(scheduled);
    } catch (_) {
      return Timestamp.fromDate(DateTime.now().add(const Duration(hours: 1)));
    }
  }

  Future<void> _submit() async {
    // ── Required-field validation ──────────────────────────────
    final missing = <String>{};
    for (final fieldId in _requiredFields) {
      final value = _formData[fieldId];
      final isEmpty = value == null ||
          (value is String && value.trim().isEmpty);
      if (isEmpty) missing.add(fieldId);
    }

    if (missing.isNotEmpty) {
      setState(() => _invalidFieldIds
        ..clear()
        ..addAll(missing));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields'),
            backgroundColor: Color(0xFFD93025),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // abort — button stays enabled
    }

    // ── Notes validation ───────────────────────────────────────
    if (_selectedDispositionRequiresNote &&
        _notesCtrl.text.trim().isEmpty) {
      setState(() => _notesError = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This disposition requires a note'),
            backgroundColor: Color(0xFFD93025),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Clear any previous error highlights before submitting
    if (_notesError) setState(() => _notesError = false);
    if (_invalidFieldIds.isNotEmpty) {
      setState(() => _invalidFieldIds.clear());
    }

    setState(() => _showSuccess = true);

    final phone = widget.currentLead?['phone']?.toString() ?? '';

    try {
      final leadId = widget.currentLead?['id']?.toString() ?? '';
      if (leadId.isNotEmpty) {
        await LeadService.submitDisposition(
          AppSession.tenantId,
          AppSession.campaignId,
          phone,
          {
            'dispositionLabel': _selectedDisposition,
            'notes': _notesCtrl.text.trim(),
            'formData': Map<String, dynamic>.from(_formData),
          },
          _selectedDispositionType,
          {
            'addedBy': AppSession.userId,
            'scheduledAt': _buildScheduledAtTimestamp(),
            'retryMinutes': 30,
          },
        );
      }
    } catch (_) {
      // swallow — UI already shows success; errors surfaced in next step
    }

    // ── Read callStarted from RTDB to calculate duration ───────
    int durationSeconds = 0;
    int callStartedMs = 0;
    try {
      final snap = await RtdbService.getCallerState(
          AppSession.tenantId, AppSession.userId);
      final rtdbData = snap.value as Map<dynamic, dynamic>?;
      callStartedMs = (rtdbData?['callStarted'] as int?) ?? 0;
      if (callStartedMs > 0) {
        final callStart =
            DateTime.fromMillisecondsSinceEpoch(callStartedMs);
        durationSeconds =
            DateTime.now().difference(callStart).inSeconds;
      }
    } catch (_) {}

    final now = DateTime.now();
    final dateKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final activityDocId = '${AppSession.userId}_$dateKey';
    final db = FirebaseFirestore.instance;
    final tid = AppSession.tenantId;
    final uid = AppSession.userId;

    // ── Write call record to caller_activity ───────────────────
    final callRecord = {
      'phone': phone,
      'callStart': callStartedMs > 0
          ? Timestamp.fromMillisecondsSinceEpoch(callStartedMs)
          : Timestamp.fromDate(DateTime.now()),
      'durationSeconds': durationSeconds,
      'disposition': _selectedDispositionType,
      'campaignId': AppSession.campaignId,
    };
    try {
      await db
          .collection('tenants')
          .doc(tid)
          .collection('caller_activity')
          .doc(activityDocId)
          .set({
            'userId': uid,
            'tenantId': tid,
            'calls': FieldValue.arrayUnion([callRecord]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}

    // ── Update caller_stats ────────────────────────────────────
    try {
      final statsUpdate = <String, dynamic>{
        'callsMade': FieldValue.increment(1),
      };
      if (_selectedDispositionType == 'convert') {
        statsUpdate['converted'] = FieldValue.increment(1);
      } else if (_selectedDispositionType == 'callback') {
        statsUpdate['callbacks'] = FieldValue.increment(1);
      } else if (_selectedDispositionType == 'dnc') {
        statsUpdate['dnc'] = FieldValue.increment(1);
      }

      // Build the recent call entry for the recentCalls array.
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final recentEntry = {
        'phone': phone,
        'disposition': _selectedDisposition ?? _selectedDispositionType,
        'time': timeStr,
      };

      // Fetch current recentCalls, prepend, keep last 10.
      final statsSnap = await db
          .collection('tenants')
          .doc(tid)
          .collection('caller_stats')
          .doc(uid)
          .get();
      final existing =
          ((statsSnap.data()?['recentCalls']) as List<dynamic>? ?? []);
      final updated = [recentEntry, ...existing].take(10).toList();
      statsUpdate['recentCalls'] = updated;

      await db
          .collection('tenants')
          .doc(tid)
          .collection('caller_stats')
          .doc(uid)
          .set(statsUpdate, SetOptions(merge: true));
    } catch (_) {}

    // ── Clear callStarted, return RTDB status to in_session ────
    try {
      await RtdbService.updateCallerState(tid, uid, {
        'callStarted': '',
        'status': 'in_session',
        'currentLeadId': '',
        'lastSeen': ServerValue.timestamp,
      });
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      setState(() => _showSuccess = false);
      _resetForm();
      // Navigate back to calling dashboard (index 1) and clear the locked lead.
      CallerShell.shellKey.currentState?.navigateTo(1);
      CallingDashboardContent.dashboardKey.currentState?.clearCurrentLead();
    }
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Disable Android back button — caller must submit before leaving.
      onWillPop: () => Future.value(false),
      child: Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLeadCard(),
                      const SizedBox(height: 12),
                      _buildFormCard(),
                      const SizedBox(height: 12),
                      _buildNotesCard(),
                      const SizedBox(height: 12),
                      _buildDispositionCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Fixed bottom bar ───────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomBar(),
          ),

          // ── Success overlay ────────────────────────────────────
          if (_showSuccess) _buildSuccessOverlay(),
        ],
      ),
      ),        // end Scaffold (closes child: Scaffold(...))
    );          // end WillPopScope
  }             // end build



  // ── Top bar ───────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 56,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // No back button — caller must submit before leaving.
          const SizedBox(width: 40),
          Expanded(
            child: Text(
              'Current Lead',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              _timerLabel,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF34A853),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lead card ─────────────────────────────────────────────────

  Widget _buildLeadCard() {
    final phone = widget.currentLead?['phone']?.toString() ?? '—';
    final attempts = (widget.currentLead?['attempts'] as int?) ?? 0;
    final attemptLabel = '${_ordinal(attempts + 1)} attempt';
    final initials = _avatarInitials(phone);
    final campaignLabel = AppSession.campaignName.isNotEmpty
        ? AppSession.campaignName
        : AppSession.campaignId.isNotEmpty
            ? AppSession.campaignId
            : 'No Campaign';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar — initials from last 2 phone digits
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A73E8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title = phone number (no contact name stored)
                    Text(phone,
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: _textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(phone,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: _textSecondary)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF34A853),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.call, size: 15,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Attempt count + campaign badge
          Row(
            children: [
              _Badge(label: attemptLabel,
                  bg: const Color(0xFFFEF3E2),
                  fg: const Color(0xFFE37400)),
              const Spacer(),
              _Badge(label: campaignLabel,
                  bg: const Color(0xFFE8F0FE),
                  fg: const Color(0xFF1A73E8)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dynamic form card (Firestore-driven) ─────────────────────

  Widget _buildFormCard() {
    // Skip rendering if no campaign is assigned
    if (AppSession.campaignId.isEmpty || _schemaFuture == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Campaign Form'),
            const SizedBox(height: 12),
            Text('No campaign assigned.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: _textHint)),
          ],
        ),
      );
    }

    // FutureBuilder: schema is fetched once in initState and never re-fetched
    // on timer-driven rebuilds, eliminating flickering.
    return FutureBuilder<QuerySnapshot>(
      future: _schemaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Campaign Form'),
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Campaign Form'),
                const SizedBox(height: 12),
                Text('No form fields configured for this campaign.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _textHint)),
              ],
            ),
          );
        }

        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle('Campaign Form'),
              const SizedBox(height: 12),
              ...docs.asMap().entries.map((entry) {
                final idx = entry.key;
                final doc = entry.value;
                final id = doc.id;
                final data = doc.data() as Map<String, dynamic>;
                final label = data['label']?.toString() ?? id;
                final type = data['type']?.toString() ?? 'text';
                final isRequired = data['required'] == true;
                final rawOpts = data['options'];
                final options = rawOpts is List
                    ? rawOpts.map((e) => e.toString()).toList()
                    : <String>[];

                // Register required fields by label so _submit() can look up
                // values via _formData[label].
                if (isRequired) _requiredFields.add(label);

                final hasError = _invalidFieldIds.contains(label);
                Widget fieldWidget;

                final typeLower = type.toLowerCase();

                if (typeLower == 'text' || typeLower == 'text input') {
                  final ctrl = _formControllers.putIfAbsent(
                    id, () => TextEditingController(),
                  );
                  fieldWidget = _CompactTextField(
                    controller: ctrl,
                    hint: 'Enter $label',
                    keyboardType: TextInputType.text,
                    hasError: hasError,
                    onChanged: (v) {
                      _formData[label] = v;
                      if (hasError && v.trim().isNotEmpty) {
                        setState(() => _invalidFieldIds.remove(label));
                      }
                    },
                  );
                } else if (typeLower == 'number') {
                  final ctrl = _formControllers.putIfAbsent(
                    id, () => TextEditingController(),
                  );
                  fieldWidget = _CompactTextField(
                    controller: ctrl,
                    hint: 'Enter $label',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hasError: hasError,
                    onChanged: (v) {
                      _formData[label] = v;
                      if (hasError && v.trim().isNotEmpty) {
                        setState(() => _invalidFieldIds.remove(label));
                      }
                    },
                  );
                } else if (typeLower == 'date') {
                  final selected = _formData[label]?.toString();
                  fieldWidget = GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate == null || !mounted) return;
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(now),
                      );
                      if (!mounted) return;
                      final timeStr = pickedTime != null
                          ? '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}'
                          : '00:00';
                      final combined =
                          '${pickedDate.year.toString().padLeft(4, '0')}-'
                          '${pickedDate.month.toString().padLeft(2, '0')}-'
                          '${pickedDate.day.toString().padLeft(2, '0')} '
                          '$timeStr';
                      setState(() {
                        _formData[label] = combined;
                        _invalidFieldIds.remove(label);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: hasError
                              ? const Color(0xFFD93025)
                              : const Color(0xFFE8EAED),
                          width: hasError ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: hasError
                            ? const Color(0xFFFCE8E6)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: hasError
                                ? const Color(0xFFD93025)
                                : const Color(0xFF9AA0A6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selected ?? 'Select date & time',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: selected != null
                                    ? const Color(0xFF202124)
                                    : const Color(0xFF9AA0A6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (typeLower == 'dropdown') {
                  fieldWidget = _CompactDropdown(
                    value: _formData[label]?.toString(),
                    hint: 'Select $label',
                    items: options,
                    hasError: hasError,
                    onChanged: (v) => setState(() {
                      _formData[label] = v;
                      _invalidFieldIds.remove(label);
                    }),
                  );
                } else if (typeLower == 'radio' || typeLower == 'radio button' || typeLower == 'chips') {
                  fieldWidget = Container(
                    padding: hasError
                        ? const EdgeInsets.all(6)
                        : EdgeInsets.zero,
                    decoration: hasError
                        ? BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFD93025), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: options.map((opt) {
                        final sel = _formData[label] == opt;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _formData[label] = opt;
                            _invalidFieldIds.remove(label);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1A73E8)
                                  : Colors.white,
                              border: Border.all(
                                color: sel
                                    ? const Color(0xFF1A73E8)
                                    : const Color(0xFFE8EAED),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              opt,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : _textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                } else if (typeLower == 'checkbox') {
                  // Parse currently selected values from the comma-separated string.
                  final rawVal = _formData[label]?.toString() ?? '';
                  final selected = rawVal.isEmpty
                      ? <String>{}
                      : rawVal.split(',').map((s) => s.trim()).toSet();

                  fieldWidget = Container(
                    padding: hasError
                        ? const EdgeInsets.all(6)
                        : EdgeInsets.zero,
                    decoration: hasError
                        ? BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFD93025), width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: options.map((opt) {
                        final checked = selected.contains(opt);
                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() {
                            final next = Set<String>.from(selected);
                            if (checked) {
                              next.remove(opt);
                            } else {
                              next.add(opt);
                            }
                            _formData[label] = next.join(', ');
                            if (next.isNotEmpty) {
                              _invalidFieldIds.remove(label);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Checkbox(
                                    value: checked,
                                    activeColor: const Color(0xFF1A73E8),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (_) => setState(() {
                                      final next = Set<String>.from(selected);
                                      if (checked) {
                                        next.remove(opt);
                                      } else {
                                        next.add(opt);
                                      }
                                      _formData[label] = next.join(', ');
                                      if (next.isNotEmpty) {
                                        _invalidFieldIds.remove(label);
                                      }
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF202124),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                } else {
                  final ctrl = _formControllers.putIfAbsent(
                    id, () => TextEditingController(),
                  );
                  fieldWidget = _CompactTextField(
                    controller: ctrl,
                    hint: 'Enter $label',
                    hasError: hasError,
                    onChanged: (v) {
                      _formData[label] = v;
                      if (hasError && v.trim().isNotEmpty) {
                        setState(() => _invalidFieldIds.remove(label));
                      }
                    },
                  );
                }

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: idx < docs.length - 1 ? 12 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _FieldLabel(label),
                          if (isRequired) ...[
                            const SizedBox(width: 3),
                            const Text('*',
                                style: TextStyle(
                                    color: Color(0xFFD93025),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      fieldWidget,
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Notes card ────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionTitle('Add Notes'),
              if (_selectedDispositionRequiresNote) ...[
                const SizedBox(width: 4),
                const Text('*',
                    style: TextStyle(
                        color: Color(0xFFD93025),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _notesError
                    ? const Color(0xFFD93025)
                    : _border,
                width: _notesError ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
              color: _notesError ? const Color(0xFFFCE8E6) : null,
            ),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
              onChanged: (_) {
                if (_notesError && _notesCtrl.text.trim().isNotEmpty) {
                  setState(() => _notesError = false);
                }
              },
              decoration: InputDecoration(
                hintText: _selectedDispositionRequiresNote
                    ? 'Required — type call notes here...'
                    : 'Type call notes here...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: _notesError
                        ? const Color(0xFFD93025)
                        : _textHint),
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Disposition card ──────────────────────────────────────────

  Widget _buildDispositionCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Select Disposition'),
          const SizedBox(height: 12),

          // ── Chip grid — loaded from Firestore ─────────────────
          FutureBuilder<QuerySnapshot>(
            future: _dispositionFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No dispositions configured.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF9AA0A6)),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                ),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final label = data['label']?.toString() ?? docs[i].id;
                  final chipColor = _hexColor(data['color']?.toString());
                  final sel = _selectedDisposition == label;
                  return GestureDetector(
                    onTap: () {
                      final requiresNote =
                          data['requiresNote'] as bool? ?? false;
                      final requiresCallback =
                          data['requiresCallback'] as bool? ?? false;
                      final dispositionType =
                          data['type'] as String? ?? 'close';
                      setState(() {
                        _selectedDisposition = label;
                        _selectedDispositionType = dispositionType;
                        _selectedDispositionRequiresNote = requiresNote;
                        _selectedDispositionRequiresCallback = requiresCallback;
                        // Clear notes error when disposition changes
                        _notesError = false;
                        if (!requiresCallback) {
                          _cbDate = null;
                          _cbTime = null;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      decoration: BoxDecoration(
                        color: sel ? chipColor : Colors.white,
                        border: Border.all(
                            color: chipColor,
                            width: sel ? 0 : 1.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (sel) ...[
                            const Icon(Icons.check, size: 11,
                                color: Colors.white),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : chipColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Callback scheduler — shown when disposition requiresCallback
          if (_selectedDispositionRequiresCallback) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Schedule Callback',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A73E8))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactDropdown(
                          value: _cbDate,
                          hint: 'Date',
                          items: _callbackDates,
                          onChanged: (v) => setState(() => _cbDate = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompactDropdown(
                          value: _cbTime,
                          hint: 'Time',
                          items: _callbackTimes,
                          onChanged: (v) => setState(() => _cbTime = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EAED))),
      ),
      child: _SubmitButton(
        enabled: _canSubmit,
        onTap: _submit,
      ),
    );
  }

  // ── Success overlay ───────────────────────────────────────────

  Widget _buildSuccessOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.35),
        alignment: Alignment.center,
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: const BoxDecoration(
                    color: Color(0xFF34A853), shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text('Submitted!',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202124))),
              const SizedBox(height: 4),
              Text('Loading next lead…',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF9AA0A6))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit button with animated state
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF1A73E8);
    final hoverColor = const Color(0xFF1557B0);
    final disabledColor = const Color(0xFFBDC1C6);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          height: 52,
          decoration: BoxDecoration(
            color: widget.enabled
                ? (_hovered ? hoverColor : activeColor)
                : disabledColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                        color: activeColor.withOpacity(0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            'Submit & Next Lead',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF5F6368)));
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF5F6368)));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.hasError = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: hasError
              ? const Color(0xFFD93025)
              : const Color(0xFFE8EAED),
          width: hasError ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
        color: hasError ? const Color(0xFFFCE8E6) : Colors.white,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF202124)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9AA0A6)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.hasError = false,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasError
              ? const Color(0xFFD93025)
              : const Color(0xFFE8EAED),
          width: hasError ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
        color: hasError ? const Color(0xFFFCE8E6) : Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF9AA0A6))),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: Color(0xFF9AA0A6)),
          style: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFF202124)),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

