import 'dart:typed_data';

import 'package:gs_mobile/data/gs_brand_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _scope =
    'Serviço de Calibração Volumétrica, Calibração de Densidade e Temperatura '
    'dos Instrumentos do Sistema de Carregamento;';

const _aboutCompany =
    'A GS SOLUÇÕES foi criada com o propósito de atender as principais áreas '
    'da indústria, com a experiência adquirida pelo profissional atuante há '
    'mais de 15 anos na área de Óleo e Gás, com opções inovadoras de '
    'equipamentos e serviços de alta qualidade, sempre com foco para obter '
    'os melhores resultados em seu processo e atender suas demandas, '
    'Agregando valores e conhecimentos, visando o contínuo aprimoramento '
    'em nossos serviços.';

const _mission =
    'Prover serviços de alta qualidade, com foco na otimização de processos '
    'e na geração de resultados positivos para nossos clientes, através de '
    'soluções personalizadas e um atendimento diferenciado.';

const _vision =
    'Alcançar a satisfação total dos clientes, oferecendo soluções '
    'personalizadas e de alta qualidade.';

const _qualityPolicy =
    'Comprometemo-nos a fornecer serviços que superem as expectativas de '
    'nossos clientes, buscando a excelência em cada interação, além de '
    'incentivamos a participação de todos os colaboradores na busca pela '
    'melhoria contínua dos processos e serviços. Atendemos aos requisitos '
    'legais e normativos aplicáveis, garantindo a qualidade e a segurança '
    'em todas as etapas do serviço. Valorizamos o feedback dos nossos '
    'clientes e utilizamos suas sugestões para aprimorar continuamente '
    'nossos serviços.';

const _objectives = [
  'Realizar o serviço de calibração com qualidade e segurança;',
  'Trazer solução de forma rápida, objetiva e duradoura;',
  'Contribuir com a melhora de Performance do cliente;',
  'Identificar os principais problemas na linha de produção.',
  'Trazer solução de forma rápida, objetiva e duradoura;',
];

const _volumetricMethod =
    'A Calibração dos 36 medidores da PLECT (Plataforma de Enchimento de '
    'Caminhões Tanque), será realizada utilizando o método de comparação com '
    'o Master Meter fornecido pela GS SOLUÇÕES;';

const _temperatureMethod =
    'A calibração dos sensores de temperatura dos 36 PT100 do sistema de '
    'carregamento, será realizada com a utilização de um forno de calibração '
    'do tipo Bloco; Será realizada a calibração das malhas de temperatura '
    'dos 36 PT100;';

const _densityMethod =
    'A Calibração da densidade do medidor instalado no sistema de carregamento '
    '(Medidor Coriolis), será realizada com o método de comparação com o '
    'Master Meter fornecido pela GS SOLUÇÕES;';

const _criteriaVolumetric =
    'Em 2 repetições de cada vazão com erro de até 0,05% ou conforme manual '
    'do equipamento. Em caso de não conformidade do equipamento será '
    'informada ao responsável da base e emitido o certificado de calibração '
    'de não conformidade;';

const _criteriaDensity =
    'O erro máximo admissível na calibração da densidade para medidores '
    'Coriolis é de até 1,0 kg/m³;';

const _criteriaTemperature =
    'O erro máximo admissível na calibração de um sensor PT100 segue os '
    'limites de tolerância definidos pela norma internacional IEC 60751, '
    'Classe B de até 0,30ºC.';

const _clientTruck =
    'Responsabilidade do TEMAPE. Será necessário um CT compartimentado a '
    'disposição durante toda a calibração;';

const _contractorConnections = 'Responsabilidade da empresa contratada;';

const _documents = [
  'Certificado Acreditado dos Padrões a serem utilizados;',
  'Certificado Rastreado das calibrações dos sensores de temperatura com a '
      'utilização do bloco seco e master meter da GS SOLUÇÕES;',
  'Certificado Rastreado dos medidores com a utilização do Master Meter da '
      'GS SOLUÇÕES;',
];

const _norma =
    'Serviço de Calibração volumétrica, com base na portaria do Inmetro de '
    'Nº 291, de 07 de julho de 2021;';

const _deliveryNote =
    'O certificado da calibração será entregue em até 15 dias úteis após a '
    'conclusão do serviço;';

const _conclusion1 =
    'Esperamos ansiosamente trabalhar com a TEMAPE e apoiar seus esforços de '
    'aprimoramento da automação e controle de processos. Acreditamos ser '
    'possível enfrentar os desafios futuros e estar prontos para trabalhar em '
    'parceria com você para oferecer uma solução eficaz de suporte de '
    'assistência técnica.';

const _conclusion2 =
    'Aproveito a oportunidade para me colocar a sua disposição para quaisquer '
    'esclarecimentos adicionais que se fizerem necessários, subscrevemo-nos.';

class _Bico {
  const _Bico(this.label, this.rows);
  final String label;
  final List<(String, String)> rows;
}

class _Platform {
  const _Platform(this.title, this.bicos);
  final String title;
  final List<_Bico> bicos;
}

const _platforms = [
  _Platform('PLATAFORMA 01', [
    _Bico('01 — GASOLINA / ANIDRO', [
      ('GA A', '300 / 800 / 1.200 / 1.300 / 2000'),
      ('AEAC A', '300 / 700 / 1.200 / 2.000'),
    ]),
    _Bico('02 — HIDRATADO', [
      ('HIDRATADO', '300 / 1.200 / 2.000'),
    ]),
    _Bico('03 — DIESEL S500', [
      ('S500 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('04 — DIESEL S10', [
      ('S10 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('05 — GASOLINA C', [
      ('GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
  ]),
  _Platform('PLATAFORMA 02', [
    _Bico('01 — GASOLINA C', [
      ('- GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
    _Bico('02 — HIDRATADO', [
      ('HIDRATADO', '300 / 1.200 / 2.000'),
    ]),
    _Bico('03 — DIESEL S500', [
      ('S500 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('04 — DIESEL S10', [
      ('S10 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('05 — GASOLINA C', [
      ('GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
  ]),
  _Platform('PLATAFORMA 03', [
    _Bico('01 — GASOLINA C', [
      ('GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
    _Bico('02 — HIDRATADO', [
      ('HIDRATADO', '300 / 1.200 / 2.000'),
    ]),
    _Bico('03 — DIESEL S500', [
      ('S500 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('04 — DIESEL S10', [
      ('S10 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('05 — GASOLINA C', [
      ('GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
  ]),
  _Platform('PLATAFORMA 04', [
    _Bico('01 — GASOLINA C', [
      ('GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
    _Bico('02 — HIDRATADO', [
      ('HIDRATADO', '300 / 1.200 / 2.000'),
    ]),
    _Bico('03 — DIESEL S500', [
      ('S500', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('04 — DIESEL S10', [
      ('S10 A', '300 / 1.200 / 1.700 / 2000'),
      ('B100 A', '300'),
    ]),
    _Bico('05 — GASOLINA C', [
      ('- GA A', '300 / 800 / 1.200 / 1.300 / 2.000'),
      ('AEAC A', '300 / 1.200 / 700 / 2.000'),
    ]),
  ]),
];

Future<Uint8List> buildTechnicalProposal() async {
  await loadGsBrandPdf();
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: 16,
      pageTheme: gsProposalTheme(),
      header: gsProposalHeader,
      footer: (context) => gsDocFooter(context, includeTotal: true),
      build: (_) => [
        ..._clientAndScopePage(),
        pw.NewPage(),
        _platformBlock(_platforms[0]),
        pw.SizedBox(height: 10),
        _platformBlock(_platforms[1]),
        pw.NewPage(),
        _platformBlock(_platforms[2]),
        pw.SizedBox(height: 10),
        _platformBlock(_platforms[3]),
        pw.NewPage(),
        ..._additionalPage(),
        pw.NewPage(),
        ..._scheduleInvestmentPage(),
        pw.NewPage(),
        ..._conclusionPage(),
      ],
    ),
  );
  return Uint8List.fromList(await doc.save());
}

/// Capa + apresentação da empresa, para o book enviado ao cliente
/// junto com os certificados. Não entra no PDF do ensaio.
Future<Uint8List> buildGsClientBookFront() async {
  await loadGsBrandPdf();
  final doc = pw.Document();
  gsAddCoverPage(
    doc,
    title: 'PROPOSTA',
    title2: 'TÉCNICA',
    accent: 'COMERCIAL',
    subtitle: 'Empresa Especializada',
    clientName: 'BABET – Base de Betim',
    date: '24 de Agosto de 2026',
  );
  doc.addPage(
    pw.MultiPage(
      maxPages: 4,
      pageTheme: gsCertificateTheme(),
      header: (_) => gsDocHeader(),
      footer: (context) => gsDocFooter(context, includeTotal: true),
      build: (_) => _companyPage(),
    ),
  );
  return Uint8List.fromList(await doc.save());
}

List<pw.Widget> _companyPage() {
  return [
    gsSectionTitle('Dados da Empresa'),
    gsTwoColPairs(const [
      ('Razão Social', 'GS SOLUÇÕES LTDA'),
      ('Optante pelo Simples Nacional', 'Sim'),
      ('Nome Fantasia', 'GS SOLUÇÕES'),
      ('CNPJ', '64.949.495/0001-82'),
      ('Insc. Estadual', '75.107.007-6'),
      ('Insc. Municipal', '5275155'),
      ('Endereço', 'AV. GENMO DEODORO, 1893'),
      ('Bairro', 'CREMAÇÃO'),
      ('Cidade', 'BELÉM'),
      ('UF', 'PA'),
      ('Telefone', '21 9.95788574'),
      ('CEP', '66.040-140'),
      ('E-mail', 'cleber@gssolucoestec.com.br'),
    ]),
    gsAboutBlockCustom(_aboutCompany),
    gsSectionTitle('Objetivo'),
    gsGoldList(_objectives),
    gsStatementBlock('Missão', _mission),
    gsStatementBlock('Visão', _vision),
    gsStatementBlock('Política de Qualidade', _qualityPolicy),
    gsSectionTitle('Dados Bancários'),
    gsTwoColPairs(const [
      ('Banco', 'Santander'),
      ('Código', '33'),
      ('Conta Corrente', '13.001251-2'),
      ('Agência', '2106'),
      ('Pix', '64.949.495/0001-82'),
    ]),
  ];
}

List<pw.Widget> _clientAndScopePage() {
  return [
    gsSectionTitle('Dados do Cliente'),
    gsWithCompany('BABET – Base de Betim'),
    gsTwoColPairs(const [
      ('Contratante', 'BABET – Base de Betim'),
      ('CNPJ', '34.274.233/0025-71'),
      (
        'Endereço',
        'Rodovia BR-381, KM 427,5, Distrito Industrial - Jardim Piemont Norte –Betim/MG',
      ),
      ('E-mail', 'sourcing@vibraenergia.coupahost.com'),
    ]),
    gsSectionTitle('Descrição do Serviço'),
    gsSubheading('1. Objeto e Escopo'),
    pw.Text(
      _scope,
      style: const pw.TextStyle(fontSize: 8.3, color: gsPdfInk, lineSpacing: 1.28),
    ),
    gsSubheading('2. Metodologia de Execução'),
    gsStatementBlock('Calibração Volumétrica', _volumetricMethod),
    gsStatementBlock('Calibração de Temperatura – PT100', _temperatureMethod),
    gsStatementBlock('Calibração de Densidade', _densityMethod),
  ];
}

pw.Widget _platformBlock(_Platform platform) {
  final rows = <List<String>>[];
  for (final bico in platform.bicos) {
    for (var i = 0; i < bico.rows.length; i++) {
      rows.add([
        i == 0 ? bico.label : '',
        bico.rows[i].$1,
        bico.rows[i].$2,
      ]);
    }
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      gsSectionTitle(platform.title),
      gsDataTable(
        headers: const ['Bico', 'Produto / Componente', 'Vazão (L/min)'],
        rows: rows,
        flex: const [3, 3, 4],
        aligns: const [
          pw.TextAlign.left,
          pw.TextAlign.left,
          pw.TextAlign.left,
        ],
      ),
    ],
  );
}

List<pw.Widget> _additionalPage() {
  return [
    gsSectionTitle('Informações Adicionais do Serviço'),
    gsGoldList(const [
      'O certificado da calibração será entregue em até 15 dias úteis após a conclusão do serviço;',
    ]),
    gsSectionTitle('Critérios de Aceitação'),
    gsStatementBlock('Calibração Volumétrica', _criteriaVolumetric),
    gsStatementBlock('Calibração de Densidade', _criteriaDensity),
    gsStatementBlock(
      'Calibração de Temperatura / Malha de Temperatura',
      _criteriaTemperature,
    ),
    gsSectionTitle('Responsabilidades'),
    gsStatementBlock('Responsabilidade do cliente', _clientTruck),
    gsStatementBlock('Responsabilidade da contratada', _contractorConnections),
    gsSectionTitle('Documentos a serem entregues'),
    gsGoldList(_documents),
    gsSectionTitle('Norma Utilizada'),
    gsStatementBlock('Norma', _norma),
  ];
}

List<pw.Widget> _scheduleInvestmentPage() {
  return [
    gsSectionTitle('Cronograma do Serviço'),
    gsDataTable(
      headers: const [
        'Plataforma',
        'Medidores',
        'PT100',
        'Malha de Temperatura',
        'Densímetros',
        'Dias',
      ],
      rows: const [
        ['01', '9', '9', '9', '9', '4'],
        ['02', '9', '9', '9', '9', '4'],
        ['03', '9', '9', '9', '9', '4'],
        ['04', '9', '9', '9', '9', '4'],
      ],
      flex: const [2, 2, 2, 3, 2, 1],
      aligns: const [
        pw.TextAlign.center,
        pw.TextAlign.right,
        pw.TextAlign.right,
        pw.TextAlign.right,
        pw.TextAlign.right,
        pw.TextAlign.right,
      ],
    ),
    gsSectionTitle('Investimento'),
    gsDataTable(
      headers: const [
        'Descrição',
        'Quantidade',
        'Valor Unitário',
        'Valor Total',
      ],
      rows: const [
        ['', '', '', ''],
        ['', '', '', ''],
        ['', '', '', ''],
        ['', '', '', ''],
        ['', '', '', ''],
      ],
      flex: const [4, 2, 2, 2],
      aligns: const [
        pw.TextAlign.left,
        pw.TextAlign.right,
        pw.TextAlign.right,
        pw.TextAlign.right,
      ],
    ),
    gsSectionTitle('Condições Comerciais'),
    gsDataTable(
      headers: const ['Condição', 'Informação'],
      rows: const [
        ['Impostos', ''],
        ['Valor do Serviço', ''],
        ['Condição De Pagamento', ''],
        ['Validade da Proposta', ''],
      ],
      flex: const [3, 5],
      aligns: const [pw.TextAlign.left, pw.TextAlign.left],
    ),
  ];
}

List<pw.Widget> _conclusionPage() {
  return [
    gsSectionTitle('Conclusão'),
    pw.Text(
      _conclusion1,
      textAlign: pw.TextAlign.justify,
      style: const pw.TextStyle(fontSize: 8.4, color: gsPdfInk, lineSpacing: 1.3),
    ),
    pw.SizedBox(height: 8),
    pw.Text(
      _conclusion2,
      textAlign: pw.TextAlign.justify,
      style: const pw.TextStyle(fontSize: 8.4, color: gsPdfInk, lineSpacing: 1.3),
    ),
    pw.SizedBox(height: 16),
    pw.Text(
      'Agradeço sua atenção.',
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: gsPdfPrimaryDark,
      ),
    ),
    pw.SizedBox(height: 36),
    pw.Container(width: 220, height: 1.4, color: gsPdfPrimaryGold),
    pw.SizedBox(height: 8),
    pw.Text(
      'Cleber Guimarães',
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: gsPdfPrimaryDark,
      ),
    ),
    pw.Text(
      'Cargo: Diretor / Técnico em Instrumentação Industrial',
      style: const pw.TextStyle(fontSize: 8, color: gsPdfMuted),
    ),
    pw.SizedBox(height: 16),
    gsTwoColPairs(const [
      ('Data da Emissão', '24 de Agosto de 2026'),
    ]),
  ];
}

pw.Widget gsAboutBlockCustom(String body) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 118,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SOBRE A',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryDark,
                  letterSpacing: 0.8,
                ),
              ),
              pw.Text(
                'EMPRESA',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryDark,
                  letterSpacing: 0.8,
                ),
              ),
              pw.SizedBox(height: 8),
              gsGoldAccentLine(width: 40, height: 2.4),
              pw.SizedBox(height: 10),
              gsGoldDots(),
            ],
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Text(
            body,
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(
              fontSize: 8.3,
              color: gsPdfInk,
              lineSpacing: 1.28,
            ),
          ),
        ),
      ],
    ),
  );
}
