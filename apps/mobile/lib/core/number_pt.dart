/// Leitura e exibição de números no padrão brasileiro.
///
/// Exemplos de entrada:
/// - `50.000` → 50000 (milhar)
/// - `49.975` → 49975
/// - `824,20` → 824.20
/// - `20,5` → 20.5
/// - `1.234,56` → 1234.56
double? parseBrNumber(String raw) {
  var text = raw.trim().replaceAll(' ', '').replaceAll('%', '');
  if (text.isEmpty) return null;

  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    // No BR a vírgula é decimal. Só trata como milhar quando o inteiro é ≥ 1
    // e a parte após a vírgula tem 3 dígitos sem zero à esquerda (ex.: 49,600).
    // Assim 0,045 fica 0.045 — e não vira 45.
    final before = text.substring(0, lastComma).replaceAll('.', '');
    final after = text.substring(lastComma + 1);
    final beforeNum = double.tryParse(before);
    final looksLikeThousands = after.length == 3 &&
        beforeNum != null &&
        beforeNum >= 1 &&
        (after == '000' || !after.startsWith('0'));
    if (looksLikeThousands) {
      text = before + after;
    } else {
      text = text.replaceAll(',', '.');
    }
  } else if (lastDot >= 0) {
    final parts = text.split('.');
    if (parts.length > 1 &&
        parts.last.length == 3 &&
        parts.every((part) => part.length <= 3)) {
      text = parts.join('');
    }
  }

  final value = double.tryParse(text);
  return value != null && value.isFinite ? value : null;
}

/// Formata com separador de milhar (.) e decimal (,).
String formatBrNumber(double value, [int digits = 2]) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final fromEnd = intPart.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  if (digits == 0) return '$sign$buf';
  return '$sign$buf,${parts[1]}';
}
