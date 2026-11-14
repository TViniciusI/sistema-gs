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

const defines = [];
if (process.env.OFFICE_URL) {
  defines.push(`--dart-define=OFFICE_URL=${process.env.OFFICE_URL}`);
}

run(`"${flutterBin}" build web --release --pwa-strategy=offline-first ${defines.join(" ")}`.trim(), env);
