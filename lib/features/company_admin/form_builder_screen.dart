import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/app_session.dart';

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

TextStyle _inter(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _kText,
}) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

// ─────────────────────────────────────────────
//  Field type model
// ─────────────────────────────────────────────
class _FieldType {
  const _FieldType(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _kFieldTypes = [
  _FieldType('Text Input', Icons.text_fields_outlined),
  _FieldType('Number', Icons.pin_outlined),
  _FieldType('Dropdown', Icons.arrow_drop_down_circle_outlined),
  _FieldType('Radio Button', Icons.radio_button_checked_outlined),
  _FieldType('Checkbox', Icons.check_box_outlined),
  _FieldType('Date Picker', Icons.calendar_today_outlined),
];

// ─────────────────────────────────────────────
//  Canvas field model
// ─────────────────────────────────────────────
class _CanvasField {
  _CanvasField({
    required this.type,
    required this.label,
    this.required = false,
    List<String>? options,
  }) : id = UniqueKey(),
       options = options ?? [];

  final Key id;
  final _FieldType type;
  String label;
  bool required;
  List<String> options;

  bool get hasOptions =>
      type.label == 'Dropdown' ||
      type.label == 'Radio Button' ||
      type.label == 'Checkbox';
}

// ─────────────────────────────────────────────
//  Root widget — exported from this file
// ─────────────────────────────────────────────
class FormBuilderContent extends StatefulWidget {
  const FormBuilderContent({
    super.key,
    required this.campaignId,
  });

  final String campaignId;

  @override
  State<FormBuilderContent> createState() => _FormBuilderContentState();
}

class _FormBuilderContentState extends State<FormBuilderContent> {
  final List<_CanvasField> _fields = [];

  bool _saving = false;
  bool _loading = true;

  // Maps the human-readable field type label to a normalized Firestore value.
  static const _typeMap = <String, String>{
    'Text Input': 'text',
    'Number': 'number',
    'Dropdown': 'dropdown',
    'Radio Button': 'radio',
    'Checkbox': 'checkbox',
    'Date Picker': 'date',
  };

  // Reverse of _typeMap: Firestore value → _FieldType label.
  static final _reverseTypeMap = <String, String>{
    for (final e in _typeMap.entries) e.value: e.key,
  };

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  Future<void> _loadSchema() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('campaigns')
          .doc(widget.campaignId)
          .collection('form_schema')
          .orderBy('order')
          .get();

      if (!mounted) return;

      final loaded = <_CanvasField>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final storedType = data['type']?.toString() ?? '';
        // Reverse-lookup: 'text' → 'Text Input', then find in _kFieldTypes.
        final typeLabel = _reverseTypeMap[storedType] ?? storedType;
        final fieldType = _kFieldTypes.firstWhere(
          (ft) => ft.label == typeLabel,
          orElse: () => _kFieldTypes[0], // fallback to Text Input
        );
        loaded.add(_CanvasField(
          type: fieldType,
          label: data['label']?.toString() ?? typeLabel,
          required: data['required'] as bool? ?? false,
          options: (data['options'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
        ));
      }

      setState(() {
        _fields.addAll(loaded);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveForm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final colRef = db
          .collection('tenants')
          .doc(AppSession.tenantId)
          .collection('campaigns')
          .doc(widget.campaignId)
          .collection('form_schema');

      final batch = db.batch();

      // Clear existing schema docs.
      final existing = await colRef.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Write one doc per canvas field, keyed by index.
      for (int i = 0; i < _fields.length; i++) {
        final f = _fields[i];
        batch.set(colRef.doc(i.toString()), {
          'label': f.label,
          'type': _typeMap[f.type.label] ?? f.type.label.toLowerCase(),
          'options': f.options,
          'required': f.required,
          'order': i,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form saved')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving form: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addField(_FieldType type) {
    setState(() {
      _fields.add(_CanvasField(type: type, label: type.label));
    });
  }

  void _removeField(Key id) {
    setState(() => _fields.removeWhere((f) => f.id == id));
  }

  void _toggleRequired(Key id) {
    setState(() {
      final f = _fields.firstWhere((f) => f.id == id);
      f.required = !f.required;
    });
  }

  void _updateLabel(Key id, String newLabel) {
    final f = _fields.firstWhere((f) => f.id == id);
    f.label = newLabel;
  }

  void _updateOptions(Key id, List<String> opts) {
    setState(() {
      final f = _fields.firstWhere((f) => f.id == id);
      f.options = opts;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left panel — field picker ──────────
        _FieldPicker(onAdd: _addField),
        // ── Right panel — canvas ───────────────
        Expanded(
          child: _FormCanvas(
            fields: _fields,
            saving: _saving,
            onSave: _saveForm,
            onRemove: _removeField,
            onToggleRequired: _toggleRequired,
            onLabelChanged: _updateLabel,
            onOptionsChanged: _updateOptions,
            onReorder: _reorder,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Left Panel — Field Type Picker
// ─────────────────────────────────────────────
class _FieldPicker extends StatelessWidget {
  const _FieldPicker({required this.onAdd});
  final ValueChanged<_FieldType> onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'Add Fields',
              style: _inter(16, weight: FontWeight.w600),
            ),
          ),
          const Divider(color: _kBorder, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                itemCount: _kFieldTypes.length,
                itemBuilder: (_, i) => _FieldTypeCard(
                  type: _kFieldTypes[i],
                  onTap: () => onAdd(_kFieldTypes[i]),
                ),
              ),
            ),
          ),
          // ── Info footer ─
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder)),
              color: Color(0xFFF8F9FA),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: _kGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Click a field to add it to the canvas.',
                    style: _inter(11, color: _kGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Individual field type card in the left panel
class _FieldTypeCard extends StatefulWidget {
  const _FieldTypeCard({required this.type, required this.onTap});
  final _FieldType type;
  final VoidCallback onTap;

  @override
  State<_FieldTypeCard> createState() => _FieldTypeCardState();
}

class _FieldTypeCardState extends State<_FieldTypeCard> {
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered ? _kBlue.withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? _kBlue : _kBorder,
              width: _hovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.type.icon,
                size: 26,
                color: _hovered ? _kBlue : _kGrey,
              ),
              const SizedBox(height: 8),
              Text(
                widget.type.label,
                textAlign: TextAlign.center,
                style: _inter(
                  11,
                  weight: FontWeight.w500,
                  color: _hovered ? _kBlue : _kText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Right Panel — Form Canvas
// ─────────────────────────────────────────────
class _FormCanvas extends StatelessWidget {
  const _FormCanvas({
    required this.fields,
    required this.saving,
    required this.onSave,
    required this.onRemove,
    required this.onToggleRequired,
    required this.onLabelChanged,
    required this.onOptionsChanged,
    required this.onReorder,
  });

  final List<_CanvasField> fields;
  final bool saving;
  final VoidCallback onSave;
  final ValueChanged<Key> onRemove;
  final ValueChanged<Key> onToggleRequired;
  final void Function(Key id, String label) onLabelChanged;
  final void Function(Key id, List<String> opts) onOptionsChanged;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar ───────────────────────────
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(
            children: [
              // ── Back button ───────────────────────
              IconButton(
                icon: const Icon(Icons.arrow_back,
                    size: 20, color: _kTextLight),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.dynamic_form_outlined,
                size: 20,
                color: _kTextLight,
              ),
              const SizedBox(width: 10),
              Text('Form Preview', style: _inter(16, weight: FontWeight.w600)),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: saving ? _kGrey : _kBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.save_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                label: Text(
                  saving ? 'Saving…' : 'Save Form',
                  style: _inter(
                    13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Canvas body ───────────────────────
        Expanded(
          child: fields.isEmpty
              ? _EmptyCanvas()
              : _FieldList(
                  fields: fields,
                  onRemove: onRemove,
                  onToggleRequired: onToggleRequired,
                  onLabelChanged: onLabelChanged,
                  onOptionsChanged: onOptionsChanged,
                  onReorder: onReorder,
                ),
        ),
      ],
    );
  }
}

// Empty state
class _EmptyCanvas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          border: Border.all(
            color: _kBorder.withOpacity(0.8),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_to_photos_outlined,
              size: 40,
              color: _kGrey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Drag fields here to build your form',
              textAlign: TextAlign.center,
              style: _inter(14, color: _kGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'Click any field type on the left to add it',
              textAlign: TextAlign.center,
              style: _inter(12, color: _kGrey.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

// Populated field list with reorder support
class _FieldList extends StatelessWidget {
  const _FieldList({
    required this.fields,
    required this.onRemove,
    required this.onToggleRequired,
    required this.onLabelChanged,
    required this.onOptionsChanged,
    required this.onReorder,
  });

  final List<_CanvasField> fields;
  final ValueChanged<Key> onRemove;
  final ValueChanged<Key> onToggleRequired;
  final void Function(Key id, String label) onLabelChanged;
  final void Function(Key id, List<String> opts) onOptionsChanged;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      buildDefaultDragHandles: false,
      onReorder: onReorder,
      itemCount: fields.length,
      itemBuilder: (context, index) {
        final field = fields[index];
        return _CanvasFieldCard(
          key: field.id,
          field: field,
          index: index,
          onRemove: () => onRemove(field.id),
          onToggleRequired: () => onToggleRequired(field.id),
          onLabelChanged: (v) => onLabelChanged(field.id, v),
          onOptionsChanged: (opts) => onOptionsChanged(field.id, opts),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Canvas Field Card
// ─────────────────────────────────────────────
class _CanvasFieldCard extends StatefulWidget {
  const _CanvasFieldCard({
    required super.key,
    required this.field,
    required this.index,
    required this.onRemove,
    required this.onToggleRequired,
    required this.onLabelChanged,
    required this.onOptionsChanged,
  });

  final _CanvasField field;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onToggleRequired;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<List<String>> onOptionsChanged;

  @override
  State<_CanvasFieldCard> createState() => _CanvasFieldCardState();
}

class _CanvasFieldCardState extends State<_CanvasFieldCard> {
  bool _hovered = false;
  bool _editingLabel = false;
  bool _optionsExpanded = false;
  late final TextEditingController _labelCtrl;
  final FocusNode _labelFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _labelFocus.addListener(() {
      if (!_labelFocus.hasFocus && _editingLabel) {
        setState(() => _editingLabel = false);
        widget.onLabelChanged(_labelCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _labelFocus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _editingLabel = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _labelFocus.requestFocus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? _kBlue.withOpacity(0.3) : _kBorder,
            ),
            boxShadow: const [
              BoxShadow(
                color: _kCardShadow,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Label row ────────────────────
              Row(
                children: [
                  // ── Drag handle ───────────────
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 20,
                          color: _hovered ? _kGrey : _kBorder,
                        ),
                      ),
                    ),
                  ),

                  // ── Field type icon ────────────
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      widget.field.type.icon,
                      size: 16,
                      color: _kBlue,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Editable label ─────────────
                  Expanded(
                    child: _editingLabel
                        ? TextField(
                            controller: _labelCtrl,
                            focusNode: _labelFocus,
                            style: _inter(14, weight: FontWeight.w500),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _kBlue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: (v) {
                              setState(() => _editingLabel = false);
                              widget.onLabelChanged(v);
                            },
                          )
                        : GestureDetector(
                            onTap: _startEditing,
                            child: Row(
                              children: [
                                Text(
                                  widget.field.label,
                                  style: _inter(14, weight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: _hovered
                                      ? _kTextLight
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                  ),

                  const SizedBox(width: 16),

                  // ── Required toggle ────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Required', style: _inter(11, color: _kTextLight)),
                      const SizedBox(width: 6),
                      Transform.scale(
                        scale: 0.78,
                        child: Switch(
                          value: widget.field.required,
                          onChanged: (_) => widget.onToggleRequired(),
                          activeColor: _kGreen,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // ── Delete button ──────────────
                  _DeleteBtn(onTap: widget.onRemove),
                ],
              ),

              // ── Options toggle (Dropdown / Radio only) ──
              if (widget.field.hasOptions) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _optionsExpanded = !_optionsExpanded),
                      child: Text(
                        'Options (${widget.field.options.length})'
                        ' ${_optionsExpanded ? '▴' : '▾'}',
                        style: _inter(
                          11,
                          color: _kGrey,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_optionsExpanded)
                  _OptionsSection(
                    options: widget.field.options,
                    onChanged: widget.onOptionsChanged,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Delete button with red hover
class _DeleteBtn extends StatefulWidget {
  const _DeleteBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Remove field',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovered ? _kRed.withOpacity(0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.delete_outline,
              size: 18,
              color: _hovered ? _kRed : _kGrey,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Options Section (Dropdown / Radio)
// ─────────────────────────────────────────────
class _OptionsSection extends StatefulWidget {
  const _OptionsSection({required this.options, required this.onChanged});

  final List<String> options;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_OptionsSection> createState() => _OptionsSectionState();
}

class _OptionsSectionState extends State<_OptionsSection> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addOption() {
    final v = _ctrl.text.trim();
    if (v.isEmpty || widget.options.contains(v)) return;
    widget.onChanged([...widget.options, v]);
    _ctrl.clear();
  }

  void _removeOption(String opt) {
    widget.onChanged(widget.options.where((o) => o != opt).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Chip list ──────────────────────────
          if (widget.options.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.options.map((opt) {
                return Chip(
                  label: Text(opt, style: _inter(11, color: _kText)),
                  deleteIcon: const Icon(Icons.close, size: 12),
                  onDeleted: () => _removeOption(opt),
                  deleteIconColor: _kGrey,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _kBorder),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          if (widget.options.isNotEmpty) const SizedBox(height: 10),
          // ── Add row ────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _ctrl,
                    style: _inter(12),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      hintText: 'New option…',
                      hintStyle: _inter(12, color: _kGrey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _kBlue, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _addOption(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: _addOption,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kBlue,
                    side: const BorderSide(color: _kBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Add',
                    style: _inter(12, color: _kBlue, weight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
