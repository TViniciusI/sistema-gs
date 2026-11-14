import 'package:flutter/material.dart';
import 'package:gs_mobile/core/search_pick_sheet.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/features/calibration/calibration_badges.dart';

class CalibrationStandardsPage extends StatefulWidget {
  const CalibrationStandardsPage({super.key});

  @override
  State<CalibrationStandardsPage> createState() =>
      _CalibrationStandardsPageState();
}

class _CalibrationStandardsPageState extends State<CalibrationStandardsPage> {
  final _search = TextEditingController();
  /// null com [_onlyUncategorized] falso = todos.
  StandardCategory? _filter;
  var _onlyUncategorized = false;

  @override
  void initState() {
    super.initState();
    CalibrationCatalog.instance.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([CatalogStandard? existing]) async {
    final saved = await Navigator.of(context).push<CatalogStandard>(
      MaterialPageRoute(
        builder: (_) => _StandardEditPage(
          existing: existing,
          initialCategory: existing == null ? _filter : null,
        ),
      ),
    );
    if (saved == null) return;
    await CalibrationCatalog.instance.saveStandard(saved);
  }

  Future<void> _delete(CatalogStandard item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir padrão?'),
        content: Text('Isso tira ${item.name} da biblioteca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CalibrationCatalog.instance.deleteStandard(item.id);
  }

  var _syncing = false;

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await CalibrationCatalog.instance.sync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Padrões sincronizados com a nuvem.')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  bool _matchesQuery(CatalogStandard item, String query) {
    if (query.isEmpty) return true;
    return [
      item.name,
      item.serial,
      item.certificate,
      item.type,
      item.ownerLabel,
      item.locationsLabel,
    ].join(' ').toLowerCase().contains(query);
  }

  void _setFilter(StandardCategory? category, {bool uncategorized = false}) {
    setState(() {
      _filter = category;
      _onlyUncategorized = uncategorized;
    });
  }

  Widget _filterChips(List<CatalogStandard> all) {
    int count(StandardCategory category) =>
        all.where((item) => item.categories.contains(category)).length;
    final uncategorized = all.where((item) => item.categories.isEmpty).length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('padrao-filtro-todos'),
            label: Text('Todos (${all.length})'),
            selected: _filter == null && !_onlyUncategorized,
            onSelected: (_) => _setFilter(null),
          ),
          for (final category in StandardCategory.values)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                key: Key('padrao-filtro-${category.key}'),
                label: Text('${category.label} (${count(category)})'),
                selected: _filter == category,
                onSelected: (_) => _setFilter(category),
              ),
            ),
          if (uncategorized > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                key: const Key('padrao-filtro-sem-categoria'),
                label: Text('Sem categoria ($uncategorized)'),
                selected: _onlyUncategorized,
                onSelected: (_) => _setFilter(null, uncategorized: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        '$text · $count',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: GsTheme.brass,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _card(CatalogStandard item) {
    final details = [
      item.type,
      if (item.serial.trim().isNotEmpty) 'N/S ${item.serial}',
      if (item.certificate.trim().isNotEmpty) item.certificate,
      if (item.validity.trim().isNotEmpty) item.validity,
      if (item.uncertainty.trim().isNotEmpty)
        item.uncertainty.trim().startsWith('±')
            ? item.uncertainty.trim()
            : '±${item.uncertainty.trim()}',
    ].join(' · ');
    final usage = [
      item.ownerLabel,
      if (item.locationsLabel.isNotEmpty) 'Locais: ${item.locationsLabel}',
    ].join(' · ');
    return Card(
      child: ListTile(
        title: Text(
          item.name.trim().isEmpty ? 'Padrão' : item.name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: GsTheme.navy,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details),
            const SizedBox(height: 2),
            Text(
              usage,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: item.isClientOwned
                    ? const Color(0xFF1E5AA8)
                    : const Color(0xFF8A6A1F),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            validityPill(item.validityStatus),
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(item),
            ),
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              color: const Color(0xFF8A1F1F),
              onPressed: () => _delete(item),
            ),
          ],
        ),
        onTap: () => _edit(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: const Text('Padrões de calibração'),
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
        key: const Key('padrao-novo'),
        onPressed: _edit,
        backgroundColor: GsTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo padrão'),
      ),
      body: AnimatedBuilder(
        animation: CalibrationCatalog.instance,
        builder: (context, _) {
          final all = CalibrationCatalog.instance.standards;
          final query = _search.text.trim().toLowerCase();
          final items = [
            for (final item in all)
              if (_matchesQuery(item, query)) item,
          ];
          final sections = <(String, List<CatalogStandard>)>[];
          if (_onlyUncategorized) {
            sections.add((
              'Sem categoria',
              [for (final item in items) if (item.categories.isEmpty) item],
            ));
          } else if (_filter != null) {
            sections.add((
              _filter!.label,
              [
                for (final item in items)
                  if (item.categories.contains(_filter)) item,
              ],
            ));
          } else {
            for (final category in StandardCategory.values) {
              final inCategory = [
                for (final item in items)
                  if (item.categories.contains(category)) item,
              ];
              if (inCategory.isNotEmpty) {
                sections.add((category.label, inCategory));
              }
            }
            final loose = [
              for (final item in items) if (item.categories.isEmpty) item,
            ];
            if (loose.isNotEmpty) sections.add(('Sem categoria', loose));
          }
          final shown = {
            for (final section in sections)
              for (final item in section.$2) item.id,
          }.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text(
                'Padrões cadastrados',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Validade em destaque: verde ok, laranja nos 30 dias, vermelho vencido. O sino da calibração avisa isso.',
                style: TextStyle(color: Color(0xFF5C6570), height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar padrão, cliente ou local…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              _filterChips(all),
              const SizedBox(height: 8),
              Text(
                shown == 0 ? 'Nenhum padrão aqui.' : '$shown padrão(ões)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GsTheme.navy,
                ),
              ),
              if (sections.length == 1 && sections.first.$1 == 'Sem categoria')
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Abra cada um e marque para que tipo de calibração ele serve.',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  ),
                ),
              for (final section in sections)
                if (section.$2.isNotEmpty) ...[
                  _sectionTitle(section.$1, section.$2.length),
                  for (final item in section.$2) _card(item),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _StandardEditPage extends StatefulWidget {
  const _StandardEditPage({this.existing, this.initialCategory});

  final CatalogStandard? existing;
  final StandardCategory? initialCategory;

  @override
  State<_StandardEditPage> createState() => _StandardEditPageState();
}

class _StandardEditPageState extends State<_StandardEditPage> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _type = TextEditingController(
    text: widget.existing?.type ?? 'Outro',
  );
  late final _serial = TextEditingController(text: widget.existing?.serial);
  late final _certificate = TextEditingController(
    text: widget.existing?.certificate,
  );
  late final _validity = TextEditingController(text: widget.existing?.validity);
  late final _uncertainty = TextEditingController(
    text: widget.existing?.uncertainty,
  );
  late final _coverageK = TextEditingController(
    text: widget.existing?.coverageK,
  );
  late final _ownerClient = TextEditingController(
    text: widget.existing?.ownerClientName,
  );
  late String _ownerClientId = widget.existing?.ownerClientId ?? '';
  late String _owner = widget.existing?.owner ?? standardOwnerGs;
  late final Set<StandardCategory> _categories = _initialCategories();
  late final bool _categoriesSuggested =
      widget.existing != null &&
      widget.existing!.categories.isEmpty &&
      _categories.isNotEmpty;
  late final List<TextEditingController> _locations = [
    for (final item in widget.existing?.locations ?? const <String>[])
      TextEditingController(text: item),
  ];

  Set<StandardCategory> _initialCategories() {
    final existing = widget.existing;
    if (existing == null) {
      return {if (widget.initialCategory case final category?) category};
    }
    if (existing.categories.isNotEmpty) return {...existing.categories};
    return {if (existing.suggestedCategory case final category?) category};
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _serial.dispose();
    _certificate.dispose();
    _validity.dispose();
    _uncertainty.dispose();
    _coverageK.dispose();
    _ownerClient.dispose();
    for (final item in _locations) {
      item.dispose();
    }
    super.dispose();
  }

  void _setLocationCount(int count) {
    final next = count.clamp(0, 30);
    setState(() {
      while (_locations.length < next) {
        _locations.add(TextEditingController());
      }
      while (_locations.length > next) {
        _locations.removeLast().dispose();
      }
    });
  }

  Future<void> _pickClient() async {
    await ClientStore.instance.load();
    final clients = ClientStore.instance.items;
    if (!mounted) return;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum cliente cadastrado. Digite o nome do cliente.'),
        ),
      );
      return;
    }
    final picked = await showSearchPickSheet<SavedClient>(
      context: context,
      title: 'Cliente dono do padrão',
      items: clients,
      labelOf: (item) => item.name,
      subtitleOf: (item) => [
        if (item.cnpj.trim().isNotEmpty) item.cnpj,
        if (item.city.trim().isNotEmpty)
          [item.city.trim(), item.state.trim()]
              .where((part) => part.isNotEmpty)
              .join('/'),
      ].join(' · '),
      searchOf: (item) => '${item.name} ${item.cnpj} ${item.city}',
      emptyMessage: 'Nenhum cliente com esse texto.',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _ownerClientId = picked.id;
      _ownerClient.text = picked.name;
    });
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientOwned = _owner == standardOwnerClient;
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Novo padrão' : 'Editar padrão'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            TextField(
              key: const Key('padrao-nome'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome do padrão'),
            ),
            _sectionLabel('Serve para calibração de'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in StandardCategory.values)
                  FilterChip(
                    key: Key('padrao-categoria-${category.key}'),
                    label: Text(category.label),
                    selected: _categories.contains(category),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _categories.add(category);
                      } else {
                        _categories.remove(category);
                      }
                    }),
                  ),
              ],
            ),
            if (_categoriesSuggested)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Sugestão pelo nome e pela unidade. Confira e salve.',
                  style: TextStyle(color: Color(0xFF8A6A1F)),
                ),
              ),
            _sectionLabel('De quem é o padrão'),
            SegmentedButton<String>(
              key: const Key('padrao-dono'),
              segments: const [
                ButtonSegment(
                  value: standardOwnerGs,
                  label: Text('GS Soluções'),
                  icon: Icon(Icons.business),
                ),
                ButtonSegment(
                  value: standardOwnerClient,
                  label: Text('Do cliente'),
                  icon: Icon(Icons.handshake_outlined),
                ),
              ],
              selected: {_owner},
              onSelectionChanged: (value) =>
                  setState(() => _owner = value.first),
            ),
            if (clientOwned) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('padrao-cliente'),
                controller: _ownerClient,
                onChanged: (_) => _ownerClientId = '',
                decoration: InputDecoration(
                  labelText: 'Cliente',
                  suffixIcon: IconButton(
                    tooltip: 'Escolher da lista de clientes',
                    icon: const Icon(Icons.manage_search),
                    onPressed: _pickClient,
                  ),
                ),
              ),
            ],
            _sectionLabel('Locais de utilização'),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quantidade de locais',
                    style: TextStyle(color: Color(0xFF5C6570)),
                  ),
                ),
                IconButton(
                  key: const Key('padrao-locais-menos'),
                  tooltip: 'Menos um local',
                  onPressed: _locations.isEmpty
                      ? null
                      : () => _setLocationCount(_locations.length - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${_locations.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: GsTheme.navy,
                  ),
                ),
                IconButton(
                  key: const Key('padrao-locais-mais'),
                  tooltip: 'Mais um local',
                  onPressed: () => _setLocationCount(_locations.length + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            for (var i = 0; i < _locations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  key: Key('padrao-local-$i'),
                  controller: _locations[i],
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Local ${i + 1}',
                    hintText: 'Ex.: DTC Goiânia/GO, Base Senador Canedo',
                  ),
                ),
              ),
            const Text(
              'Dono e locais não saem no certificado. Servem para escolher o padrão certo na hora de emitir.',
              style: TextStyle(color: Color(0xFF5C6570), fontSize: 13),
            ),
            _sectionLabel('Dados do padrão'),
            TextField(
              controller: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo (Coriolis, prova, bloco seco…)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serial,
              decoration: const InputDecoration(labelText: 'Nº de série'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _certificate,
              decoration: const InputDecoration(labelText: 'Certificado'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('padrao-validade'),
              controller: _validity,
              decoration: const InputDecoration(
                labelText: 'Validade (dd/mm/aaaa)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _uncertainty,
              decoration: const InputDecoration(
                labelText: 'Incerteza do padrão (ex.: 0,2 °C, 0,05%, 0,08 bar)',
                helperText:
                    'Digite com a unidade ou escolha uma das opções abaixo:',
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final u in commonUncertaintyUnits)
                    ActionChip(
                      label: Text(
                        u,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        final updated =
                            applyUncertaintyUnit(_uncertainty.text, u);
                        _uncertainty.text = updated;
                        _uncertainty.selection = TextSelection.collapsed(
                          offset: updated.length,
                        );
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _coverageK,
              decoration: const InputDecoration(
                labelText: 'Fator de abrangência (k) (opcional)',
                helperText:
                    'Fator de abrangência (k) do certificado do padrão. Se vazio, usa 2.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('padrao-salvar'),
              onPressed: () {
                final base = widget.existing ??
                    CatalogStandard(id: newCatalogId());
                Navigator.pop(
                  context,
                  base.copyWith(
                    name: _name.text.trim(),
                    type: _type.text.trim().isEmpty ? 'Outro' : _type.text.trim(),
                    serial: _serial.text.trim(),
                    certificate: _certificate.text.trim(),
                    validity: _validity.text.trim(),
                    uncertainty: _uncertainty.text.trim(),
                    coverageK: _coverageK.text.trim(),
                    categories: [
                      for (final category in StandardCategory.values)
                        if (_categories.contains(category)) category,
                    ],
                    owner: _owner,
                    ownerClientId: clientOwned ? _ownerClientId : '',
                    ownerClientName:
                        clientOwned ? _ownerClient.text.trim() : '',
                    locations: [
                      for (final item in _locations)
                        if (item.text.trim().isNotEmpty) item.text.trim(),
                    ],
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
