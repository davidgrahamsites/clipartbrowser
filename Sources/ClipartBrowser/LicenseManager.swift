import ClipartBrowserCore
import CryptoKit
import Foundation
import IOKit

/// App-side licensing: computes this machine's fingerprint, stores/loads the
/// license, and verifies it with the embedded public key via `LicenseVerifier`.
enum LicenseManager {
    /// Raw Ed25519 public key (base64) — must match the keygen app's private key.
    /// See coordination/SCHEMA.md "License".
    static let publicKeyBase64 = "T9N5BJyrn6bEWPxSixZ3v8bscvg+g6dSAjm2dkoPOBs="

    /// Stable per-machine fingerprint shown to the user (e.g. "A1B2-C3D4-E5F6-7890").
    static var machineFingerprint: String {
        let seed = hardwareUUID() ?? (Host.current().name ?? "unknown-mac")
        let digest = SHA256.hash(data: Data(seed.utf8))
        let hex = digest.map { String(format: "%02X", $0) }.joined()
        return group(String(hex.prefix(16)))
    }

    static var isLicensed: Bool {
        guard let stored = try? String(contentsOf: licenseURL, encoding: .utf8) else { return false }
        return LicenseVerifier.isValid(
            license: stored.trimmingCharacters(in: .whitespacesAndNewlines),
            machineFingerprint: machineFingerprint,
            publicKeyBase64: publicKeyBase64
        )
    }

    /// Validates `key` for this machine; persists it and returns true on success.
    @discardableResult
    static func activate(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LicenseVerifier.isValid(license: trimmed, machineFingerprint: machineFingerprint, publicKeyBase64: publicKeyBase64) else {
            return false
        }
        try? FileManager.default.createDirectory(at: licenseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? trimmed.write(to: licenseURL, atomically: true, encoding: .utf8)
        return true
    }

    private static var licenseURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ClipartBrowser/license.txt")
    }

    private static func group(_ s: String) -> String {
        stride(from: 0, to: s.count, by: 4).map { i in
            let start = s.index(s.startIndex, offsetBy: i)
            let end = s.index(start, offsetBy: 4, limitedBy: s.endIndex) ?? s.endIndex
            return String(s[start..<end])
        }.joined(separator: "-")
    }

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let property = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        return property?.takeRetainedValue() as? String
    }
}
