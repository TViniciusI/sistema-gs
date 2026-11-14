import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/field_store.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/os/os_calibration_slot_edit_sheet.dart';
import 'package:gs_mobile/features/os/os_hub_page.dart';
import 'package:intl/intl.dart';

/// Quem pode aprovar/recusar envio de instrumento para o cadastro.
bool canReviewCatalogSubmissions(AppUser? user) {
  if (user == null) return false;
  return user.isCleber ||
      user.canManageClientCadastro ||
      user.canManageClients;
}

Future<void> showCatalogReviewAlerts(BuildContext context) async {
  await FieldStore.instance.sync();
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const CatalogReviewPage()),
  );
}

class CatalogReviewPage extends StatefulWidget {
  const CatalogReviewPage({super.key});

  @override
  State<CatalogReviewPage> createState() => _CatalogReviewPageState();
}

class _CatalogReviewPageState extends State<CatalogReviewPage> {
  var _busy = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _approve(PendingCatalogSubmission item) async {
    final user = AuthSession.instance.user;
    if (!canReviewCatalogSubmissions(user)) {
      _toast('Sem permissão para aprovar cadastro.');
      return;
    }
    setState(() => _busy = true);
    try {
      await applyOsSlotToClientCatalog(os: item.os, slot: item.slot);
      final now = DateTime.now().toIso8601String();
      final slots = [
        for (var i = 0; i < item.os.calibrationSlots.length; i++)
          if (i == item.slotIndex)
            item.slot.copyWith(
              catalogStatus: 'approved',
              catalogReviewedAt: now,
              catalogReviewedBy: user?.name.trim().isNotEmpty == true
                  ? user!.name
                  : (user?.email ?? 'adm'),
              catalogReviewNote: '',
            )
          else
            item.os.calibrationSlots[i],
      ];
      await FieldStore.instance.saveCalibrationSlots(
        osId: item.os.id,
        slots: slots,
      );
      if (mounted) _toast('Aprovado e gravado no cadastro do cliente.');
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(PendingCatalogSubmission item) async {
    final user = AuthSession.instance.user;
    if (!canReviewCatalogSubmissions(user)) {
      _toast('Sem permissão para recusar.');
      return;
    }
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recusar · ${item.slot.certificateNumber}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            helperText: 'O técnico vê este aviso e pode corrigir e reenviar.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toIso8601String();
      final slots = [
        for (var i = 0; i < item.os.calibrationSlots.length; i++)
          if (i == item.slotIndex)
            item.slot.copyWith(
              catalogStatus: 'rejected',
              catalogReviewedAt: now,
              catalogReviewedBy: user?.name.trim().isNotEmpty == true
                  ? user!.name
                  : (user?.email ?? 'adm'),
              catalogReviewNote: note,
            )
          else
            item.os.calibrationSlots[i],
      ];
      await FieldStore.instance.saveCalibrationSlots(
        osId: item.os.id,
        slots: slots,
      );
      if (mounted) _toast('Recusado. Técnico pode corrigir e reenviar.');
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editThenDecide(PendingCatalogSubmission item) async {
    final updated = await showOsCalibrationSlotEditSheet(
      context: context,
      slot: item.slot,
      allowEdit: true,
    );
    if (updated == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final slots = [
        for (var i = 0; i < item.os.calibrationSlots.length; i++)
          if (i == item.slotIndex)
            updated.copyWith(
              catalogStatus: 'pending',
              catalogSubmittedAt: item.slot.catalogSubmittedAt.isNotEmpty
                  ? item.slot.catalogSubmittedAt
                  : DateTime.now().toIso8601String(),
              catalogSubmittedBy: item.slot.catalogSubmittedBy,
            )
          else
            item.os.calibrationSlots[i],
      ];
      await FieldStore.instance.saveCalibrationSlots(
        osId: item.os.id,
        slots: slots,
      );
      if (!mounted) return;
      final approve = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Salvar no cadastro agora?'),
          content: const Text(
            'Você editou os dados. Aprovar grava no cadastro do cliente; '
            'manter pendente deixa para decidir depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter pendente'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aprovar e gravar'),
            ),
          ],
        ),
      );
      if (approve == true && mounted) {
        final os = FieldStore.instance.byId(item.os.id) ?? item.os;
        final slot = os.calibrationSlots[item.slotIndex];
        await _approve(
          PendingCatalogSubmission(
            os: os,
            slot: slot,
            slotIndex: item.slotIndex,
          ),
        );
      }
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferência de cadastro'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await FieldStore.instance.sync();
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: FieldStore.instance,
        builder: (context, _) {
          final pending = FieldStore.instance.pendingCatalogSubmissions();
          if (pending.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum instrumento aguardando conferência.\n'
                  'Quando o técnico enviar da OS, aparece aqui no Alerta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF5C6570)),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = pending[index];
              final when = DateTime.tryParse(item.slot.catalogSubmittedAt);
              final whenLabel = when == null
                  ? ''
                  : DateFormat('dd/MM/yyyy HH:mm').format(when.toLocal());
              return Card(
                key: Key('catalog-pending-${item.slot.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OS ${item.os.number} · ${item.slot.certificateNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: GsTheme.navy,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.os.rdo.client.trim().isNotEmpty)
                            item.os.rdo.client.trim(),
                          if (item.slot.title.trim().isNotEmpty) item.slot.title,
                          if (item.slot.serialNumber.trim().isNotEmpty)
                            'N/S ${item.slot.serialNumber}',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5C6570),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.slot.catalogSubmittedBy.trim().isNotEmpty)
                            'Enviado por ${item.slot.catalogSubmittedBy}',
                          if (whenLabel.isNotEmpty) whenLabel,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy ? null : () => _approve(item),
                            child: const Text('Aprovar'),
                          ),
                          OutlinedButton(
                            onPressed: _busy ? null : () => _reject(item),
                            child: const Text('Recusar'),
                          ),
                          TextButton(
                            onPressed:
                                _busy ? null : () => _editThenDecide(item),
                            child: const Text('Editar'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => OsHubPage(
                                          osId: item.os.id,
                                          officeMode: true,
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('Abrir OS'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
