import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/client_excel.dart';
import 'package:gs_mobile/data/client_store.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/features/clients/client_system_sheet.dart';
import 'package:http/http.dart' as http;

const _ufs = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
];

class ClientEditPage extends StatefulWidget {
  const ClientEditPage({super.key, this.existing});

  final SavedClient? existing;

  @override
  State<ClientEditPage> createState() => _ClientEditPageState();
}

class _BaseContactEditors {
  _BaseContactEditors({
    String name = '',
    String cargo = '',
    String email = '',
    String phone = '',
  }) : name = TextEditingController(text: name),
       cargo = TextEditingController(text: cargo),
       email = TextEditingController(text: email),
       phone = TextEditingController(text: phone);

  factory _BaseContactEditors.from(ClientBaseContact contact) {
    return _BaseContactEditors(
      name: contact.name,
      cargo: contact.cargo,
      email: contact.email,
      phone: contact.phone,
    );
  }

  final TextEditingController name;
  final TextEditingController cargo;
  final TextEditingController email;
  final TextEditingController phone;

  ClientBaseContact toContact() => ClientBaseContact(
    name: name.text.trim(),
    cargo: cargo.text.trim(),
    email: email.text.trim(),
    phone: phone.text.trim(),
  );

  void dispose() {
    name.dispose();
    cargo.dispose();
    email.dispose();
    phone.dispose();
  }
}

class _ClientEditPageState extends State<ClientEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _requester;
  late final TextEditingController _cnpj;
  late final TextEditingController _cep;
  late final TextEditingController _street;
  late final TextEditingController _number;
  late final TextEditingController _complement;
  late final TextEditingController _neighborhood;
  late final TextEditingController _city;
  late final List<_BaseContactEditors> _basePeople;
  late List<ClientSystem> _systems;

  /// Cadastro como estava ao abrir (ou na última gravação desta tela).
  SavedClient? _base;
  var _state = '';
  var _busy = false;
  var _lookupCep = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _requester = TextEditingController(text: existing?.requester ?? '');
    _cnpj = TextEditingController(text: existing?.cnpj ?? '');
    _cep = TextEditingController(text: existing?.cep ?? '');
    _street = TextEditingController(text: existing?.street ?? '');
    _number = TextEditingController(text: existing?.number ?? '');
    _complement = TextEditingController(text: existing?.complement ?? '');
    _neighborhood = TextEditingController(text: existing?.neighborhood ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    final people =
        existing?.resolvedBaseContacts ?? const <ClientBaseContact>[];
    _basePeople = [
      for (final person in people) _BaseContactEditors.from(person),
    ];
    if (_basePeople.isEmpty) {
      _basePeople.add(_BaseContactEditors());
    }
    _systems = [...?existing?.resolvedSystems];
    _state = (existing?.state ?? '').toUpperCase();
    _base = existing;
  }

  @override
  void dispose() {
    _name.dispose();
    _requester.dispose();
    _cnpj.dispose();
    _cep.dispose();
    _street.dispose();
    _number.dispose();
    _complement.dispose();
    _neighborhood.dispose();
    _city.dispose();
    for (final person in _basePeople) {
      person.dispose();
    }
    super.dispose();
  }

  List<ClientBaseContact> _baseContactsDraft() => [
    for (final person in _basePeople)
      if (person.toContact().hasName) person.toContact(),
  ].take(3).toList();

  SavedClient _draft({String? id}) {
    final contacts = _baseContactsDraft();
    final primary = contacts.isEmpty ? null : contacts.first;
    return SavedClient(
      id:
          id ??
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text,
      requester: _requester.text,
      cnpj: _cnpj.text,
      cep: _cep.text,
      street: _street.text,
      number: _number.text,
      complement: _complement.text,
      neighborhood: _neighborhood.text,
      city: _city.text,
      state: _state,
      sites: widget.existing?.sites ?? const [],
      service: widget.existing?.service ?? '',
      systemType: widget.existing?.systemType ?? '',
      baseName: primary?.name ?? '',
      baseCargo: primary?.cargo ?? '',
      baseEmail: primary?.email ?? '',
      basePhone: primary?.phone ?? '',
      baseContacts: contacts,
      systems: _systems,
      equipment: flattenClientSystems(_systems),
      updatedAt: DateTime.now(),
    );
  }

  void _addBasePerson() {
    if (_basePeople.length >= 3) return;
    setState(() => _basePeople.add(_BaseContactEditors()));
  }

  void _removeBasePerson(int index) {
    if (_basePeople.length <= 1) {
      setState(() {
        _basePeople[0].name.clear();
        _basePeople[0].cargo.clear();
        _basePeople[0].email.clear();
        _basePeople[0].phone.clear();
      });
      return;
    }
    setState(() {
      _basePeople.removeAt(index).dispose();
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _searchCep() async {
    final digits = _cep.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 8) {
      _toast('CEP precisa ter 8 dígitos.');
      return;
    }
    setState(() => _lookupCep = true);
    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$digits/json/'),
      );
      if (response.statusCode != 200) {
        _toast('Não deu para buscar o CEP agora.');
        return;
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['erro'] == true) {
        _toast('CEP não encontrado.');
        return;
      }
      setState(() {
        if ('${data['logradouro']}'.trim().isNotEmpty) {
          _street.text = '${data['logradouro']}'.trim();
        }
        if ('${data['bairro']}'.trim().isNotEmpty) {
          _neighborhood.text = '${data['bairro']}'.trim();
        }
        if ('${data['localidade']}'.trim().isNotEmpty) {
          _city.text = '${data['localidade']}'.trim();
        }
        final uf = '${data['uf']}'.trim().toUpperCase();
        if (_ufs.contains(uf)) _state = uf;
      });
    } catch (_) {
      _toast('Não deu para buscar o CEP agora.');
    } finally {
      if (mounted) setState(() => _lookupCep = false);
    }
  }

  Future<void> _editSystem({
    ClientSystem? current,
    ClientSystem? template,
  }) async {
    final result = await Navigator.of(context).push<ClientSystem>(
      MaterialPageRoute(
        builder: (context) =>
            ClientSystemSheet(existing: current, systemTemplate: template),
      ),
    );
    if (result == null) return;
    setState(() {
      if (current == null) {
        _systems = [..._systems, result];
        return;
      }
      _systems = [
        for (final item in _systems)
          if (item.id == current.id) result else item,
      ];
    });
  }

  Future<void> _downloadTemplate() async {
    setState(() => _busy = true);
    try {
      await ClientStore.instance.sync();
      if (!mounted) return;
      final draft = _draft();
      final fromStore =
          ClientStore.instance.byId(draft.id) ??
          ClientStore.instance.findMatch(cnpj: draft.cnpj, name: draft.name);
      final systems = _systems.isNotEmpty
          ? _systems
          : (fromStore?.resolvedSystems ?? const <ClientSystem>[]);
      final client = SavedClient(
        id: fromStore?.id ?? draft.id,
        name: draft.name.trim().isNotEmpty
            ? draft.name
            : (fromStore?.name ?? ''),
        requester: draft.requester.trim().isNotEmpty
            ? draft.requester
            : (fromStore?.requester ?? ''),
        cnpj: draft.cnpj.trim().isNotEmpty
            ? draft.cnpj
            : (fromStore?.cnpj ?? ''),
        sites: draft.sites.isNotEmpty
            ? draft.sites
            : (fromStore?.sites ?? const []),
        cep: draft.cep.trim().isNotEmpty ? draft.cep : (fromStore?.cep ?? ''),
        street: draft.street.trim().isNotEmpty
            ? draft.street
            : (fromStore?.street ?? ''),
        number: draft.number.trim().isNotEmpty
            ? draft.number
            : (fromStore?.number ?? ''),
        complement: draft.complement.trim().isNotEmpty
            ? draft.complement
            : (fromStore?.complement ?? ''),
        neighborhood: draft.neighborhood.trim().isNotEmpty
            ? draft.neighborhood
            : (fromStore?.neighborhood ?? ''),
        city: draft.city.trim().isNotEmpty
            ? draft.city
            : (fromStore?.city ?? ''),
        state: draft.state.trim().isNotEmpty
            ? draft.state
            : (fromStore?.state ?? ''),
        service: draft.service,
        systemType: draft.systemType,
        baseName: draft.baseName.trim().isNotEmpty
            ? draft.baseName
            : (fromStore?.baseName ?? ''),
        baseCargo: draft.baseCargo.trim().isNotEmpty
            ? draft.baseCargo
            : (fromStore?.baseCargo ?? ''),
        baseEmail: draft.baseEmail.trim().isNotEmpty
            ? draft.baseEmail
            : (fromStore?.baseEmail ?? ''),
        basePhone: draft.basePhone.trim().isNotEmpty
            ? draft.basePhone
            : (fromStore?.basePhone ?? ''),
        baseContacts: draft.resolvedBaseContacts.isNotEmpty
            ? draft.resolvedBaseContacts
            : (fromStore?.resolvedBaseContacts ?? const []),
        systems: systems,
        equipment: systems.isNotEmpty
            ? flattenClientSystems(systems)
            : (fromStore?.storedEquipment.isNotEmpty == true
                  ? fromStore!.storedEquipment
                  : fromStore?.equipment ?? const []),
        updatedAt: DateTime.now(),
      );
      if (client.name.trim().isEmpty && client.cnpj.trim().isEmpty) {
        _toast('Informe o contratante ou o CNPJ antes de baixar.');
        return;
      }
      final bytes = buildClientExcelTemplate(
        clients: [client],
        withExample: false,
      );
      final safeName = client.name
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = safeName.isEmpty
          ? clientExcelFileName
          : 'GS_Calibracao_${safeName.length > 40 ? safeName.substring(0, 40) : safeName}.xlsx';
      await downloadRdoFile(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      final n = client.equipment.length;
      _toast(
        n == 0
            ? 'Planilha deste cliente baixada (ainda sem instrumentos).'
            : 'Planilha baixada: $n instrumento(s) deste cliente.',
      );
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSheet() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xlsm', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast('Não deu para ler a planilha.');
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await ClientStore.instance.saveEdited(
        _draft(),
        base: _base,
      );
      final result = await importClientWorkbook(bytes, onlyClient: saved);
      final fresh = ClientStore.instance.byId(saved.id) ?? saved;
      if (!mounted) return;
      setState(() {
        _base = fresh;
        _name.text = fresh.name;
        _requester.text = fresh.requester;
        _cnpj.text = fresh.cnpj;
        _cep.text = fresh.cep;
        _street.text = fresh.street;
        _number.text = fresh.number;
        _complement.text = fresh.complement;
        _neighborhood.text = fresh.neighborhood;
        _city.text = fresh.city;
        _state = fresh.state.toUpperCase();
        _systems = [...fresh.resolvedSystems];
        _busy = false;
      });
      _toast(result.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('$error');
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ClientStore.instance.saveEdited(_draft(), base: _base);
      if (!mounted) return;
      _toast('Cliente salvo.');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('$error');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(
          'Isso tira ${existing.name} da lista. As OS já geradas continuam.',
        ),
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
    if (confirmed != true) return;
    await ClientStore.instance.delete(existing.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Novo cliente' : 'Editar cliente',
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Excluir',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const Text(
            'Cadastro da empresa: endereço e responsável da base. Serviço, tipo e local do serviço você preenche na OS.',
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Color(0xFF5C6570),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('client-requester'),
            controller: _requester,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Solicitante do serviço (opcional)',
              helperText: 'Ex.: TESCAN, nome fantasia da empresa solicitante.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('client-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Cliente / Contratante (Razão Social)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('client-cnpj'),
            controller: _cnpj,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'CNPJ'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Endereço'),
          const SizedBox(height: 8),
          TextField(
            controller: _cep,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'CEP',
              suffixIcon: IconButton(
                tooltip: 'Buscar CEP',
                onPressed: _lookupCep ? null : _searchCep,
                icon: _lookupCep
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _street,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Endereço'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: const InputDecoration(labelText: 'Nº'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _complement,
                  decoration: const InputDecoration(labelText: 'Complemento'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _neighborhood,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Bairro'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Cidade'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(_state),
            initialValue: _ufs.contains(_state) ? _state : null,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              for (final uf in _ufs)
                DropdownMenuItem(value: uf, child: Text(uf)),
            ],
            onChanged: (value) => setState(() => _state = value ?? ''),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Sistemas e instrumentos'),
          const SizedBox(height: 6),
          const Text(
            'Cadastre o sistema (tipo, local e tag). Depois inclua preset, transmissor, os dois, PT100, densímetro ou malha. No preset (e no Coriolis) informe as quantidades; cada PT100 traz a malha correspondente. O produto de cada medidor sai da lista de produtos cadastrados.',
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: Color(0xFF5C6570),
            ),
          ),
          if (AuthSession.instance.user?.canUseClientExcel == true) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _downloadTemplate,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Baixar Excel deste cliente'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _importSheet,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Importar Excel deste cliente'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_systems.isEmpty)
            const Text(
              'Nenhum sistema neste cliente ainda.',
              style: TextStyle(color: Color(0xFF5C6570)),
            )
          else
            for (final group in groupClientSystems(_systems))
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(group.title),
                        subtitle: Text(group.subtitle),
                      ),
                      for (final item in group.assemblies)
                        ListTile(
                          title: Text(item.assemblyTitle),
                          subtitle: Text(
                            item.assemblySubtitle.isEmpty
                                ? item.subtitle
                                : item.assemblySubtitle,
                          ),
                          trailing: IconButton(
                            tooltip: 'Excluir',
                            onPressed: () {
                              setState(() {
                                _systems = [
                                  for (final current in _systems)
                                    if (current.id != item.id) current,
                                ];
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                          onTap: () => _editSystem(current: item),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: OutlinedButton.icon(
                          key: Key(
                            'incluir-preset-${group.assemblies.first.id}',
                          ),
                          onPressed: () =>
                              _editSystem(template: group.assemblies.first),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Incluir equipamento neste sistema',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          OutlinedButton.icon(
            key: const Key('incluir-sistema'),
            onPressed: () => _editSystem(),
            icon: const Icon(Icons.add),
            label: const Text('Incluir sistema'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Responsáveis da base (assinam o RDO)'),
          const SizedBox(height: 6),
          const Text(
            'Cadastre de 1 a 3 pessoas. No RDO o técnico escolhe quem assina, igual à seleção de técnicos.',
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: Color(0xFF5C6570),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _basePeople.length; i++) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Responsável ${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: GsTheme.navy,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => _removeBasePerson(i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _basePeople[i].name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _basePeople[i].cargo,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Cargo'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _basePeople[i].email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _basePeople[i].phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_basePeople.length < 3)
            OutlinedButton.icon(
              onPressed: _addBasePerson,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Incluir outro responsável'),
            ),
          const SizedBox(height: 28),
          FilledButton(
            key: const Key('save-client'),
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: GsTheme.brass,
              foregroundColor: Colors.black,
            ),
            child: Text(_busy ? 'Aguarde…' : 'Salvar cliente'),
          ),
        ],
      ),
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
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: GsTheme.navy,
      ),
    );
  }
}
