const { execSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

if (process.platform !== "linux") {
  process.exit(0);
}

const webRoot = path.join(__dirname, "..");
const repoRoot = path.join(webRoot, "..", "..");
const moduleRoots = [
  path.join(repoRoot, "node_modules"),
  path.join(webRoot, "node_modules"),
];

function log(message) {
  console.log(`[ensure-native-css] ${message}`);
}

function packageDir(name, base) {
  return path.join(base, ...name.split("/"));
}

function findPackage(name) {
  for (const base of moduleRoots) {
    const dir = packageDir(name, base);
    if (fs.existsSync(dir)) return dir;
  }
  return null;
}

function findLightningcssDirs() {
  return moduleRoots
    .map((base) => path.join(base, "lightningcss"))
    .filter((dir) => fs.existsSync(path.join(dir, "node", "index.js")));
}

function findNodeFile(dir) {
  if (!dir || !fs.existsSync(dir)) return null;
  const file = fs.readdirSync(dir).find((name) => name.endsWith(".node"));
  return file ? path.join(dir, file) : null;
}

function installPackage(name, version) {
  log(`installing ${name}@${version}`);
  execSync(`npm install ${name}@${version} --no-save --no-package-lock`, {
    cwd: repoRoot,
    stdio: "inherit",
    env: process.env,
  });
}

function ensurePackage(name, version) {
  let dir = findPackage(name);
  if (dir) return dir;
  installPackage(name, version);
  dir = findPackage(name);
  if (!dir) {
    throw new Error(`Could not install ${name}@${version}`);
  }
  return dir;
}

const gnuDir = ensurePackage("lightningcss-linux-x64-gnu", "1.32.0");
ensurePackage("@tailwindcss/oxide-linux-x64-gnu", "4.3.3");

const nodeBinding = findNodeFile(gnuDir);
if (!nodeBinding) {
  throw new Error(`No .node binary inside ${gnuDir}`);
}

const lightningcssDirs = findLightningcssDirs();
if (lightningcssDirs.length === 0) {
  throw new Error("lightningcss is not installed");
}

for (const dir of lightningcssDirs) {
  const dest = path.join(dir, "lightningcss.linux-x64-gnu.node");
  fs.copyFileSync(nodeBinding, dest);
  log(`placed native binding in ${dest}`);
}
