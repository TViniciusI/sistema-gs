/// Versão visível no app; o último número sobe a cada publicação no site.
/// O número de build (`appBuild` / `+N` no pubspec) também sobe a cada publicação.
const appVersion = '1.2.89';
const appBuild = 282;

/// Texto curto para telas: `1.2.55`.
String get appVersionLabel => appVersion;
