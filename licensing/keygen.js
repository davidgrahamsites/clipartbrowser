#!/usr/bin/env node
// ClipartBrowser license keygen (developer-only; uses Node crypto, no deps).
//
//   node licensing/keygen.js init
//       Generate the Ed25519 keypair. Writes licensing/private.pem (KEEP SECRET,
//       gitignored, BACK IT UP) and prints the public key to embed in the apps.
//
//   node licensing/keygen.js issue --mid AAAA-BBBB-CCCC-DDDD [--name "Jane"] [--exp 2027-12-31]
//       Print a license key that only validates on the machine with that
//       fingerprint (the value the app shows the user).
//
// License format (see coordination/SCHEMA.md):
//   base64url(payloadJSON) + "." + base64url(ed25519-signature-over-part0)
//   payload = { "mid": "<fingerprint>", "name"?: "<str>", "exp"?: <unix-seconds> }
"use strict";
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const PRIV = path.join(__dirname, "private.pem");

function b64url(buf) {
  return Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function init() {
  if (fs.existsSync(PRIV)) {
    console.error("Refusing to overwrite existing licensing/private.pem.");
    process.exit(1);
  }
  const { publicKey, privateKey } = crypto.generateKeyPairSync("ed25519");
  fs.writeFileSync(PRIV, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
  const spki = publicKey.export({ type: "spki", format: "der" }); // 12-byte header + 32-byte key
  const raw = spki.subarray(spki.length - 32);
  console.log("Keypair generated.");
  console.log("  licensing/private.pem written — KEEP SECRET and BACK IT UP.");
  console.log("");
  console.log("Embed this PUBLIC KEY (raw Ed25519, base64) in every edition:");
  console.log("  " + Buffer.from(raw).toString("base64"));
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) out[argv[i].slice(2)] = argv[i + 1];
  }
  return out;
}

function issue(argv) {
  if (!fs.existsSync(PRIV)) {
    console.error("No licensing/private.pem — run `node licensing/keygen.js init` first.");
    process.exit(1);
  }
  const args = parseArgs(argv);
  if (!args.mid) {
    console.error("--mid <fingerprint> is required (the value the app shows the user).");
    process.exit(1);
  }
  const payload = { mid: String(args.mid).trim().toUpperCase() };
  if (args.name) payload.name = String(args.name);
  if (args.exp) {
    const ts = Math.floor(new Date(args.exp + "T23:59:59Z").getTime() / 1000);
    if (Number.isNaN(ts)) {
      console.error("--exp must be YYYY-MM-DD");
      process.exit(1);
    }
    payload.exp = ts;
  }
  const priv = crypto.createPrivateKey(fs.readFileSync(PRIV));
  const part0 = b64url(Buffer.from(JSON.stringify(payload)));
  const sig = crypto.sign(null, Buffer.from(part0), priv);
  console.log(part0 + "." + b64url(sig));
}

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === "init") init();
else if (cmd === "issue") issue(rest);
else {
  console.error("Usage: keygen.js init | keygen.js issue --mid <fp> [--name <n>] [--exp YYYY-MM-DD]");
  process.exit(1);
}
