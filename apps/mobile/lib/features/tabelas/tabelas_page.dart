import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/rdo_share.dart';
import 'package:gs_mobile/data/tabelas20.dart';
import 'package:gs_mobile/data/tabelas_alcool.dart';
import 'package:gs_mobile/data/tabelas_pdf.dart';
import 'package:gs_mobile/demo/auth.dart';
import 'package:gs_mobile/web/pwa_install.dart'
    if (dart.library.js_interop) 'package:gs_mobile/web/pwa_install_web.dart';
import 'package:gs_mobile/web/pwa_install_banner.dart';
import 'package:intl/intl.dart';

enum _TabelaId { derivados, alcool }

class TabelasPage extends StatefulWidget {
  const TabelasPage({super.key});

  @override
  State<TabelasPage> createState() => _TabelasPageState();
}

class _TabelasPageState extends State<TabelasPage> {
  var _tab = _TabelaId.derivados;

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.user;
    return Scaffold(
      backgroundColor: GsTheme.paper,
      appBar: AppBar(
        title: const Text('Tabelas 20 °C'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'instalar') {
                showPwaInstallHelp(context);
                return;
              }
              if (value == 'sair') AuthSession.instance.signOut();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(user?.name ?? 'Técnico'),
              ),
              if (PwaInstall.shouldOffer)
                const PopupMenuItem(
                  value: 'instalar',
                  child: Text('Instalar no celular'),
                ),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: ListView(
        key: const Key('tabelas-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'Correção volumétrica da GS — derivados de petróleo e álcool. O técnico consulta e calcula a 20 °C no campo.',
            style: TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 16),
          _TablePick(
            selected: _tab == _TabelaId.derivados,
            standard: 'ASTM / tabela GS · 20 °C',
            title: 'Conversão de derivados de petróleo',
            description:
                'Densidade e volume corrigidos a 20 °C, fator CTL, peso e perda/sobra contra o volume a 20 do objeto.',
            onTap: () => setState(() => _tab = _TabelaId.derivados),
          ),
          const SizedBox(height: 10),
          _TablePick(
            selected: _tab == _TabelaId.alcool,
            standard: 'NBR 5992 · misturas etanol-água',
            title: 'Correção a 20 °C — álcool',
            description:
                'Densidade e volume corrigidos a 20 °C, fator CTL, peso e perda/sobra contra o volume a 20 do objeto.',
            onTap: () => setState(() => _tab = _TabelaId.alcool),
          ),
          const SizedBox(height: 20),
          IndexedStack(
            index: _tab == _TabelaId.derivados ? 0 : 1,
            sizing: StackFit.loose,
            children: const [
              _TabelaCalcPanel(
                key: ValueKey('tabela-derivados'),
                spec: _TabelaSpec.derivados,
              ),
              _TabelaCalcPanel(
                key: ValueKey('tabela-alcool'),
                spec: _TabelaSpec.alcool,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabelaSpec {
  const _TabelaSpec({
    required this.kind,
    required this.kindLabel,
    required this.standard,
    required this.panelTitle,
    required this.density,
    required this.temperature,
    required this.volume,
    required this.tempCt,
    required this.volumeObjeto,
  });

  final String kind;
  final String kindLabel;
  final String standard;
  final String panelTitle;
  final String density;
  final String temperature;
  final String volume;
  final String tempCt;
  final String volumeObjeto;

  static const derivados = _TabelaSpec(
    kind: 'derivados',
    kindLabel: 'Derivados de petróleo',
    standard: 'ASTM / tabela GS · 20 °C',
    panelTitle: 'Amostra',
    density: '723',
    temperature: '25',
    volume: '10000',
    tempCt: '25',
    volumeObjeto: '9940',
  );

  static const alcool = _TabelaSpec(
    kind: 'alcool',
    kindLabel: 'Álcool',
    standard: 'NBR 5992 · misturas etanol-água',
    panelTitle: 'Misturas etanol-água',
    density: '800',
    temperature: '29,45',
    volume: '10000',
    tempCt: '29,45',
    volumeObjeto: '9900',
  );
}

class _TablePick extends StatelessWidget {
  const _TablePick({
    required this.selected,
    required this.standard,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final String standard;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? GsTheme.brass : const Color(0x331A2330),
                width: selected ? 5 : 1,
              ),
              top: const BorderSide(color: Color(0x331A2330)),
              right: const BorderSide(color: Color(0x331A2330)),
              bottom: const BorderSide(color: Color(0x331A2330)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                standard,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: GsTheme.brass,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: GsTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: Color(0xFF5C6570),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabelaCalcPanel extends StatefulWidget {
  const _TabelaCalcPanel({super.key, required this.spec});

  final _TabelaSpec spec;

  @override
  State<_TabelaCalcPanel> createState() => _TabelaCalcPanelState();
}

class _TabelaCalcPanelState extends State<_TabelaCalcPanel> {
  late final TextEditingController _product;
  late final TextEditingController _system;
  late final TextEditingController _density;
  late final TextEditingController _temperature;
  late final TextEditingController _volume;
  late final TextEditingController _tempCt;
  late final TextEditingController _volumeObjeto;
  var _date = DateTime.now();
  var _saving = false;
  var _showVariancePercent = true;

  @override
  void initState() {
    super.initState();
    final spec = widget.spec;
    _product = TextEditingController();
    _system = TextEditingController();
    _density = TextEditingController(text: spec.density);
    _temperature = TextEditingController(text: spec.temperature);
    _volume = TextEditingController(text: spec.volume);
    _tempCt = TextEditingController(text: spec.tempCt);
    _volumeObjeto = TextEditingController(text: spec.volumeObjeto);
  }

  @override
  void dispose() {
    _product.dispose();
    _system.dispose();
    _density.dispose();
    _temperature.dispose();
    _volume.dispose();
    _tempCt.dispose();
    _volumeObjeto.dispose();
    super.dispose();
  }

  bool _looksLikeAlcoholSample() {
    if (widget.spec.kind != 'derivados') return false;
    final density = parsePtNumber(_density.text);
    if (density == null) return false;
    return density >= 770 && density <= 830;
  }

  DerivadosResult? get _result {
    final d = parsePtNumber(_density.text);
    final t = parsePtNumber(_temperature.text);
    final v = parsePtNumber(_volume.text);
    final tc = parsePtNumber(_tempCt.text);
    final objeto = parsePtNumber(_volumeObjeto.text);
    if ([d, t, v, tc].contains(null)) return null;
    if (widget.spec.kind == 'alcool') {
      return convertAlcool(
        densityAmbient: d!,
        temperature: t!,
        volumeAmbient: v!,
        temperatureCt: tc!,
        volumeDanfe: objeto,
      );
    }
    return convertDerivados(
      densityAmbient: d!,
      temperature: t!,
      volumeAmbient: v!,
      temperatureCt: tc!,
      volumeDanfe: objeto,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: GsTheme.navy,
        content: Text(message, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _savePdf() async {
    final result = _result;
    if (result == null) {
      _toast('Preencha os campos numéricos da amostra.');
      return;
    }
    setState(() => _saving = true);
    try {
      final spec = widget.spec;
      final bytes = await buildTabela20Pdf(
        Tabela20PdfData(
          kindLabel: spec.kindLabel,
          standard: spec.standard,
          date: _date,
          productName: _product.text,
          systemNumber: _system.text,
          technicianName: AuthSession.instance.user?.name ?? '',
          densityAmbient: _density.text,
          temperatureSample: _temperature.text,
          volumeAmbient: _volume.text,
          temperatureCt: _tempCt.text,
          volumeObjeto: _volumeObjeto.text,
          result: result,
          showVariancePercent: _showVariancePercent,
        ),
      );
      final fileName = tabela20FileName(
        kind: spec.kind,
        date: _date,
        product: _product.text,
        system: _system.text,
      );
      await downloadRdoFile(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      _toast('PDF salvo: $fileName');
    } catch (error) {
      if (!mounted) return;
      _toast('Não foi possível salvar o PDF. $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final result = _result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelTitle(spec.panelTitle),
        if (spec.kind == 'alcool') ...[
          const Text(
            'NBR 5992 · correção a 20 °C',
            style: TextStyle(fontSize: 14, color: Color(0xFF5C6570)),
          ),
          const SizedBox(height: 12),
        ],
        _DateField(date: _date, onTap: _pickDate),
        _TextField(
          controller: _product,
          label: 'Nome do produto',
        ),
        _TextField(
          controller: _system,
          label: 'Número do sistema',
        ),
        if (spec.kind == 'derivados' && _looksLikeAlcoholSample())
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Densidade típica de etanol anidro ou hidratado. Para NBR 5992, '
              'use a aba Correção a 20 °C — álcool.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        _NumField(
          key: spec.kind == 'derivados' ? const Key('tab-densidade') : null,
          controller: _density,
          label: 'Densidade da amostra (kg/m³)',
          onChanged: (_) => setState(() {}),
        ),
        _NumField(
          controller: _temperature,
          label: 'Temperatura da amostra (°C)',
          onChanged: (_) => setState(() {}),
        ),
        _NumField(
          controller: _volume,
          label: 'Volume ambiente (L)',
          onChanged: (_) => setState(() {}),
        ),
        _NumField(
          controller: _tempCt,
          label: 'Temperatura do CT (°C)',
          onChanged: (_) => setState(() {}),
        ),
        _NumField(
          controller: _volumeObjeto,
          label: 'Volume a 20 do objeto (L20)',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Mostrar erro da comparação em %',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: GsTheme.navy,
            ),
          ),
          subtitle: const Text(
            'Exibe perda e sobra em percentual além dos litros.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5C6570)),
          ),
          value: _showVariancePercent,
          activeThumbColor: GsTheme.navy,
          onChanged: (value) => setState(() => _showVariancePercent = value),
        ),
        const SizedBox(height: 8),
        const _PanelTitle('Resultado a 20 °C'),
        if (result == null)
          const Text(
            'Preencha os campos numéricos da amostra.',
            style: TextStyle(color: Color(0xFF5C6570)),
          )
        else
          _ResultBox(
            rows: [
              if (spec.kind == 'alcool')
                (
                  'Grau INPM do álcool',
                  result.inpm == null
                      ? '—'
                      : '${formatPt(result.inpm!, 2)} % massa',
                ),
              ('Densidade a 20 °C', '${formatPt(result.density20, 3)} kg/m³'),
              ('Fator de correção (CTL)', formatPt(result.ctl, 4)),
              (
                'Volume a 20 °C',
                '${formatPt(result.volume20, spec.kind == 'alcool' ? 0 : 2)} L20',
              ),
              ('Peso', '${formatPt(result.weight, 3)} kg'),
              if (result.variance != null)
                (
                  'Perda & sobra',
                  formatVarianceDisplay(
                    variance: result.variance!,
                    variancePercent: result.variancePercent,
                    showPercent: _showVariancePercent,
                    litDigits: spec.kind == 'alcool' ? 0 : 2,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('tabelas-salvar-pdf'),
          onPressed: result == null || _saving ? null : _savePdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          style: FilledButton.styleFrom(backgroundColor: GsTheme.navy),
          label: Text(_saving ? 'Gerando PDF…' : 'Salvar em PDF'),
        ),
        const SizedBox(height: 12),
        Text(
          spec.kind == 'alcool'
              ? 'Cálculo NBR 5992 com tabela INPM da GS (misturas etanol-água).'
              : 'Cálculo com tabelas DNS_20 e FCV_20 da planilha GS (ASTM 1520/2004).',
          style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF5C6570)),
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: GsTheme.navy,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Data',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            DateFormat('dd/MM/yyyy').format(date),
            style: const TextStyle(fontSize: 16, color: GsTheme.ink),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-]')),
        ],
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  const _ResultBox({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5C6570),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: GsTheme.navy,
                      ),
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
