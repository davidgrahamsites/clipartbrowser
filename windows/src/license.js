// Windows-side licensing: machine fingerprint + Ed25519 verify (Node crypto,
// no deps). Mirrors the macOS LicenseVerifier / LicenseManager and the shared
// contract in coordination/SCHEMA.md.
const crypto = require("crypto");
const os = require("os");
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");

// Raw Ed25519 public key (base64) — must match the keygen app's private key.
const PUBLIC_KEY_B64 = "T9N5BJyrn6bEWPxSixZ3v8bscvg+g6dSAjm2dkoPOBs=";

function group16(hex) {
  return hex.slice(0, 16).toUpperCase().match(/.{1,4}/g).join("-");
}

// Stable per-machine fingerprint shown to the user.
function machineFingerprint() {
  let seed;
  try {
    if (process.platform === "win32") {
      const out = execSync(
        'reg query "HKLM\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid',
        { encoding: "utf8" }
      );
      const m = out.match(/MachineGuid\s+REG_SZ\s+([0-9A-Fa-f-]+)/);
      seed = m ? m[1] : os.hostname();
    } else {
      const cpu = (os.cpus()[0] || {}).model || "";
      seed = `${os.hostname()}|${os.platform()}|${cpu}`;
    }
  } catch (e) {
    seed = os.hostname();
  }
  return group16(crypto.createHash("sha256").update(seed).digest("hex"));
}

function fromB64url(s) {
  return Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

// Returns the payload object if the license is validly signed, bound to
// `fingerprint`, and not expired; otherwise null.
function verify(license, fingerprint) {
  if (typeof license !== "string") return null;
  const [part0, sigPart] = license.split(".");
  if (!part0 || !sigPart) return null;
  try {
    const der = Buffer.concat([
      Buffer.from("302a300506032b6570032100", "hex"),
      Buffer.from(PUBLIC_KEY_B64, "base64"),
    ]);
    const pub = crypto.createPublicKey({ key: der, format: "der", type: "spki" });
    if (!crypto.verify(null, Buffer.from(part0), pub, fromB64url(sigPart))) return null;
    const payload = JSON.parse(fromB64url(part0).toString("utf8"));
    if (String(payload.mid || "").toUpperCase() !== fingerprint.toUpperCase()) return null;
    if (payload.exp && Date.now() / 1000 > payload.exp) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

function licensePath(app) {
  return path.join(app.getPath("userData"), "license.json");
}

function loadKey(app) {
  try {
    return JSON.parse(fs.readFileSync(licensePath(app), "utf8")).key;
  } catch (e) {
    return null;
  }
}

function saveKey(app, key) {
  fs.writeFileSync(licensePath(app), JSON.stringify({ key }));
}

function isLicensed(app) {
  const key = loadKey(app);
  return !!(key && verify(key, machineFingerprint()));
}

module.exports = { PUBLIC_KEY_B64, machineFingerprint, verify, isLicensed, saveKey };
