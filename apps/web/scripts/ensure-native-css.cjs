const { execSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

if (process.platform !== "linux") {
  process.exit(0);
}

const webRoot = path.join(__dirname, "..");
const repoRoot = path.join(webRoot, "..", "..");
const webModules = path.join(webRoot, "node_modules");
const rootModules = path.join(repoRoot, "node_modules");

function packageDir(name, base) {
  return path.join(base, ...name.split("/"));
}

function copyPackage(name) {
  const dest = packageDir(name, webModules);
  if (fs.existsSync(dest)) return dest;

  const src = packageDir(name, rootModules);
  if (!fs.existsSync(src)) return null;

  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(src, dest, { recursive: true });
  console.log(`[ensure-native-css] copied ${name}`);
  return dest;
}

function ensurePackage(name, version) {
  const existing = copyPackage(name);
  if (existing) return existing;

  console.log(`[ensure-native-css] installing ${name}@${version}`);
  execSync(`npm install ${name}@${version} --no-save --no-package-lock`, {
    cwd: webRoot,
    stdio: "inherit",
    env: process.env,
  });

  return copyPackage(name) ?? (fs.existsSync(packageDir(name, webModules))
    ? packageDir(name, webModules)
    : null);
}

function copyNodeBinding(pkgDir, destFileName) {
  const lightningcssDir = path.join(webModules, "lightningcss");
  if (!pkgDir || !fs.existsSync(lightningcssDir)) return;

  const dest = path.join(lightningcssDir, destFileName);
  if (fs.existsSync(dest)) return;

  const nodeFile = fs.readdirSync(pkgDir).find((file) => file.endsWith(".node"));
  if (!nodeFile) return;

  fs.copyFileSync(path.join(pkgDir, nodeFile), dest);
  console.log(`[ensure-native-css] placed ${destFileName}`);
}

const gnu = ensurePackage("lightningcss-linux-x64-gnu", "1.32.0");
ensurePackage("lightningcss-linux-x64-musl", "1.32.0");
ensurePackage("@tailwindcss/oxide-linux-x64-gnu", "4.3.3");
ensurePackage("@tailwindcss/oxide-linux-x64-musl", "4.3.3");
copyNodeBinding(gnu, "lightningcss.linux-x64-gnu.node");
