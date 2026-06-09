import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';
import '../../services/lead_service.dart';
import '../../services/rtdb_service.dart';
import 'caller_shell.dart';

class CallingWorkspaceContent extends StatefulWidget {
  const CallingWorkspaceContent({
    super.key,
    required this.role,
    required this.currentLead,
  });

  final String role;
  final Map<String, dynamic>? currentLead;

  @override
  State<CallingWorkspaceContent> createState() =>
      _CallingWorkspaceContentState();
}

class _CallingWorkspaceContentState extends State<CallingWorkspaceContent> {
  static const _primary = Color(0xFF1A73E8);
  static const _textPrimary = Color(0xFF202124);
  static const _textSecondary = Color(0xFF5F6368);
  static const _textHint = Color(0xFF9AA0A6);
  static const _border = Color(0xFFE8EAED);
  static const _bg = Color(0xFFF8F9FA);

  final _notesCtrl = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, dynamic> _fieldValues = {};

  List<_FormFieldConfig> _formFields = [];
  List<_DispositionOption> _dispositions = [];
  bool _loadingConfig = true;
  bool _submitting = false;
  String? _selectedDisposition;

  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadWorkspaceConfig();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || widget.currentLead == null) return;
      setState(() => _seconds++);
    });
  }

  @override
  void didUpdateWidget(covariant CallingWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_leadIdFrom(oldWidget.currentLead) != _leadId) {
      setState(_resetForCurrentLead);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesCtrl.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWorkspaceConfig() async {
    setState(() => _loadingConfig = true);

    final campaignRef = FirebaseFirestore.instance
        .collection('tenants')
        .doc(AppSession.tenantId)
        .collection('campaigns')
        .doc(AppSession.campaignId);

    try {
      final results = await Future.wait([
        campaignRef.collection('form_schema').orderBy('order').get(),
        campaignRef.collection('disposition_config').orderBy('order').get(),
      ]);

      final formFields = (results[0] as QuerySnapshot)
          .docs
          .map((doc) => _FormFieldConfig.fromDoc(doc))
          .toList();
      final dispositions = (results[1] as QuerySnapshot)
          .docs
          .map((doc) => _DispositionOption.fromDoc(doc))
          .toList();

      if (!mounted) return;

      setState(() {
        _formFields = formFields;
        _dispositions = dispositions;
        _loadingConfig = false;
        _resetForCurrentLead();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConfig = false);
    }
  }

  void _resetForCurrentLead() {
    _selectedDisposition = null;
    _notesCtrl.clear();
    _seconds = 0;
    _fieldValues.clear();

    for (final field in _formFields) {
      final seededValue = _seedValueForField(field);
      final controller = _fieldControllers[field.key];

      if (controller != null) {
        controller.text = seededValue is String ? seededValue : '';
      }

      if (seededValue is String && seededValue.isNotEmpty) {
        _fieldValues[field.key] = seededValue;
      }
      if (seededValue is List && seededValue.isNotEmpty) {
        _fieldValues[field.key] = List<String>.from(seededValue);
      }
    }
  }

  String? get _leadId => _leadIdFrom(widget.currentLead);

  String? _leadIdFrom(Map<String, dynamic>? lead) {
    final value = lead?['id'] ?? lead?['leadId'];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String get _leadPhone {
    return _readLeadValue(['phone', 'phoneNumber', 'mobile', 'mobileNumber']) ??
        'Unknown number';
  }

  String get _leadName {
    return _readLeadValue(['name', 'fullName', 'leadName']) ?? 'Current Lead';
  }

  String? _readLeadValue(List<String> keys) {
    final lead = widget.currentLead;
    if (lead == null) return null;

    for (final key in keys) {
      final value = lead[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  dynamic _seedValueForField(_FormFieldConfig field) {
    final lead = widget.currentLead;
    if (lead == null) return field.kind == _FieldKind.checkbox ? <String>[] : '';

    final candidates = <String>{
      field.key,
      field.label,
      _normalizeFieldKey(field.label),
    };

    dynamic rawValue;
    for (final candidate in candidates) {
      final value = lead[candidate];
      if (value != null) {
        rawValue = value;
        break;
      }
    }

    if (field.kind == _FieldKind.checkbox) {
      if (rawValue is List) {
        return rawValue.map((item) => item.toString()).toList();
      }
      if (rawValue is String && rawValue.trim().isNotEmpty) {
        return [rawValue.trim()];
      }
      return <String>[];
    }

    return rawValue?.toString() ?? '';
  }

  String _normalizeFieldKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  TextEditingController _controllerFor(_FormFieldConfig field) {
    return _fieldControllers.putIfAbsent(field.key, () {
      final initialValue = _seedValueForField(field);
      final controller = TextEditingController(
        text: initialValue is String ? initialValue : '',
      );
      if (controller.text.isNotEmpty) {
        _fieldValues[field.key] = controller.text;
      }
      return controller;
    });
  }

  String get _timerLabel {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _canSubmit =>
      !_submitting &&
      widget.currentLead != null &&
      _selectedDisposition != null &&
      _leadId != null;

  Future<void> _pickDate(_FormFieldConfig field) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (selected == null || !mounted) return;

    final value =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';

    setState(() {
      _controllerFor(field).text = value;
      _fieldValues[field.key] = value;
    });
  }

  Map<String, dynamic> _buildFormData() {
    final data = <String, dynamic>{};

    for (final field in _formFields) {
      dynamic value = _fieldValues[field.key];

      if ((value == null || value == '') &&
          (field.kind == _FieldKind.text ||
              field.kind == _FieldKind.number ||
              field.kind == _FieldKind.date)) {
        value = _fieldControllers[field.key]?.text.trim();
      }

      if (value is String && value.trim().isEmpty) {
        continue;
      }
      if (value is List && value.isEmpty) {
        continue;
      }
      if (value == null) {
        continue;
      }

      data[field.label] = value;
    }

    return data;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final leadId = _leadId;
    if (leadId == null) return;

    setState(() => _submitting = true);

    try {
      await LeadService.submitDisposition(
        AppSession.tenantId,
        leadId,
        {
          'campaignId': AppSession.campaignId,
          'dispositionLabel': _selectedDisposition,
          'formData': _buildFormData(),
          'notes': _notesCtrl.text.trim(),
          'disposedBy': AppSession.userId,
        },
      );

      await RtdbService.updateCallerState(
        AppSession.tenantId,
        AppSession.userId,
        {
          'status': 'idle',
          'currentLeadId': '',
          'lastSeen': ServerValue.timestamp,
        },
      );

      CallerShell.shellKey.currentState?.clearCurrentLead();
      CallerShell.shellKey.currentState?.navigateTo(0);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit disposition: $error')),
      );
      setState(() => _submitting = false);
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentLead == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _buildTopBar(title: 'Workspace'),
        body: _buildEmptyState(),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildTopBar(title: _leadPhone),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildTopBar({required String title}) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 22, color: _textPrimary),
        onPressed: () => CallerShell.shellKey.currentState?.navigateTo(0),
      ),
      centerTitle: true,
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              _timerLabel,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF34A853),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.headset_mic_outlined, size: 48, color: _textHint),
            const SizedBox(height: 16),
            Text(
              'No active lead',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a lead from the Home tab to start calling.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => CallerShell.shellKey.currentState?.navigateTo(0),
              child: Text(
                'Go to Home tab',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadCard() {
    final initials = _leadName.isNotEmpty
        ? _leadName
            .split(' ')
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join()
        : 'LD';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _leadName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _leadPhone,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Campaign Form'),
          const SizedBox(height: 12),
          if (_loadingConfig)
            const Center(child: CircularProgressIndicator())
          else if (_formFields.isEmpty)
            Text(
              'No form fields configured for this campaign.',
              style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
            )
          else
            ..._formFields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(field.label),
                    const SizedBox(height: 6),
                    _buildDynamicField(field),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDynamicField(_FormFieldConfig field) {
    switch (field.kind) {
      case _FieldKind.dropdown:
        return _CompactDropdownFormField(
          value: _fieldValues[field.key] as String?,
          hint: 'Select ${field.label}',
          items: field.options,
          onChanged: (value) => setState(() => _fieldValues[field.key] = value),
        );
      case _FieldKind.radio:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((option) {
            final selected = _fieldValues[field.key] == option;
            return ChoiceChip(
              label: Text(option),
              selected: selected,
              onSelected: (_) {
                setState(() => _fieldValues[field.key] = option);
              },
            );
          }).toList(),
        );
      case _FieldKind.checkbox:
        final selectedValues =
            List<String>.from(_fieldValues[field.key] as List? ?? <String>[]);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: field.options.map((option) {
            final selected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: selected,
              onSelected: (isSelected) {
                setState(() {
                  if (isSelected) {
                    selectedValues.add(option);
                  } else {
                    selectedValues.remove(option);
                  }
                  _fieldValues[field.key] = List<String>.from(selectedValues);
                });
              },
            );
          }).toList(),
        );
      case _FieldKind.date:
        return _CompactTextField(
          controller: _controllerFor(field),
          hint: 'Select date',
          readOnly: true,
          onTap: () => _pickDate(field),
        );
      case _FieldKind.number:
        return _CompactTextField(
          controller: _controllerFor(field),
          hint: field.label,
          keyboardType: TextInputType.number,
          onChanged: (value) => _fieldValues[field.key] = value,
        );
      case _FieldKind.text:
        return _CompactTextField(
          controller: _controllerFor(field),
          hint: field.label,
          onChanged: (value) => _fieldValues[field.key] = value,
        );
    }
  }

  Widget _buildNotesCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Add Notes'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Type call notes here...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _textHint),
                contentPadding: const EdgeInsets.all(12),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispositionCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Select Disposition'),
          const SizedBox(height: 12),
          if (_loadingConfig)
            const Center(child: CircularProgressIndicator())
          else if (_dispositions.isEmpty)
            Text(
              'No dispositions configured for this campaign.',
              style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dispositions.map((disposition) {
                final selected = _selectedDisposition == disposition.label;
                return ChoiceChip(
                  label: Text(disposition.label),
                  selected: selected,
                  selectedColor: disposition.color.withOpacity(0.18),
                  side: BorderSide(color: disposition.color),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? disposition.color : _textSecondary,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedDisposition = disposition.label);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: _SubmitButton(
        enabled: _canSubmit,
        loading: _submitting,
        onTap: _submit,
      ),
    );
  }
}

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
            offset: const Offset(0, 2),
          ),
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
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF5F6368),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF5F6368),
      ),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8EAED)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF202124),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF9AA0A6),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _CompactDropdownFormField extends StatelessWidget {
  const _CompactDropdownFormField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF9AA0A6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8EAED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8EAED)),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF202124),
                  ),
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final Future<void> Function() onTap;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1A73E8);
    const hoverColor = Color(0xFF1557B0);
    const disabledColor = Color(0xFFBDC1C6);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled
            ? () {
                widget.onTap();
              }
            : null,
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
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Text(
                  'Submit',
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

enum _FieldKind {
  text,
  number,
  dropdown,
  radio,
  checkbox,
  date,
}

class _FormFieldConfig {
  const _FormFieldConfig({
    required this.key,
    required this.label,
    required this.kind,
    required this.options,
  });

  factory _FormFieldConfig.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawType = (data['type'] as String? ?? 'Text Input').toLowerCase();

    _FieldKind kind;
    if (rawType.contains('dropdown')) {
      kind = _FieldKind.dropdown;
    } else if (rawType.contains('radio')) {
      kind = _FieldKind.radio;
    } else if (rawType.contains('checkbox')) {
      kind = _FieldKind.checkbox;
    } else if (rawType.contains('date')) {
      kind = _FieldKind.date;
    } else if (rawType.contains('number')) {
      kind = _FieldKind.number;
    } else {
      kind = _FieldKind.text;
    }

    return _FormFieldConfig(
      key: doc.id,
      label: data['label'] as String? ?? doc.id,
      kind: kind,
      options: (data['options'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final String key;
  final String label;
  final _FieldKind kind;
  final List<String> options;
}

class _DispositionOption {
  const _DispositionOption({
    required this.label,
    required this.color,
  });

  factory _DispositionOption.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final colorValue = (data['color'] as num?)?.toInt() ?? _primaryColorValue;

    return _DispositionOption(
      label: data['label'] as String? ?? doc.id,
      color: Color(colorValue),
    );
  }

  static const _primaryColorValue = 0xFF1A73E8;

  final String label;
  final Color color;
}
