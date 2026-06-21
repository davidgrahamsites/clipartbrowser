# Licensing (developer-only)

One-per-computer activation. The apps **verify**; only you can **issue** keys.

## Keypair
- `licensing/private.pem` — the Ed25519 **private key**. **Gitignored. Never
  commit or ship it. Back it up** (losing it means you can't issue keys without
  shipping a new public key in an app update).
- The matching **public key** is embedded in every edition (see
  `coordination/SCHEMA.md` → "License"). Current key:
  `T9N5BJyrn6bEWPxSixZ3v8bscvg+g6dSAjm2dkoPOBs=`

## Issuing a key (the normal flow)
1. The customer installs the app and reads the **Machine ID** it shows on the
   activation screen.
2. They send you that Machine ID.
3. You mint a key with the **ClipartKeygen** Mac app:
   - Build/refresh it: `scripts/package-keygen.sh` → `builds/ClipartKeygen.app`.
   - Open it (it auto-imports `private.pem`), paste the Machine ID, optionally a
     name/expiry, click **Generate License Key**, copy it.
4. Send the key back. They paste it; it only validates on that machine.

CLI alternative: `node licensing/keygen.js issue --mid AAAA-BBBB-CCCC-DDDD
[--name "Jane"] [--exp 2027-12-31]`.

## Rotating the key (if private.pem is lost/compromised)
`node licensing/keygen.js init` (or "Generate new keypair" in the app) → embed the
new public key in all editions (`LicenseManager.swift`, `windows/src/license.js`)
and SCHEMA.md, then ship updates. Old keys stop validating.

## Reality check
Client-side and the apps are unsigned, so a determined cracker can patch the
check. This deters casual copying and gives you an approval gate — not unbreakable
DRM.
