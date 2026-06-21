import CryptoKit
import Foundation

/// Pure, testable Ed25519 license verification shared by the app. The license
/// string is `base64url(payloadJSON) + "." + base64url(signature)`, where the
/// signature is over the `base64url(payloadJSON)` bytes (see coordination/SCHEMA.md).
public enum LicenseVerifier {
    /// Returns the decoded payload if `license` is validly signed by the holder
    /// of `publicKeyBase64`, is bound to `machineFingerprint`, and is not expired.
    /// Returns `nil` otherwise.
    public static func payload(
        forLicense license: String,
        machineFingerprint: String,
        publicKeyBase64: String,
        now: Date = Date()
    ) -> [String: Any]? {
        let parts = license.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let pubData = Data(base64Encoded: publicKeyBase64),
              let pubKey = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData),
              let sig = base64urlDecode(parts[1]),
              pubKey.isValidSignature(sig, for: Data(parts[0].utf8)),
              let payloadData = base64urlDecode(parts[0]),
              let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let mid = (obj["mid"] as? String)?.uppercased(),
              mid == machineFingerprint.uppercased()
        else {
            return nil
        }
        if let exp = obj["exp"] as? Double, now.timeIntervalSince1970 > exp {
            return nil
        }
        return obj
    }

    public static func isValid(
        license: String,
        machineFingerprint: String,
        publicKeyBase64: String,
        now: Date = Date()
    ) -> Bool {
        payload(forLicense: license, machineFingerprint: machineFingerprint, publicKeyBase64: publicKeyBase64, now: now) != nil
    }

    static func base64urlDecode(_ string: String) -> Data? {
        var b = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        return Data(base64Encoded: b)
    }
}
