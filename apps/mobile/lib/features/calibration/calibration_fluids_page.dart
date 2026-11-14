import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';

class CalibrationFluidsPage extends StatefulWidget {
  const CalibrationFluidsPage({super.key});

  @override
  State<CalibrationFluidsPage> createState() => _CalibrationFluidsPageState();
}

class _CalibrationFluidsPageState extends State<CalibrationFluidsPage> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    CalibrationCatalog.instance.load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _edit([CatalogFluid? existing]) async {
    await openFluidEditPage(context, existing: existing);
  }

  Future<void> _delete(CatalogFluid item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir fluido?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await CalibrationCatalog.instance.deleteFluid(item.id);
  }

  var _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await CalibrationCatalog.instance.sync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fluidos sincronizados com a nuvem.')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos (fluidos)'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar com a nuvem',
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : _sync,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('fluido-novo'),
        onPressed: () => _edit(),
        backgroundColor: GsTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          CalibrationCatalog.instance,
          _query,
        ]),
        builder: (context, _) {
          final q = _query.text.trim().toLowerCase();
          final items = [
            for (final item in CalibrationCatalog.instance.fluids)
              if (q.isEmpty || item.name.toLowerCase().contains(q)) item,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text(
                'Biblioteca de fluidos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cadastre densidade e viscosidade em faixa (mínima e máxima). '
                'A temperatura de referência da densidade é 20 °C. No cadastro '
                'do medidor o produto sai desta lista. Na emissão do certificado '
                'só entra a densidade e a temperatura medidas na calibração.',
                style: TextStyle(height: 1.35, color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Buscar fluido…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                items.isEmpty
                    ? 'Nenhum fluido ainda.'
                    : '${items.length} fluido(s)',
                style: const TextStyle(color: Color(0xFF5C6570)),
              ),
              const SizedBox(height: 8),
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      item.summary.isEmpty
                          ? 'Sem densidade/viscosidade'
                          : item.summary,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(item),
                    ),
                    onTap: () => _edit(item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Abre o cadastro do produto em página própria e grava na biblioteca.
/// Devolve o produto salvo (ou nulo se voltou sem salvar).
Future<CatalogFluid?> openFluidEditPage(
  BuildContext context, {
  CatalogFluid? existing,
  String initialName = '',
}) async {
  final saved = await Navigator.of(context).push<CatalogFluid>(
    MaterialPageRoute(
      builder: (_) => CalibrationFluidEditPage(
        existing: existing,
        initialName: initialName,
      ),
    ),
  );
  if (saved == null) return null;
  await CalibrationCatalog.instance.saveFluid(saved);
  return saved;
}

class CalibrationFluidEditPage extends StatefulWidget {
  const CalibrationFluidEditPage({
    super.key,
    this.existing,
    this.initialName = '',
  });

  final CatalogFluid? existing;
  final String initialName;

  @override
  State<CalibrationFluidEditPage> createState() =>
      _CalibrationFluidEditPageState();
}

class _CalibrationFluidEditPageState extends State<CalibrationFluidEditPage> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late final _densityMin =
      TextEditingController(text: widget.existing?.densityMin);
  late final _densityMax =
      TextEditingController(text: widget.existing?.densityMax);
  late final _viscosityMin =
      TextEditingController(text: widget.existing?.viscosityMin);
  late final _viscosityMax =
      TextEditingController(text: widget.existing?.viscosityMax);
  late final _densityRefTemp = TextEditingController(
    text: widget.existing?.densityRefTemp.isNotEmpty == true
        ? widget.existing!.densityRefTemp
        : fluidDensityRefTempDefault,
  );
  late final _viscosityRefTemp = TextEditingController(
    text: widget.existing?.viscosityRefTemp.isNotEmpty == true
        ? widget.existing!.viscosityRefTemp
        : fluidViscosityRefTempDefault,
  );

  @override
  void dispose() {
    _name.dispose();
    _densityMin.dispose();
    _densityMax.dispose();
    _viscosityMin.dispose();
    _viscosityMax.dispose();
    _densityRefTemp.dispose();
    _viscosityRefTemp.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do produto.')),
      );
      return;
    }
    final key = name.toLowerCase();
    final duplicate = CalibrationCatalog.instance.fluids.any(
      (item) =>
          item.id != widget.existing?.id &&
          item.name.trim().toLowerCase() == key,
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Já existe um produto chamado "$name".')),
      );
      return;
    }
    final dRef = _densityRefTemp.text.trim();
    final vRef = _viscosityRefTemp.text.trim();
    Navigator.pop(
      context,
      CatalogFluid(
        id: widget.existing?.id ?? newCatalogId(),
        name: name,
        densityMin: _densityMin.text.trim(),
        densityMax: _densityMax.text.trim(),
        viscosityMin: _viscosityMin.text.trim(),
        viscosityMax: _viscosityMax.text.trim(),
        densityRefTemp: dRef.isNotEmpty ? dRef : fluidDensityRefTempDefault,
        viscosityRefTemp: vRef.isNotEmpty ? vRef : fluidViscosityRefTempDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Novo produto' : 'Editar produto'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Densidade e viscosidade em faixa (mínima e máxima). Esses dados '
              'entram sozinhos no certificado quando o produto é escolhido no '
              'cadastro do instrumento.',
              style: TextStyle(height: 1.35, color: Color(0xFF5C6570)),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('fluido-nome'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome do fluido'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Densidade',
              style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fluido-densidade-min'),
                    controller: _densityMin,
                    decoration: const InputDecoration(
                      labelText: 'Mínima',
                      helperText: 'ex.: 0,780 g/cm³',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('fluido-densidade-max'),
                    controller: _densityMax,
                    decoration: const InputDecoration(
                      labelText: 'Máxima',
                      helperText: 'ex.: 0,840 g/cm³',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Viscosidade',
              style: TextStyle(fontWeight: FontWeight.w700, color: GsTheme.navy),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fluido-viscosidade-min'),
                    controller: _viscosityMin,
                    decoration: const InputDecoration(
                      labelText: 'Mínima',
                      helperText: 'ex.: 1,5 cSt',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('fluido-viscosidade-max'),
                    controller: _viscosityMax,
                    decoration: const InputDecoration(
                      labelText: 'Máxima',
                      helperText: 'ex.: 3,5 cSt',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fluido-densidade-ref-temp'),
                    controller: _densityRefTemp,
                    decoration: const InputDecoration(
                      labelText: 'Temp. ref. densidade',
                      helperText: 'Norma: 20 °C',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('fluido-viscosidade-ref-temp'),
                    controller: _viscosityRefTemp,
                    decoration: const InputDecoration(
                      labelText: 'Temp. ref. viscosidade',
                      helperText: 'Norma: 40 °C',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('fluido-salvar'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: GsTheme.brass,
                foregroundColor: Colors.black,
              ),
              child: const Text('Salvar produto'),
            ),
          ],
        ),
      ),
    );
  }
}
