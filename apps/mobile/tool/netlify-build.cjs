"use strict";

const { execSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const version = process.env.FLUTTER_VERSION || "3.35.6";
const cacheRoot = process.env.NETLIFY_CACHE_DIR || path.join(os.homedir(), ".cache");
const flutterDir = path.join(cacheRoot, `flutter-${version}`);
const flutterBin = path.join(flutterDir, "bin", process.platform === "win32" ? "flutter.bat" : "flutter");
const tarball = `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${version}-stable.tar.xz`;

function run(command, extraEnv = {}) {
  execSync(command, {
    stdio: "inherit",
    env: { ...process.env, ...extraEnv },
    shell: true,
  });
}

if (!fs.existsSync(flutterBin)) {
  fs.mkdirSync(cacheRoot, { recursive: true });
  const extracted = path.join(cacheRoot, "flutter");
  if (fs.existsSync(extracted)) {
    fs.rmSync(extracted, { recursive: true, force: true });
  }
  console.log(`Baixando Flutter ${version}…`);
  run(`curl -L "${tarball}" | tar -xJ -C "${cacheRoot}"`);
  if (fs.existsSync(flutterDir)) {
    fs.rmSync(flutterDir, { recursive: true, force: true });
  }
  fs.renameSync(extracted, flutterDir);
}

const env = {
  PATH: `${path.join(flutterDir, "bin")}${path.delimiter}${process.env.PATH || ""}`,
  PUB_CACHE: path.join(cacheRoot, "pub-cache"),
};

run(`"${flutterBin}" config --no-analytics --enable-web`, env);
run(`"${flutterBin}" pub get`, env);

// Boot screen version must match app_version.dart — it triggers PWA cache clear.
const appVersionPath = path.join(__dirname, "..", "lib", "core", "app_version.dart");
const indexHtmlPath = path.join(__dirname, "..", "web", "index.html");
const appVersionSrc = fs.readFileSync(appVersionPath, "utf8");
const versionMatch = appVersionSrc.match(/const appVersion = '([^']+)'/);
if (versionMatch) {
  const appVersion = versionMatch[1];
  let indexHtml = fs.readFileSync(indexHtmlPath, "utf8");
  const nextHtml = indexHtml.replace(
    /(<span class="gs-boot-version">versão )[^<]+(<\/span>)/,
    `$1${appVersion}$2`,
  );
  if (nextHtml !== indexHtml) {
    fs.writeFileSync(indexHtmlPath, nextHtml);
    console.log(`Boot version → ${appVersion}`);
  }
}

const defines = [];
if (process.env.OFFICE_URL) {
  defines.push(`--dart-define=OFFICE_URL=${process.env.OFFICE_URL}`);
}

run(`"${flutterBin}" build web --release --pwa-strategy=offline-first ${defines.join(" ")}`.trim(), env);
