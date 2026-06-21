import AppKit
import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// Developer-only macOS app: signs a customer's Machine ID into a license key.
// Holds the Ed25519 private key (in Application Support / imported from the repo's
// licensing/private.pem). NEVER distribute this app — it can mint keys.

@main
struct ClipartKeygenApp: App {
    var body: some Scene {
        WindowGroup("ClipartBrowser License Keygen") {
            KeygenView()
        }
        .windowResizability(.contentSize)
    }
}

private enum KeyStore {
    static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipartKeygen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("private.key")
    }

    /// Convenience: the repo's gitignored private.pem on the developer's Mac.
    static var defaultPEMURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Apps/ClipartBrowser/licensing/private.pem")
    }

    static func load() -> Curve25519.Signing.PrivateKey? {
        if let data = try? Data(contentsOf: storeURL),
           let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            return key
        }
        if let key = importPEM(defaultPEMURL) { return key }
        return nil
    }

    @discardableResult
    static func save(_ key: Curve25519.Signing.PrivateKey) -> Bool {
        (try? key.rawRepresentation.write(to: storeURL, options: [.atomic, .completeFileProtection])) != nil
    }

    /// Extract the 32-byte Ed25519 seed from a PKCS#8 PEM (the seed is the last
    /// 32 bytes of the DER) and load it.
    static func importPEM(_ url: URL) -> Curve25519.Signing.PrivateKey? {
        guard let pem = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let b64 = pem.split(separator: "\n").filter { !$0.contains("-----") }.joined()
        guard let der = Data(base64Encoded: b64), der.count >= 32,
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: der.suffix(32))
        else { return nil }
        save(key)
        return key
    }
}

private func base64url(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private struct KeygenView: View {
    @State private var key: Curve25519.Signing.PrivateKey? = KeyStore.load()
    @State private var machineID = ""
    @State private var name = ""
    @State private var expiry = ""
    @State private var output = ""
    @State private var status = ""

    private var publicKeyB64: String {
        key?.publicKey.rawRepresentation.base64EncodedString() ?? "— no signing key loaded —"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ClipartBrowser — License Keygen")
                .font(.title2.bold())
            Text("Sign a customer's Machine ID into a one-computer license key.")
                .foregroundStyle(.secondary)

            GroupBox("Signing public key — must match the apps' embedded key") {
                HStack {
                    Text(publicKeyB64).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Button("Copy") { copy(publicKeyB64) }
                }.padding(4)
            }

            HStack {
                Button("Import private key (.pem)…") { importKey() }
                Button("Generate new keypair") { generateKeypair() }
                Spacer()
                Text(status).font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    Text("Machine ID").gridColumnAlignment(.trailing)
                    TextField("AAAA-BBBB-CCCC-DDDD (from the customer's app)", text: $machineID)
                }
                GridRow {
                    Text("Name").gridColumnAlignment(.trailing)
                    TextField("optional", text: $name)
                }
                GridRow {
                    Text("Expiry").gridColumnAlignment(.trailing)
                    TextField("optional — YYYY-MM-DD", text: $expiry)
                }
            }

            Button("Generate License Key") { generateLicense() }
                .buttonStyle(.borderedProminent)
                .disabled(key == nil || machineID.trimmingCharacters(in: .whitespaces).isEmpty)

            if !output.isEmpty {
                GroupBox("License key — send this to the customer") {
                    HStack(alignment: .top) {
                        Text(output).font(.system(.caption, design: .monospaced)).textSelection(.enabled).lineLimit(5)
                        Spacer()
                        Button("Copy") { copy(output) }
                    }.padding(4)
                }
            }
        }
        .padding(24)
        .frame(width: 640)
    }

    private func generateLicense() {
        guard let key else { return }
        var payload: [String: Any] = ["mid": machineID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { payload["name"] = trimmedName }
        let trimmedExpiry = expiry.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExpiry.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            guard let date = formatter.date(from: trimmedExpiry) else {
                status = "Expiry must be YYYY-MM-DD."
                return
            }
            payload["exp"] = Int(date.timeIntervalSince1970) + 86399
        }
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return }
        let part0 = base64url(json)
        guard let sig = try? key.signature(for: Data(part0.utf8)) else { return }
        output = part0 + "." + base64url(sig)
        status = "Generated."
    }

    private func generateKeypair() {
        let newKey = Curve25519.Signing.PrivateKey()
        KeyStore.save(newKey)
        key = newKey
        output = ""
        status = "New keypair saved — RE-EMBED this public key in all apps!"
    }

    private func importKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "pem") ?? .data, .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let imported = KeyStore.importPEM(url) {
            key = imported
            status = "Imported private key."
        } else {
            status = "Could not import that .pem."
        }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
