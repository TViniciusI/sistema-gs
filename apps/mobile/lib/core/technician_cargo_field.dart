import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/models.dart';

/// Campo de cargo com atalhos do quadro (Técnico / Assistente Técnico…).
class TechnicianCargoField extends StatefulWidget {
  const TechnicianCargoField({
    super.key,
    required this.controller,
    this.label = 'Cargo no RDO',
    this.helperText,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<TechnicianCargoField> createState() => _TechnicianCargoFieldState();
}

class _TechnicianCargoFieldState extends State<TechnicianCargoField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant TechnicianCargoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  void _pick(String cargo) {
    widget.controller.text = cargo;
    widget.controller.selection =
        TextSelection.collapsed(offset: cargo.length);
    widget.onChanged?.call(cargo);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.text.trim().toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.sentences,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helperText ??
                'Escolha um cargo do quadro ou digite outro se precisar.',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cargo in technicianCargoOptions)
              FilterChip(
                label: Text(
                  cargo,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: current == cargo.toLowerCase(),
                onSelected: !widget.enabled
                    ? null
                    : (_) {
                        _pick(cargo);
                      },
                selectedColor: GsTheme.brass.withValues(alpha: 0.35),
                checkmarkColor: GsTheme.navy,
                labelStyle: TextStyle(
                  color: current == cargo.toLowerCase()
                      ? GsTheme.navy
                      : const Color(0xFF5C6570),
                  fontWeight: current == cargo.toLowerCase()
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
