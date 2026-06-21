import CryptoKit
import XCTest
@testable import ClipartBrowserCore

final class LicenseVerifierTests: XCTestCase {
    private func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Signs `payloadJSON` with `key`, producing a license in the shared format.
    private func makeLicense(_ payloadJSON: String, key: Curve25519.Signing.PrivateKey) -> String {
        let part0 = base64url(Data(payloadJSON.utf8))
        let sig = try! key.signature(for: Data(part0.utf8))
        return part0 + "." + base64url(sig)
    }

    func testValidLicenseForThisMachinePasses() {
        let key = Curve25519.Signing.PrivateKey()
        let pub = key.publicKey.rawRepresentation.base64EncodedString()
        let license = makeLicense(#"{"mid":"AAAA-BBBB-CCCC-DDDD","name":"Jane"}"#, key: key)

        let payload = LicenseVerifier.payload(
            forLicense: license,
            machineFingerprint: "aaaa-bbbb-cccc-dddd", // case-insensitive
            publicKeyBase64: pub
        )
        XCTAssertEqual(payload?["name"] as? String, "Jane")
    }

    func testWrongMachineRejected() {
        let key = Curve25519.Signing.PrivateKey()
        let pub = key.publicKey.rawRepresentation.base64EncodedString()
        let license = makeLicense(#"{"mid":"AAAA-BBBB-CCCC-DDDD"}"#, key: key)
        XCTAssertNil(LicenseVerifier.payload(forLicense: license, machineFingerprint: "ZZZZ-9999-0000-1111", publicKeyBase64: pub))
    }

    func testTamperedPayloadRejected() {
        let key = Curve25519.Signing.PrivateKey()
        let pub = key.publicKey.rawRepresentation.base64EncodedString()
        let license = makeLicense(#"{"mid":"AAAA-BBBB-CCCC-DDDD"}"#, key: key)
        let parts = license.split(separator: ".").map(String.init)
        let tampered = "X" + parts[0].dropFirst() + "." + parts[1]
        XCTAssertNil(LicenseVerifier.payload(forLicense: tampered, machineFingerprint: "AAAA-BBBB-CCCC-DDDD", publicKeyBase64: pub))
    }

    func testWrongKeyRejected() {
        let key = Curve25519.Signing.PrivateKey()
        let otherPub = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        let license = makeLicense(#"{"mid":"AAAA-BBBB-CCCC-DDDD"}"#, key: key)
        XCTAssertNil(LicenseVerifier.payload(forLicense: license, machineFingerprint: "AAAA-BBBB-CCCC-DDDD", publicKeyBase64: otherPub))
    }

    func testExpiredLicenseRejected() {
        let key = Curve25519.Signing.PrivateKey()
        let pub = key.publicKey.rawRepresentation.base64EncodedString()
        let license = makeLicense(#"{"mid":"AAAA-BBBB-CCCC-DDDD","exp":1000}"#, key: key)
        // now is well after exp=1000 (1970)
        XCTAssertNil(LicenseVerifier.payload(forLicense: license, machineFingerprint: "AAAA-BBBB-CCCC-DDDD", publicKeyBase64: pub, now: Date(timeIntervalSince1970: 2000)))
        // but valid before exp
        XCTAssertNotNil(LicenseVerifier.payload(forLicense: license, machineFingerprint: "AAAA-BBBB-CCCC-DDDD", publicKeyBase64: pub, now: Date(timeIntervalSince1970: 500)))
    }
}
