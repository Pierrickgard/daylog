// Release signing key, kept in the login Keychain (never in the repo, never on GitHub).
//   swift scripts/release-key.swift generate      create the key once, print the public key
//   swift scripts/release-key.swift public        print the public key
//   swift scripts/release-key.swift sign FILE     print the base64 Ed25519 signature of FILE
//   swift scripts/release-key.swift verify FILE SIG PUBLICKEY
import CryptoKit
import Foundation
import Security

let service = "io.github.daylog.release-key"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

func loadKey() -> Curve25519.Signing.PrivateKey? {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "generate":
    if let key = loadKey() {
        print(key.publicKey.rawRepresentation.base64EncodedString())
        fail("A release key already exists in the Keychain (public key above).")
    }
    let key = Curve25519.Signing.PrivateKey()
    let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                              kSecAttrAccount as String: "daylog", kSecAttrLabel as String: "Daylog release signing key",
                              kSecValueData as String: key.rawRepresentation]
    let status = SecItemAdd(add as CFDictionary, nil)
    guard status == errSecSuccess else { fail("Keychain error \(status)") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "public":
    guard let key = loadKey() else { fail("No release key in the Keychain. Run: generate") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard let key = loadKey() else { fail("No release key in the Keychain. Run: generate") }
    guard let path = args.dropFirst().first, let data = FileManager.default.contents(atPath: path) else { fail("No file") }
    print(try key.signature(for: data).base64EncodedString())
case "verify":
    let a = Array(args.dropFirst())
    guard a.count == 3, let data = FileManager.default.contents(atPath: a[0]),
          let sigText = try? String(contentsOfFile: a[1], encoding: .utf8),
          let sig = Data(base64Encoded: sigText.trimmingCharacters(in: .whitespacesAndNewlines)),
          let pub = Data(base64Encoded: a[2]),
          let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pub) else { fail("Bad arguments") }
    guard key.isValidSignature(sig, for: data) else { fail("INVALID signature") }
    print("Signature OK")
default:
    fail("usage: release-key.swift generate | public | sign FILE | verify FILE SIG PUBLICKEY")
}
