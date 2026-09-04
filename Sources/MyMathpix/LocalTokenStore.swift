import Foundation
import Darwin

struct LocalTokenStore {
    let storageURL: URL
    private let rootURL: URL

    init(rootURL: URL? = nil) {
        let root = rootURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MyMathpix", isDirectory: true)
        self.rootURL = root
        self.storageURL = root.appendingPathComponent("datalab-token.txt")
    }

    func readToken() -> String? {
        guard hasPrivatePermissions,
              let data = try? Data(contentsOf: storageURL),
              let value = String(data: data, encoding: .utf8) else { return nil }
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    func saveToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if FileManager.default.fileExists(atPath: storageURL.path) {
                try FileManager.default.removeItem(at: storageURL)
            }
            return
        }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: rootURL.path
        )
        let temporaryURL = rootURL.appendingPathComponent(
            ".datalab-token-\(UUID().uuidString).tmp"
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        let created = FileManager.default.createFile(
            atPath: temporaryURL.path,
            contents: Data(trimmed.utf8),
            attributes: [.posixPermissions: NSNumber(value: Int16(0o600))]
        )
        guard created else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: temporaryURL.path
        )
        guard hasPrivatePermissions(at: temporaryURL) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let renameResult = temporaryURL.path.withCString { source in
            storageURL.path.withCString { destination in
                Darwin.rename(source, destination)
            }
        }
        guard renameResult == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        guard hasPrivatePermissions else {
            try? FileManager.default.removeItem(at: storageURL)
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    var hasPrivatePermissions: Bool {
        hasPrivatePermissions(at: storageURL)
    }

    private func hasPrivatePermissions(at url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let permissions = attributes[.posixPermissions] as? NSNumber,
              let owner = attributes[.ownerAccountID] as? NSNumber else {
            return false
        }
        return permissions.intValue & 0o777 == 0o600
            && owner.uint32Value == getuid()
    }
}

enum Ticket01LocalTokenStoreSelfTest {
    static func run() -> Bool {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("MyMathpix", isDirectory: true)
        .appendingPathComponent("Ticket01LocalTokenSelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalTokenStore(rootURL: root)
        do {
            guard store.readToken() == nil else { return false }
            try store.saveToken("ticket01-signed-local-non-secret")
            guard store.readToken() == "ticket01-signed-local-non-secret",
                  store.hasPrivatePermissions else { return false }
            try store.saveToken("ticket01-signed-local-replacement-non-secret")
            guard store.readToken() == "ticket01-signed-local-replacement-non-secret" else {
                return false
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o644))],
                ofItemAtPath: store.storageURL.path
            )
            guard store.readToken() == nil else { return false }
            try store.saveToken("ticket01-signed-local-repaired-non-secret")
            guard store.hasPrivatePermissions else { return false }
            try store.saveToken("")
            return store.readToken() == nil
        } catch {
            return false
        }
    }
}
