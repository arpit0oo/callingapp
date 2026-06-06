import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kBlue = Color(0xFF1A73E8);
const _kGreen = Color(0xFF34A853);
const _kRed = Color(0xFFEA4335);
const _kOrange = Color(0xFFFA7B17);
const _kGrey = Color(0xFF80868B);
const _kText = Color(0xFF202124);
const _kTextLight = Color(0xFF5F6368);
const _kBorder = Color(0xFFE8EAED);
const _kBgPage = Color(0xFFF8F9FA);
const _kCardShadow = Color(0x14000000);

TextStyle _inter(double size,
        {FontWeight weight = FontWeight.w400, Color color = _kText}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

BoxDecoration _card({double radius = 12}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(color: _kCardShadow, blurRadius: 8, offset: Offset(0, 2)),
      ],
    );

// ─────────────────────────────────────────────
//  Disposition model
// ─────────────────────────────────────────────
class _Disposition {
  _Disposition({
    required this.label,
    required this.color,
    this.requiresNote = false,
    this.callback = false,
  });
  final String label;
  final Color color;
  bool requiresNote;
  bool callback;
}

// ─────────────────────────────────────────────
//  Root widget
// ─────────────────────────────────────────────
class CampaignSettingsContent extends StatefulWidget {
  const CampaignSettingsContent({super.key});

  @override
  State<CampaignSettingsContent> createState() =>
      _CampaignSettingsContentState();
}

class _CampaignSettingsContentState extends State<CampaignSettingsContent> {
  // Dispositions
  final List<_Disposition> _dispositions = [
    _Disposition(label: 'Interested',      color: _kGreen,  requiresNote: true,  callback: false),
    _Disposition(label: 'WTL',             color: _kBlue,   requiresNote: true,  callback: true),
    _Disposition(label: 'CBL',             color: _kBlue,   requiresNote: false, callback: true),
    _Disposition(label: 'No Need',         color: _kGrey,   requiresNote: false, callback: false),
    _Disposition(label: 'DNC',             color: _kRed,    requiresNote: false, callback: false),
    _Disposition(label: 'No Answer',       color: _kOrange, requiresNote: false, callback: false),
    _Disposition(label: 'Busy',            color: _kOrange, requiresNote: false, callback: false),
    _Disposition(label: 'Invalid Number',  color: _kGrey,   requiresNote: false, callback: false),
  ];

  bool _showAddForm = false;
  final _newLabelCtrl = TextEditingController();
  Color _newColor = _kGreen;

  // Retry Logic
  int _maxRetries = 3;
  int _retryAfter = 30;
  int _dailyLimit = 5;

  // Webhook
  final _webhookCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _secretVisible = false;
  String _trigger = 'On Interested';

  static const _triggers = ['On Interested', 'On Any Disposition', 'On Form Submit'];
  static const _dotColors = [_kGreen, _kBlue, _kRed, _kOrange, _kGrey];

  @override
  void dispose() {
    _newLabelCtrl.dispose();
    _webhookCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBgPage,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top Bar ─────────────────────────────
          Row(children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.arrow_back, size: 20, color: _kTextLight),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: _kBorder)),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Campaign Settings — Xpert Tutor',
                  style: _inter(20, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Configure dispositions and integrations',
                  style: _inter(14, color: _kTextLight)),
            ]),
          ]),
          const SizedBox(height: 28),

          // ── Two-column layout ────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Left — Disposition List
            Expanded(child: _DispositionCard(
              dispositions: _dispositions,
              showAddForm: _showAddForm,
              newLabelCtrl: _newLabelCtrl,
              newColor: _newColor,
              availableColors: _dotColors,
              onAddTap: () => setState(() => _showAddForm = !_showAddForm),
              onColorPick: (c) => setState(() => _newColor = c),
              onAddConfirm: () {
                if (_newLabelCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _dispositions.add(_Disposition(
                      label: _newLabelCtrl.text.trim(),
                      color: _newColor,
                    ));
                    _newLabelCtrl.clear();
                    _showAddForm = false;
                  });
                }
              },
              onToggleNote: (i) =>
                  setState(() => _dispositions[i].requiresNote = !_dispositions[i].requiresNote),
              onToggleCallback: (i) =>
                  setState(() => _dispositions[i].callback = !_dispositions[i].callback),
              onDelete: (i) => setState(() => _dispositions.removeAt(i)),
            )),
            const SizedBox(width: 20),

            // Right — Retry Logic + Webhook
            Expanded(
              child: Column(children: [
                _RetryLogicCard(
                  maxRetries: _maxRetries,
                  retryAfter: _retryAfter,
                  dailyLimit: _dailyLimit,
                  onMaxRetries: (v) => setState(() => _maxRetries = v),
                  onRetryAfter: (v) => setState(() => _retryAfter = v),
                  onDailyLimit: (v) => setState(() => _dailyLimit = v),
                ),
                const SizedBox(height: 20),
                _WebhookCard(
                  webhookCtrl: _webhookCtrl,
                  secretCtrl: _secretCtrl,
                  secretVisible: _secretVisible,
                  trigger: _trigger,
                  triggers: _triggers,
                  onToggleSecret: () =>
                      setState(() => _secretVisible = !_secretVisible),
                  onTriggerChanged: (v) => setState(() => _trigger = v!),
                ),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Left — Disposition Card
// ─────────────────────────────────────────────
class _DispositionCard extends StatelessWidget {
  const _DispositionCard({
    required this.dispositions,
    required this.showAddForm,
    required this.newLabelCtrl,
    required this.newColor,
    required this.availableColors,
    required this.onAddTap,
    required this.onColorPick,
    required this.onAddConfirm,
    required this.onToggleNote,
    required this.onToggleCallback,
    required this.onDelete,
  });

  final List<_Disposition> dispositions;
  final bool showAddForm;
  final TextEditingController newLabelCtrl;
  final Color newColor;
  final List<Color> availableColors;
  final VoidCallback onAddTap;
  final ValueChanged<Color> onColorPick;
  final VoidCallback onAddConfirm;
  final ValueChanged<int> onToggleNote;
  final ValueChanged<int> onToggleCallback;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
          child: Row(children: [
            Text('Disposition List', style: _inter(16, weight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _kBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: _kBlue.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: onAddTap,
              icon: Icon(showAddForm ? Icons.close : Icons.add, size: 15),
              label: Text(showAddForm ? 'Cancel' : 'Add Disposition',
                  style: _inter(12, weight: FontWeight.w500, color: _kBlue)),
            ),
          ]),
        ),
        const Divider(color: _kBorder, height: 1),

        // Column headers
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Row(children: [
            Expanded(child: Text('Disposition', style: _inter(11, weight: FontWeight.w600, color: _kGrey))),
            SizedBox(width: 70, child: Text('Note', textAlign: TextAlign.center, style: _inter(11, weight: FontWeight.w600, color: _kGrey))),
            SizedBox(width: 80, child: Text('Callback', textAlign: TextAlign.center, style: _inter(11, weight: FontWeight.w600, color: _kGrey))),
            const SizedBox(width: 32),
          ]),
        ),

        // Rows
        ...dispositions.asMap().entries.map((e) => _DispositionRow(
              disposition: e.value,
              index: e.key,
              onToggleNote: onToggleNote,
              onToggleCallback: onToggleCallback,
              onDelete: onDelete,
            )),

        // Add inline form
        if (showAddForm) ...[
          const Divider(color: _kBorder, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New Disposition', style: _inter(12, weight: FontWeight.w600, color: _kTextLight)),
              const SizedBox(height: 8),
              TextField(
                controller: newLabelCtrl,
                style: _inter(13),
                decoration: InputDecoration(
                  hintText: 'Disposition label...',
                  hintStyle: _inter(13, color: _kGrey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                  filled: true, fillColor: _kBgPage,
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text('Color: ', style: _inter(12, color: _kTextLight)),
                const SizedBox(width: 8),
                ...availableColors.map((c) => GestureDetector(
                      onTap: () => onColorPick(c),
                      child: Container(
                        width: 22, height: 22,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle,
                          border: Border.all(
                            color: c == newColor ? _kText : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    )),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                  onPressed: onAddConfirm,
                  child: Text('Add', style: _inter(12, weight: FontWeight.w600, color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ],

        const SizedBox(height: 8),
      ]),
    );
  }
}

class _DispositionRow extends StatefulWidget {
  const _DispositionRow({
    required this.disposition,
    required this.index,
    required this.onToggleNote,
    required this.onToggleCallback,
    required this.onDelete,
  });
  final _Disposition disposition;
  final int index;
  final ValueChanged<int> onToggleNote, onToggleCallback, onDelete;

  @override
  State<_DispositionRow> createState() => _DispositionRowState();
}

class _DispositionRowState extends State<_DispositionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? _kBgPage : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          // Dot + label
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: widget.disposition.color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.disposition.label,
              style: _inter(13, weight: FontWeight.w500))),
          // Note toggle
          SizedBox(
            width: 70,
            child: Center(
              child: Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: widget.disposition.requiresNote,
                  onChanged: (_) => widget.onToggleNote(widget.index),
                  activeColor: _kBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          // Callback toggle
          SizedBox(
            width: 80,
            child: Center(
              child: Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: widget.disposition.callback,
                  onChanged: (_) => widget.onToggleCallback(widget.index),
                  activeColor: _kBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          // Delete
          _DelBtn(onTap: () => widget.onDelete(widget.index)),
        ]),
      ),
    );
  }
}

class _DelBtn extends StatefulWidget {
  const _DelBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_DelBtn> createState() => _DelBtnState();
}

class _DelBtnState extends State<_DelBtn> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hov ? _kRed.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.delete_outline, size: 17,
              color: _hov ? _kRed : _kGrey),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Right Top — Retry Logic Card
// ─────────────────────────────────────────────
class _RetryLogicCard extends StatelessWidget {
  const _RetryLogicCard({
    required this.maxRetries,
    required this.retryAfter,
    required this.dailyLimit,
    required this.onMaxRetries,
    required this.onRetryAfter,
    required this.onDailyLimit,
  });

  final int maxRetries, retryAfter, dailyLimit;
  final ValueChanged<int> onMaxRetries, onRetryAfter, onDailyLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Retry Logic', style: _inter(16, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Control how often leads are called back',
            style: _inter(12, color: _kGrey)),
        const SizedBox(height: 16),
        const Divider(color: _kBorder, height: 1),
        const SizedBox(height: 16),
        _StepperRow(label: 'Max Retries per Lead', value: maxRetries,
            min: 1, max: 10, onChanged: onMaxRetries),
        const SizedBox(height: 14),
        _StepperRow(label: 'Retry After (minutes)', value: retryAfter,
            min: 5, max: 120, step: 5, onChanged: onRetryAfter),
        const SizedBox(height: 14),
        _StepperRow(label: 'Daily Call Limit per Lead', value: dailyLimit,
            min: 1, max: 20, onChanged: onDailyLimit),
      ]),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100,
    this.step = 1,
  });
  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: _inter(13, weight: FontWeight.w500))),
      // Stepper
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _StepBtn(icon: Icons.remove, onTap: value > min
              ? () => onChanged(value - step) : null),
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text('$value', style: _inter(14, weight: FontWeight.w600)),
          ),
          _StepBtn(icon: Icons.add, onTap: value < max
              ? () => onChanged(value + step) : null),
        ]),
      ),
    ]);
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 16,
            color: onTap != null ? _kText : _kBorder),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Right Bottom — Webhook Card
// ─────────────────────────────────────────────
class _WebhookCard extends StatelessWidget {
  const _WebhookCard({
    required this.webhookCtrl,
    required this.secretCtrl,
    required this.secretVisible,
    required this.trigger,
    required this.triggers,
    required this.onToggleSecret,
    required this.onTriggerChanged,
  });

  final TextEditingController webhookCtrl, secretCtrl;
  final bool secretVisible;
  final String trigger;
  final List<String> triggers;
  final VoidCallback onToggleSecret;
  final ValueChanged<String?> onTriggerChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Webhook / CRM Integration',
            style: _inter(16, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Push lead data to your CRM on disposition',
            style: _inter(12, color: _kGrey)),
        const SizedBox(height: 16),
        const Divider(color: _kBorder, height: 1),
        const SizedBox(height: 16),

        // Webhook URL
        _FLabel('Webhook URL'),
        const SizedBox(height: 6),
        _TField(controller: webhookCtrl, hint: 'https://your-crm.com/webhook'),
        const SizedBox(height: 16),

        // Trigger
        _FLabel('Trigger Event'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: _kBgPage,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: trigger,
              isExpanded: true,
              style: _inter(13),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kTextLight),
              onChanged: onTriggerChanged,
              items: triggers.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Secret Key
        _FLabel('Secret Key'),
        const SizedBox(height: 6),
        _TField(
          controller: secretCtrl,
          hint: '••••••••••••••••',
          obscure: !secretVisible,
          suffix: IconButton(
            icon: Icon(secretVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
                size: 18, color: _kGrey),
            onPressed: onToggleSecret,
            splashRadius: 18,
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTextLight,
                side: const BorderSide(color: _kBorder),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.wifi_tethering_outlined, size: 16),
              label: Text('Test Webhook', style: _inter(13, weight: FontWeight.w500, color: _kTextLight)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kBlue,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              icon: const Icon(Icons.save_outlined, size: 16, color: Colors.white),
              label: Text('Save Settings',
                  style: _inter(13, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _FLabel extends StatelessWidget {
  const _FLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: _inter(12, weight: FontWeight.w600, color: _kTextLight));
}

class _TField extends StatelessWidget {
  const _TField({required this.controller, required this.hint, this.obscure = false, this.suffix});
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: _inter(13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _inter(13, color: _kGrey),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        filled: true, fillColor: _kBgPage,
      ),
    );
  }
}
