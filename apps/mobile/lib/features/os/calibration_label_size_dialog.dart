import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gs_mobile/core/app_date_picker.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_label_pdf.dart';

/// Tamanho escolhido e, se o usuário quiser, uma data única para os adesivos.
class CalibrationLabelPrintOptions {
  const CalibrationLabelPrintOptions({
    required this.size,
    this.dateOverride = '',
    this.combineSameMeter = false,
  });

  final CalibrationLabelSize size;

  /// dd/MM/yyyy; vazio = data de cada item/certificado.
  final String dateOverride;

  /// Mesmo medidor/preset: um adesivo com todos os nºs de certificado.
  final bool combineSameMeter;
}

/// Diálogo para escolher largura × altura do adesivo (mm) e a data impressa.
/// [currentDate] aparece como referência quando é um adesivo só.
/// [sameMeterCount] > 1 mostra a opção junto vs individual.
Future<CalibrationLabelPrintOptions?> showCalibrationLabelSizeDialog(
  BuildContext context, {
  String currentDate = '',
  int sameMeterCount = 0,
}) async {
  var selected = CalibrationLabelSize.standard;
  final widthCtrl = TextEditingController(
    text: selected.widthMm.toInt().toString(),
  );
  final heightCtrl = TextEditingController(
    text: selected.heightMm.toInt().toString(),
  );
  var customMode = false;
  var customDate = false;
  var pickedDate = '';
  var combineSameMeter = sameMeterCount > 1;

  CalibrationLabelSize? parseCustom() {
    final w = double.tryParse(widthCtrl.text.replaceAll(',', '.'));
    final h = double.tryParse(heightCtrl.text.replaceAll(',', '.'));
    if (w == null || h == null) return null;
    if (w < 20 || h < 20 || w > 200 || h > 300) return null;
    return CalibrationLabelSize(widthMm: w, heightMm: h);
  }

  final result = await showDialog<CalibrationLabelPrintOptions>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final initial =
                parseCalibrationDateLabel(pickedDate) ??
                parseCalibrationDateLabel(currentDate) ??
                now;
            final picked = await pickAppDate(
              context,
              initialDate: initial,
              firstDate: DateTime(now.year - 3),
              lastDate: DateTime(now.year + 1, 12, 31),
            );
            if (picked == null) return;
            setLocal(() {
              customDate = true;
              pickedDate = formatCalibrationDateLabel(picked);
            });
          }

          return AlertDialog(
            backgroundColor: GsTheme.paper,
            title: const Text('Gerar adesivo'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sameMeterCount > 1) ...[
                      Text(
                        'Mesmo medidor com $sameMeterCount certificados',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: GsTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            key: const Key('adesivo-medidor-junto'),
                            label: const Text('Tudo na mesma etiqueta'),
                            selected: combineSameMeter,
                            onSelected: (_) =>
                                setLocal(() => combineSameMeter = true),
                          ),
                          ChoiceChip(
                            key: const Key('adesivo-medidor-individual'),
                            label: const Text('Uma etiqueta por certificado'),
                            selected: !combineSameMeter,
                            onSelected: (_) =>
                                setLocal(() => combineSameMeter = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        combineSameMeter
                            ? 'Sai 1 adesivo com N/S, data e todos os nºs de certificado dos produtos.'
                            : 'Sai 1 adesivo para cada certificado, como antes.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5C6570),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Tamanho em milímetros (padrão do cliente: 40 × 60).',
                      style: TextStyle(fontSize: 14, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in CalibrationLabelSize.presets)
                          ChoiceChip(
                            label: Text(preset.displayLabel),
                            selected:
                                !customMode &&
                                selected.widthMm == preset.widthMm &&
                                selected.heightMm == preset.heightMm,
                            onSelected: (_) {
                              setLocal(() {
                                customMode = false;
                                selected = preset;
                                widthCtrl.text = preset.widthMm
                                    .toInt()
                                    .toString();
                                heightCtrl.text = preset.heightMm
                                    .toInt()
                                    .toString();
                              });
                            },
                          ),
                        ChoiceChip(
                          label: const Text('Personalizado'),
                          selected: customMode,
                          onSelected: (_) {
                            setLocal(() => customMode = true);
                          },
                        ),
                      ],
                    ),
                    if (customMode) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widthCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Largura (mm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: heightCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Altura (mm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Data da calibração no adesivo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GsTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          key: const Key('adesivo-data-certificado'),
                          label: Text(
                            currentDate.trim().isEmpty
                                ? 'A de cada certificado'
                                : 'A do certificado ($currentDate)',
                          ),
                          selected: !customDate,
                          onSelected: (_) => setLocal(() => customDate = false),
                        ),
                        ChoiceChip(
                          key: const Key('adesivo-data-escolher'),
                          avatar: const Icon(Icons.event, size: 18),
                          label: Text(
                            pickedDate.isEmpty
                                ? 'Escolher data'
                                : 'Usar $pickedDate',
                          ),
                          selected: customDate,
                          onSelected: (_) => pickDate(),
                        ),
                      ],
                    ),
                    if (customDate && currentDate.trim().isEmpty) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Todos os adesivos desta impressão saem com essa data.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF5C6570)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
                onPressed: () {
                  var size = selected;
                  if (customMode) {
                    final custom = parseCustom();
                    if (custom == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Informe largura e altura válidas (20–200 × 20–300 mm).',
                          ),
                        ),
                      );
                      return;
                    }
                    size = custom;
                  }
                  Navigator.of(dialogCtx).pop(
                    CalibrationLabelPrintOptions(
                      size: size,
                      dateOverride: customDate ? pickedDate : '',
                      combineSameMeter:
                          sameMeterCount > 1 && combineSameMeter,
                    ),
                  );
                },
                child: const Text('Gerar adesivo'),
              ),
            ],
          );
        },
      );
    },
  );

  widthCtrl.dispose();
  heightCtrl.dispose();
  return result;
}
