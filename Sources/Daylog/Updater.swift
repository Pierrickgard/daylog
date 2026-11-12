import AppKit
import CryptoKit
import Foundation

/// Signed self-update.
///
/// Every release ships `update.json` (version, zip URL, SHA-256, size) and `update.json.sig`, an Ed25519 signature of
/// the exact bytes of `update.json`. The private key never leaves the maintainer's Keychain (see scripts/release.sh):
/// GitHub only hosts files, so a compromised GitHub account, release or CDN cannot produce an update this app accepts.
///
/// Before anything is installed:
///   1. the signature is checked against the public key below, before the manifest is even parsed;
///   2. the version must be strictly newer than the running one (no downgrade to an older, vulnerable release);
///   3. the zip must come from this repository's releases over HTTPS, and match the signed size and SHA-256;
///   4. the unzipped app must have the same bundle identifier and the signed version, and pass `codesign --verify`.
/// Nothing is ever installed without the user clicking "Install".
final class Updater {
    static let shared = Updater()

    /// Ed25519 public key (raw, base64) matching the release signing key.
    static let publicKey = "W9DiKuEBMheGcoICV6gJz2NhDZznVwTt7k9Gtuz9sZY="
    static let manifestURL = URL(string: "https://github.com/Pierrickgard/daylog/releases/latest/download/update.json")!
    static let releasesPage = URL(string: "https://github.com/Pierrickgard/daylog/releases/latest")!
    private static let downloadPrefix = "https://github.com/Pierrickgard/daylog/releases/download/"
    private static let maxZipSize = 50 * 1024 * 1024

    struct Release: Decodable {
        let version: String
        let url: String
        let sha256: String
        let size: Int
    }

    enum Status {
        case idle, checking, upToDate, installing
        case available(Release)
        case failed(String)
    }

    private(set) var status: Status = .idle
    var onChange: (() -> Void)?

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.httpCookieStorage = nil
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private func set(_ status: Status) {
        DispatchQueue.main.async {
            self.status = status
            self.onChange?()
        }
    }

    // MARK: Checking

    /// Checks at launch, then every few hours if the last check is more than a day old.
    func startAutomaticChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.checkIfDue() }
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in self.checkIfDue() }
    }

    private func checkIfDue() {
        guard Preferences.checkForUpdates else { return }
        if let last = Preferences.lastUpdateCheck, Date().timeIntervalSince(last) < 20 * 3600 { return }
        check(manual: false)
    }

    /// Automatic checks stay silent on errors (offline, no release yet); manual ones report them.
    func check(manual: Bool = true) {
        if case .installing = status { return }
        set(.checking)
        Task {
            do {
                Preferences.lastUpdateCheck = Date()
                let release = try await fetchVerifiedManifest()
                if Self.isNewer(release.version, than: Self.currentVersion) {
                    set(.available(release))
                } else {
                    set(.upToDate)
                }
            } catch {
                set(manual ? .failed(error.localizedDescription) : .idle)
            }
        }
    }

    private func fetchVerifiedManifest() async throws -> Release {
        let manifest = try await get(Self.manifestURL, limit: 64 * 1024)
        let signature = try await get(Self.manifestURL.appendingPathExtension("sig"), limit: 1024)
        guard Self.verify(manifest, signature: signature) else { throw UpdateError.badSignature }
        let release = try JSONDecoder().decode(Release.self, from: manifest)
        guard release.url.hasPrefix(Self.downloadPrefix), URL(string: release.url) != nil,
              release.size > 0, release.size <= Self.maxZipSize,
              release.sha256.count == 64 else { throw UpdateError.badManifest }
        return release
    }

    private func get(_ url: URL, limit: Int) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw UpdateError.notFound }
        guard data.count <= limit else { throw UpdateError.badManifest }
        return data
    }

    static func verify(_ data: Data, signature: Data) -> Bool {
        guard let keyData = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let text = String(data: signature, encoding: .utf8),
              let sig = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return key.isValidSignature(sig, for: data)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: Installing

    func install() {
        guard case .available(let release) = status else { return }
        set(.installing)
        Task {
            do {
                try await download(release)
            } catch {
                set(.failed(error.localizedDescription))
            }
        }
    }

    private func download(_ release: Release) async throws {
        let fm = FileManager.default
        let current = Bundle.main.bundleURL
        guard current.pathExtension == "app",
              fm.isWritableFile(atPath: current.deletingLastPathComponent().path) else { throw UpdateError.notWritable }

        let (tempZip, response) = try await session.download(from: URL(string: release.url)!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw UpdateError.notFound }
        let zip = try Data(contentsOf: tempZip)
        try? fm.removeItem(at: tempZip)
        guard zip.count == release.size,
              SHA256.hash(data: zip).map({ String(format: "%02x", $0) }).joined() == release.sha256.lowercased()
        else { throw UpdateError.badDownload }

        let work = fm.temporaryDirectory.appendingPathComponent("daylog-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        let zipURL = work.appendingPathComponent("Daylog.zip")
        try zip.write(to: zipURL)
        let unzipped = work.appendingPathComponent("unzipped")
        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, unzipped.path])

        let newApp = unzipped.appendingPathComponent("Daylog.app")
        guard let info = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == release.version else { throw UpdateError.badDownload }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path])

        _ = try fm.replaceItemAt(current, withItemAt: newApp)
        relaunch(current)
    }

    private func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw UpdateError.badDownload }
    }

    private func relaunch(_ app: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path]
        try? p.run()
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    enum UpdateError: LocalizedError {
        case badSignature, badManifest, badDownload, notFound, notWritable

        var errorDescription: String? {
            switch self {
            case .badSignature: return L10n.t("The update isn't signed by Daylog's key. Nothing was installed.",
                                              "La mise à jour n'est pas signée par la clé de Daylog. Rien n'a été installé.")
            case .badManifest: return L10n.t("The update information is invalid.", "Les informations de mise à jour sont invalides.")
            case .badDownload: return L10n.t("The downloaded update failed verification. Nothing was installed.",
                                             "Le téléchargement n'a pas passé la vérification. Rien n'a été installé.")
            case .notFound: return L10n.t("Couldn't reach the update server.", "Impossible de joindre le serveur de mises à jour.")
            case .notWritable: return L10n.t("Daylog can't replace itself here. Download the update from the releases page.",
                                             "Daylog ne peut pas se remplacer ici. Télécharge la mise à jour depuis la page des versions.")
            }
        }
    }
}
