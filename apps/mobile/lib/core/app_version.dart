/// Versão visível no app; o último número sobe a cada publicação no site.
/// O número de build (`appBuild` / `+N` no pubspec) também sobe a cada publicação.
///
/// **Obrigatório:** `appBuild` == `+N` do `pubspec.yaml` e o texto em
/// `web/index.html` (.gs-boot-version) == `appVersion`. Se `appBuild` ficar
/// atrás do `version.json` do site, a faixa amarela "Atualizar" nunca some.
const appVersion = '1.2.97';
const appBuild = 290;

/// Texto curto para telas: `1.2.55`.
String get appVersionLabel => appVersion;
