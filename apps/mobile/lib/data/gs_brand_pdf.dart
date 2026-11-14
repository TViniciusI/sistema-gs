import 'package:flutter/services.dart';
import 'package:gs_mobile/data/models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Gold corner bars are JPEG strips (full-page images hang package:pdf).
// Header/cover logos are transparent PNGs so no white plate on the page.

const gsPdfPrimaryDark = PdfColor.fromInt(0xFF2B2B2B);
const gsPdfPrimaryDarkSoft = PdfColor.fromInt(0xFF3A3A3A);
const gsPdfPrimaryGold = PdfColor.fromInt(0xFFE0A83A);
const gsPdfGoldLight = PdfColor.fromInt(0xFFF1A93A);
const gsPdfGoldDeep = PdfColor.fromInt(0xFFB8860B);
const gsPdfTextDark = PdfColor.fromInt(0xFF2B2B2B);
const gsPdfTextLight = PdfColor.fromInt(0xFFFFFFFF);
const gsPdfBackgroundLight = PdfColor.fromInt(0xFFFCFBF8);
const gsPdfPanel = PdfColor.fromInt(0xFFF6F1E8);
const gsPdfMuted = PdfColor.fromInt(0xFF6B6560);
const gsPdfLine = PdfColor.fromInt(0xFF2E2C28);
const gsPdfRow = PdfColor.fromInt(0xFFF4EFE6);

const gsPdfNavy = gsPdfPrimaryDark;
const gsPdfGold = gsPdfPrimaryGold;
const gsPdfGoldSoft = gsPdfGoldLight;
const gsPdfBlack = gsPdfPrimaryDark;
const gsPdfInk = gsPdfTextDark;
const gsPdfBarTop = gsPdfPrimaryDarkSoft;

pw.MemoryImage? _logo;
pw.MemoryImage? _logoCover;
pw.MemoryImage? _innerLeft;
pw.MemoryImage? _innerRight;
pw.MemoryImage? _coverLeft;
pw.MemoryImage? _coverRight;
pw.Font? gsPdfRegular;
pw.Font? gsPdfBold;
var _brandReady = false;

Future<Uint8List> _assetBytes(String path) async {
  final data = await rootBundle.load(path);
  return Uint8List.sublistView(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

bool _isPngOrJpeg(Uint8List bytes) {
  if (bytes.length < 4) return false;
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }
  return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

bool _isHtmlPayload(Uint8List bytes) {
  final head = String.fromCharCodes(
    bytes.take(bytes.length < 80 ? bytes.length : 80),
  ).trimLeft().toLowerCase();
  return head.startsWith('<!doctype') || head.startsWith('<html');
}

Future<pw.MemoryImage?> _loadPdfImage(
  String path, {
  bool required = false,
}) async {
  try {
    final bytes = await _assetBytes(path);
    if (_isHtmlPayload(bytes) || !_isPngOrJpeg(bytes)) {
      if (!required) return null;
      throw StateError(
        'Imagem do certificado inválida ($path, ${bytes.length} bytes). '
        'Atualize a publicação no Netlify e recarregue com Ctrl+F5 '
        '(cache antigo às vezes entrega a página HTML no lugar do arquivo).',
      );
    }
    return pw.MemoryImage(bytes);
  } catch (error) {
    if (required) rethrow;
    return null;
  }
}

Future<void> loadGsBrandPdf() async {
  if (_brandReady &&
      gsPdfRegular != null &&
      gsPdfBold != null) {
    return;
  }
  try {
    gsPdfRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    gsPdfBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
  } catch (_) {
    gsPdfRegular = pw.Font.helvetica();
    gsPdfBold = pw.Font.helveticaBold();
  }
  _logo = await _loadPdfImage('assets/cert/logo_gold_hd.png') ??
      await _loadPdfImage('assets/cert/logo_clear.png');
  _logoCover = await _loadPdfImage('assets/cert/logo_gold_cover_hd.png') ??
      await _loadPdfImage('assets/cert/logo_cover.png') ??
      _logo;
  _innerLeft = await _loadPdfImage('assets/cert/inner_left.jpg');
  _innerRight = await _loadPdfImage('assets/cert/inner_right.jpg');
  _coverLeft = await _loadPdfImage('assets/cert/cover_left.jpg');
  _coverRight = await _loadPdfImage('assets/cert/cover_right.jpg');
  _brandReady = true;
}

pw.MemoryImage? get gsPdfLogo => _logo;
pw.MemoryImage? get gsPdfLogoCover => _logoCover ?? _logo;

/// [cover] = dourado claro para fundo escuro.
pw.Widget? gsPdfLogoWidget({required double height, bool cover = false}) {
  final image = cover ? gsPdfLogoCover : gsPdfLogo;
  if (image != null) return pw.Image(image, height: height);
  return null;
}

pw.PageTheme gsCoverTheme() {
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: gsPdfCoverMargin,
    theme: pw.ThemeData.withFont(base: gsPdfRegular!, bold: gsPdfBold!),
    buildBackground: (_) => _pageBackdrop(cover: true),
  );
}

// Corner JPEG strips (inner_left / inner_right). Opaque gold bars on the
// right reach ~100pt inward; the dark left bar ~42pt. Content margins must
// stay outside those zones or labels/date sit under the artwork.
const _gsPdfLeftStripFrac = 0.12;
const _gsPdfRightStripFrac = 0.26;
const gsPdfContentMargin = pw.EdgeInsets.fromLTRB(56, 22, 112, 34);
const gsPdfCoverMargin = pw.EdgeInsets.fromLTRB(84, 40, 168, 44);

pw.Widget _pageBackdrop({required bool cover}) {
  final pageW = PdfPageFormat.a4.width;
  final pageH = PdfPageFormat.a4.height;
  final leftW = pageW * _gsPdfLeftStripFrac;
  final rightW = pageW * _gsPdfRightStripFrac;
  final leftImage = cover ? _coverLeft : _innerLeft;
  final rightImage = cover ? _coverRight : _innerRight;
  final leftFallback =
      cover ? gsPdfPrimaryDark : const PdfColor.fromInt(0xFFC59E39);
  final rightFallback = cover ? gsPdfPrimaryDarkSoft : gsPdfPanel;
  return pw.FullPage(
    ignoreMargins: true,
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: leftW,
          height: pageH,
          child: leftImage == null
              ? pw.Container(color: leftFallback)
              : pw.Image(
                  leftImage,
                  width: leftW,
                  height: pageH,
                  fit: pw.BoxFit.fill,
                ),
        ),
        pw.Container(
          width: pageW - leftW - rightW,
          height: pageH,
          color: cover ? gsPdfPrimaryDark : gsPdfBackgroundLight,
        ),
        pw.SizedBox(
          width: rightW,
          height: pageH,
          child: rightImage == null
              ? pw.Container(color: rightFallback)
              : pw.Image(
                  rightImage,
                  width: rightW,
                  height: pageH,
                  fit: pw.BoxFit.fill,
                ),
        ),
      ],
    ),
  );
}

pw.PageTheme gsCertificateTheme({bool technical = false}) {
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: gsPdfContentMargin,
    theme: pw.ThemeData.withFont(base: gsPdfRegular!, bold: gsPdfBold!),
    buildBackground: (_) {
      final _ = technical;
      return _pageBackdrop(cover: false);
    },
  );
}

pw.Widget gsGoldAccentLine({double width = 42, double height = 2.2}) {
  return pw.Container(
    width: width,
    height: height,
    color: gsPdfPrimaryGold,
  );
}

pw.Widget gsGoldDots({int count = 3, double size = 3.4}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) pw.SizedBox(width: 4),
        pw.Container(
          width: size,
          height: size,
          decoration: const pw.BoxDecoration(
            color: gsPdfPrimaryGold,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(1)),
          ),
        ),
      ],
    ],
  );
}

pw.PageTheme gsProposalTheme() {
  return gsCertificateTheme();
}

pw.Widget gsProposalHeader(pw.Context context) {
  final logo = gsPdfLogoWidget(height: 44);
  return pw.SizedBox(
    height: 46,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null)
          logo
        else
          pw.Text(
            'GS SOLUÇÕES',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: gsPdfPrimaryDark,
            ),
          ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'GS SOLUÇÕES',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryDark,
                  letterSpacing: 0.6,
                ),
              ),
              pw.Text(
                'PROPOSTA TÉCNICA COMERCIAL',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryGold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget gsDocHeader({String date = '', String qrUrl = ''}) {
  final stamp = date.trim();
  final qr = qrUrl.trim();
  final logo = gsPdfLogoWidget(height: 44);
  return pw.SizedBox(
    height: 52,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (logo != null)
              logo
            else
              pw.Text(
                'GS SOLUÇÕES TÉCNICAS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: gsPdfPrimaryDark,
                ),
              ),
            pw.SizedBox(width: 10),
            gsGoldAccentLine(width: 26, height: 1.8),
          ],
        ),
        if (stamp.isNotEmpty || qr.isNotEmpty)
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (stamp.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'DATA DA CALIBRAÇÃO',
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                        color: gsPdfPrimaryGold,
                        letterSpacing: 0.55,
                      ),
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      stamp,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: gsPdfPrimaryDark,
                      ),
                    ),
                    if (qr.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Consulte pelo QR code',
                        style: const pw.TextStyle(
                          fontSize: 5.8,
                          color: gsPdfMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              if (qr.isNotEmpty) ...[
                pw.SizedBox(width: 8),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qr,
                  width: 48,
                  height: 48,
                  drawText: false,
                  color: gsPdfPrimaryDark,
                ),
              ],
            ],
          ),
      ],
    ),
  );
}

pw.Widget gsDocFooter(
  pw.Context context, {
  int pageOffset = 0,
  bool includeTotal = false,
  bool dark = false,
}) {
  final page = context.pageNumber + pageOffset;
  final label = includeTotal
      ? 'Página $page de ${context.pagesCount}'
      : 'Página $page';
  final muted = dark ? gsPdfGoldLight : gsPdfMuted;
  final ink = dark ? gsPdfTextLight : gsPdfInk;
  final strong = dark ? gsPdfTextLight : gsPdfPrimaryDark;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        children: [
          pw.Container(width: 10, height: 1.1, color: gsPdfPrimaryGold),
          pw.SizedBox(width: 2),
          pw.Container(width: 16, height: 1.1, color: gsPdfPrimaryGold),
          pw.SizedBox(width: 2),
          pw.Expanded(
            child: pw.Container(height: 3.2, color: gsPdfPrimaryGold),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              gsCompanyAddress,
              style: pw.TextStyle(fontSize: 7, color: muted),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(gsCompanyPhone, style: pw.TextStyle(fontSize: 7, color: ink)),
              pw.Text(gsCompanyEmail, style: pw.TextStyle(fontSize: 7, color: ink)),
              pw.Text(gsCompanySite, style: pw.TextStyle(fontSize: 7, color: ink)),
              pw.Text(
                'CNPJ: $gsCompanyCnpj',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: strong,
                ),
              ),
            ],
          ),
          pw.SizedBox(width: 10),
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: muted)),
        ],
      ),
    ],
  );
}

pw.Widget gsSectionBar(String title) => gsSectionTitle(title);

pw.Widget gsSectionTitle(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 3, bottom: 2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 6,
          height: 14,
          color: gsPdfPrimaryGold,
        ),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 2.5, 10, 2.5),
            color: gsPdfPrimaryDark,
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfPrimaryGold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget gsWithCompany(String companyName) {
  final name = gsCertPrint(companyName);
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(2, 2, 2, 8),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          const pw.TextSpan(
            text: 'Contratante  ',
            style: pw.TextStyle(fontSize: 8, color: gsPdfPrimaryGold),
          ),
          pw.TextSpan(
            text: name.isEmpty ? '—' : name,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: gsPdfPrimaryDark,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget gsDocTitle({
  required String title,
  required String subtitle,
  String number = '',
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5, top: 1),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        gsGoldDots(size: 3.2),
        pw.SizedBox(height: 4),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfPrimaryDark,
            letterSpacing: 1.05,
          ),
        ),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfPrimaryGold,
          ),
        ),
        if (number.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Certificado Nº: ${number.trim()}',
              style: pw.TextStyle(
                fontSize: 9.2,
                fontWeight: pw.FontWeight.bold,
                color: gsPdfPrimaryDark,
              ),
            ),
          ),
        pw.SizedBox(height: 4),
        gsGoldAccentLine(width: 72, height: 2.2),
      ],
    ),
  );
}

/// Drop Excel/Word merge failures and fake uncertainty placeholders.
/// Real tags such as X or XX must survive; only the phrases k=XX and Veff=YY go.
String gsCertPrint(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return '';
  final compact = text.toLowerCase().replaceAll(' ', '');
  if (compact == 'erro' ||
      compact.startsWith('erro!') ||
      compact.contains('#erro') ||
      compact.contains('#n/d') ||
      compact.contains('#n/a') ||
      compact.contains('#ref!') ||
      compact.contains('#valor!')) {
    return '';
  }
  text = text.replaceAll(RegExp(r'k\s*=\s*XX', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'Veff\s*=\s*YY', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  if (text.toLowerCase() == 'erro') return '';
  return text;
}

const gsAboutCompany =
    'A GS SOLUÇÕES foi criada com o propósito de atender as principais áreas '
    'da indústria, com a experiência adquirida pelo profissional atuante há '
    'mais de 15 anos na área de Óleo e Gás, com opções inovadoras de '
    'equipamentos e serviços de alta qualidade, sempre com foco para obter '
    'os melhores resultados em seu processo e atender suas demandas, '
    'agregando valores e conhecimentos, visando o contínuo aprimoramento '
    'em nossos serviços.';

const gsMission =
    'Prover serviços de alta qualidade, com foco na otimização de processos '
    'e na geração de resultados positivos para nossos clientes, através de '
    'soluções personalizadas e um atendimento diferenciado.';

const gsVision =
    'Alcançar a satisfação total dos clientes, oferecendo soluções '
    'personalizadas e de alta qualidade.';

const gsQualityPolicy =
    'Comprometemo-nos a fornecer serviços que superem as expectativas de '
    'nossos clientes, buscando a excelência em cada interação, além de '
    'incentivarmos a participação de todos os colaboradores na busca pela '
    'melhoria contínua dos processos e serviços. Atendemos aos requisitos '
          'legais e normativos aplicáveis, garantindo a qualidade e a segurança '
    'em todas as etapas do serviço. Valorizamos o feedback dos nossos '
    'clientes e utilizamos suas sugestões para aprimorar continuamente '
    'nossos serviços.';

const gsObjectives = [
  'Realizar o serviço de calibração com qualidade e segurança;',
  'Trazer solução de forma rápida, objetiva e duradoura;',
  'Contribuir com a melhora de Performance do cliente;',
  'Identificar os principais problemas na linha de produção.',
];

pw.Widget gsCoverPage({
  required String kicker,
  required String title,
  required String accent,
  String title2 = '',
  String subtitle = '',
  String number = '',
  String clientName = '',
  String date = '',
}) {
  final client = gsCertPrint(clientName);
  final coverLogo = gsPdfLogoWidget(height: 46, cover: true);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (coverLogo != null)
        coverLogo
      else
        pw.Text(
          'GS SOLUÇÕES TÉCNICAS',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfGoldLight,
          ),
        ),
      pw.SizedBox(height: 88),
      if (kicker.trim().isNotEmpty)
        pw.Text(
          kicker.trim().toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfGoldLight,
            letterSpacing: 2.4,
          ),
        ),
      pw.SizedBox(height: 12),
      pw.Container(width: 40, height: 3, color: gsPdfPrimaryGold),
      pw.SizedBox(height: 14),
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 34,
          fontWeight: pw.FontWeight.bold,
          color: gsPdfTextLight,
          letterSpacing: 1.35,
        ),
      ),
      if (title2.trim().isNotEmpty)
        pw.Text(
          title2.trim(),
          style: pw.TextStyle(
            fontSize: 34,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfTextLight,
            letterSpacing: 1.35,
          ),
        ),
      pw.Text(
        accent,
        style: pw.TextStyle(
          fontSize: 34,
          fontWeight: pw.FontWeight.bold,
          color: gsPdfGoldLight,
          letterSpacing: 1.35,
        ),
      ),
      if (subtitle.trim().isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text(
          subtitle.trim(),
          style: const pw.TextStyle(
            fontSize: 13,
            color: gsPdfTextLight,
            letterSpacing: 0.3,
          ),
        ),
      ],
      if (number.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text(
          'Certificado Nº: ${number.trim()}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfGoldLight,
          ),
        ),
      ],
      if (client.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        pw.Text(
          'CONTRATANTE',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfPrimaryGold,
            letterSpacing: 1.6,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          client,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfTextLight,
          ),
        ),
      ],
      if (date.trim().isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text(
          'DATA',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfPrimaryGold,
            letterSpacing: 1.6,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          date.trim(),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: gsPdfTextLight,
          ),
        ),
      ],
    ],
  );
}

void gsAddCoverPage(
  pw.Document doc, {
  required String title,
  required String accent,
  String kicker = '',
  String title2 = '',
  String subtitle = '',
  String number = '',
  String clientName = '',
  String date = '',
}) {
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: gsPdfCoverMargin,
        theme: pw.ThemeData.withFont(base: gsPdfRegular!, bold: gsPdfBold!),
        buildBackground: (_) => _pageBackdrop(cover: true),
      ),
      build: (_) => gsCoverPage(
        kicker: kicker,
        title: title,
        title2: title2,
        accent: accent,
        subtitle: subtitle,
        number: number,
        clientName: clientName,
        date: date,
      ),
    ),
  );
}

List<pw.Widget> gsIntroBlocks() {
  return [
    gsSectionTitle('Dados da Empresa'),
    gsTwoColPairs(const [
      ('Razão Social', gsCompanyLegalName),
      ('Optante pelo Simples Nacional', gsCompanySimples),
      ('Nome Fantasia', gsCompanyTradeName),
      ('CNPJ', gsCompanyCnpj),
      ('Insc. Estadual', gsCompanyIe),
      ('Insc. Municipal', gsCompanyIm),
      ('Endereço', gsCompanyStreet),
      ('Bairro', gsCompanyNeighborhood),
      ('Cidade', gsCompanyCity),
      ('UF', gsCompanyUf),
      ('Telefone', gsCompanyPhone),
      ('CEP', gsCompanyCep),
      ('E-mail', gsCompanyEmail),
      ('Site', gsCompanySite),
    ]),
    gsAboutBlock(),
    gsSectionTitle('Objetivo'),
    gsGoldList(gsObjectives),
    gsStatementBlock('Missão', gsMission),
    gsStatementBlock('Visão', gsVision),
    gsStatementBlock('Política de Qualidade', gsQualityPolicy),
    gsSectionTitle('Dados Bancários'),
    gsTwoColPairs(const [
      ('Banco', gsCompanyBank),
      ('Código', gsCompanyBankCode),
      ('Conta Corrente', gsCompanyBankAccount),
      ('Agência', gsCompanyBankAgency),
      ('Pix', gsCompanyPix),
    ]),
  ];
}

pw.Widget gsAboutBlock() {
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
        pw.Expanded(child: _bodyText(gsAboutCompany)),
      ],
    ),
  );
}

pw.Widget gsStatementBlock(String title, String body) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 9),
    child: pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const pw.BoxDecoration(
        color: gsPdfPanel,
        border: pw.Border(
          left: pw.BorderSide(color: gsPdfPrimaryGold, width: 3.1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8.6,
              fontWeight: pw.FontWeight.bold,
              color: gsPdfPrimaryGold,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 4),
          _bodyText(body),
        ],
      ),
    ),
  );
}

pw.Widget gsSideSection(String title, String body) {
  return gsStatementBlock(title, body);
}

pw.Widget gsTwoColPairs(List<(String, String)> pairs) {
  final visible = [
    for (final pair in pairs)
      if (gsCertPrint(pair.$2).isNotEmpty) (pair.$1, gsCertPrint(pair.$2)),
  ];
  if (visible.isEmpty) return pw.SizedBox();
  final rows = <pw.Widget>[];
  for (var i = 0; i < visible.length; i += 2) {
    final left = visible[i];
    final right = i + 1 < visible.length ? visible[i + 1] : null;
    rows.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: gsKv(left.$1, left.$2)),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: right == null ? pw.SizedBox() : gsKv(right.$1, right.$2),
            ),
          ],
        ),
      ),
    );
  }
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(2, 1, 2, 1),
    child: pw.Column(children: rows),
  );
}

pw.Widget gsKv(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
          color: gsPdfPrimaryGold,
          letterSpacing: 0.55,
        ),
      ),
      pw.SizedBox(height: 1.5),
      pw.Text(
        value,
        style: const pw.TextStyle(fontSize: 8.4, color: gsPdfInk),
      ),
    ],
  );
}

pw.Widget gsGoldList(List<String> items) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final item in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 2, bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2.4),
                child: pw.Container(
                  width: 6,
                  height: 6,
                  decoration: const pw.BoxDecoration(
                    color: gsPdfPrimaryGold,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(1)),
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  item,
                  style: const pw.TextStyle(
                    fontSize: 8.4,
                    color: gsPdfInk,
                    lineSpacing: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget gsBulletList(List<String> items) => gsGoldList(items);

pw.Widget gsSubheading(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 9.2,
        fontWeight: pw.FontWeight.bold,
        color: gsPdfPrimaryDark,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class GsColHead {
  const GsColHead(this.title, {this.unit = ''});

  final String title;
  final String unit;
}

pw.TableRow gsTableHead(List<String> cells) {
  return pw.TableRow(
    repeat: true,
    decoration: const pw.BoxDecoration(color: gsPdfPrimaryGold),
    children: [
      for (final cell in cells) gsTableCell(cell, header: true),
    ],
  );
}

List<pw.TableRow> gsTableHeader(List<GsColHead> columns) {
  final hasUnits = columns.any((column) => column.unit.trim().isNotEmpty);
  return [
    pw.TableRow(
      repeat: true,
      decoration: const pw.BoxDecoration(color: gsPdfPrimaryGold),
      children: [
        for (final column in columns) gsTableCell(column.title, header: true),
      ],
    ),
    if (hasUnits)
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: gsPdfPanel),
        children: [
          for (final column in columns)
            gsTableCell(
              column.unit.trim().isEmpty ? '—' : column.unit.trim(),
              unit: true,
            ),
        ],
      ),
  ];
}

/// Título + conteúdo andam juntos. Se o bloco não cabe no resto da folha,
/// ele desce inteiro para a próxima — sem título órfão nem tabela partida.
pw.Widget gsKeep(List<pw.Widget> children) {
  return pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: children,
    ),
  );
}

pw.Widget gsTableCell(
  String text, {
  bool header = false,
  bool unit = false,
  pw.TextAlign textAlign = pw.TextAlign.center,
}) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(
      horizontal: 3.2,
      vertical: unit ? 2.6 : (header ? 4.4 : 3.8),
    ),
    child: pw.Text(
      text,
      textAlign: textAlign,
      style: pw.TextStyle(
        fontSize: unit ? 7.4 : 8.0,
        fontWeight: (header || unit) ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: gsPdfPrimaryDark,
      ),
    ),
  );
}

pw.Widget gsDataTable({
  required List<String> headers,
  required List<List<String>> rows,
  List<int>? flex,
  List<pw.TextAlign>? aligns,
}) {
  final colCount = headers.length;
  return pw.Table(
    columnWidths: {
      for (var i = 0; i < colCount; i++)
        i: pw.FlexColumnWidth(flex != null && i < flex.length ? flex[i].toDouble() : 1),
    },
    border: pw.TableBorder.all(color: gsPdfLine, width: 0.4),
    children: [
      gsTableHead(headers),
      for (var r = 0; r < rows.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: r.isOdd ? gsPdfRow : null),
          children: [
            for (var c = 0; c < colCount; c++)
              gsTableCell(
                c < rows[r].length ? rows[r][c] : '',
                textAlign: aligns != null && c < aligns.length
                    ? aligns[c]
                    : pw.TextAlign.left,
              ),
          ],
        ),
    ],
  );
}

pw.Widget _bodyText(String text) {
  return pw.Text(
    text,
    textAlign: pw.TextAlign.justify,
    style: const pw.TextStyle(fontSize: 8.3, color: gsPdfInk, lineSpacing: 1.28),
  );
}
