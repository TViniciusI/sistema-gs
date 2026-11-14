import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/features/calibration/calibration_fluids_page.dart';

/// Produto da biblioteca com esse nome (sem diferenciar maiúsculas).
CatalogFluid? registeredFluidNamed(String name) {
  final key = name.trim().toLowerCase();
  if (key.isEmpty) return null;
  for (final item in CalibrationCatalog.instance.fluids) {
    if (item.name.trim().toLowerCase() == key) return item;
  }
  return null;
}

/// Escolha do produto só entre os cadastrados, em página própria.
Future<CatalogFluid?> pickRegisteredFluid(
  BuildContext context, {
  String current = '',
}) async {
  await CalibrationCatalog.instance.load();
  if (!context.mounted) return null;
  return Navigator.of(context).push<CatalogFluid>(
    MaterialPageRoute(builder: (_) => FluidPickPage(current: current)),
  );
}

class FluidPickPage extends StatefulWidget {
  const FluidPickPage({super.key, this.current = ''});

  final String current;

  @override
  State<FluidPickPage> createState() => _FluidPickPageState();
}

class _FluidPickPageState extends State<FluidPickPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _createNew() async {
    final saved = await openFluidEditPage(
      context,
      initialName: _query.text.trim(),
    );
    if (saved == null || !mounted) return;
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = widget.current.trim().toLowerCase();
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(title: const Text('Escolher produto')),
      body: AnimatedBuilder(
        animation: Listenable.merge([CalibrationCatalog.instance, _query]),
        builder: (context, _) {
          final q = _query.text.trim().toLowerCase();
          final all = [...CalibrationCatalog.instance.fluids]
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          final items = [
            for (final item in all)
              if (item.name.trim().isNotEmpty &&
                  (q.isEmpty || item.name.toLowerCase().contains(q)))
                item,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const Text(
                'Só aparecem os produtos cadastrados. A densidade e a '
                'viscosidade de cada um já vêm junto.',
                style: TextStyle(height: 1.35, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('produto-busca'),
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Buscar produto…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('produto-cadastrar-novo'),
                onPressed: _createNew,
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar produto novo'),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    all.isEmpty
                        ? 'Nenhum produto cadastrado ainda. Toque em '
                              '"Cadastrar produto novo".'
                        : 'Nenhum produto com esse nome.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF5C6570)),
                  ),
                ),
              for (final item in items)
                Card(
                  child: ListTile(
                    key: Key('produto-opcao-${item.name}'),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      item.summary.isEmpty
                          ? 'Sem densidade/viscosidade'
                          : item.summary,
                    ),
                    trailing: item.name.trim().toLowerCase() == currentKey
                        ? const Icon(Icons.check_circle, color: GsTheme.navy)
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Campo de produto que só aceita um da biblioteca.
class RegisteredFluidField extends StatelessWidget {
  const RegisteredFluidField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.onClear,
  });

  final String label;
  final String value;
  final ValueChanged<CatalogFluid> onChanged;
  final bool enabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CalibrationCatalog.instance,
      builder: (context, _) {
        final current = value.trim();
        final match = registeredFluidNamed(current);
        final outside = current.isNotEmpty && match == null;
        return InkWell(
          onTap: enabled
              ? () async {
                  final picked = await pickRegisteredFluid(
                    context,
                    current: current,
                  );
                  if (picked != null) onChanged(picked);
                }
              : null,
          child: InputDecorator(
            isEmpty: current.isEmpty,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Toque para escolher um produto cadastrado',
              helperText: outside
                  ? 'Este produto não está cadastrado. Toque e escolha um da lista.'
                  : (match != null && match.summary.isNotEmpty
                        ? match.summary
                        : null),
              helperMaxLines: 2,
              helperStyle: outside
                  ? const TextStyle(color: Color(0xFFB45309))
                  : null,
              suffixIcon: current.isNotEmpty && enabled && onClear != null
                  ? IconButton(
                      tooltip: 'Tirar produto',
                      icon: const Icon(Icons.close),
                      onPressed: onClear,
                    )
                  : const Icon(Icons.arrow_drop_down),
            ),
            child: current.isEmpty
                ? null
                : Text(
                    current,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: outside ? const Color(0xFFB45309) : GsTheme.navy,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
