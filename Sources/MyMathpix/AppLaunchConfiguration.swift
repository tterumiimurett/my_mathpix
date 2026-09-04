import Foundation

enum Ticket01AcceptanceRelaunchMode: Equatable, Sendable {
    case acceptance
    case scenario(String)

    static func parse(_ text: String) -> Self? {
        if text == "acceptance" { return .acceptance }

        let prefix = "scenario:"
        guard text.hasPrefix(prefix) else { return nil }
        let rawScenario = String(text.dropFirst(prefix.count))
        guard AppLaunchConfiguration.Ticket01Scenario(rawValue: rawScenario) != nil else {
            return nil
        }
        return .scenario(rawScenario)
    }
}

enum Ticket01AcceptanceRelaunchMarker {
    private static let maximumAge: TimeInterval = 15 * 60

    static func load(
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> Ticket01AcceptanceRelaunchMode? {
        load(
            from: storageURL(fileManager: fileManager),
            now: now,
            fileManager: fileManager
        )
    }

    static func load(
        from url: URL,
        now: Date,
        fileManager: FileManager = .default
    ) -> Ticket01AcceptanceRelaunchMode? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = (attributes[.size] as? NSNumber)?.intValue,
              size > 0,
              size <= 128,
              let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue,
              permissions & 0o077 == 0,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        let age = now.timeIntervalSince(modificationDate)
        guard age >= -5, age <= maximumAge,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return Ticket01AcceptanceRelaunchMode.parse(
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func storageURL(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMathpix/Ticket01Acceptance", isDirectory: true)
            .appendingPathComponent("relaunch-mode.txt")
    }
}

struct AppLaunchConfiguration {
    enum Ticket01Scenario: String, CaseIterable {
        case permissionNotDetermined = "permission-not-determined"
        case permissionDenied = "permission-denied"
        case permissionRevoked = "permission-revoked"
        case captureAPIFailure = "capture-api-failure"
        case displayDisappearance = "display-disappearance"
        case cancellation
        case tinySelection = "tiny-selection"
    }

    let arguments: [String]
    let acceptanceRelaunchMode: Ticket01AcceptanceRelaunchMode?

    init(
        arguments: [String],
        acceptanceRelaunchMode: Ticket01AcceptanceRelaunchMode? = Ticket01AcceptanceRelaunchMarker.load()
    ) {
        self.arguments = arguments
        self.acceptanceRelaunchMode = acceptanceRelaunchMode
    }

    var runsTicket01MockSelfTest: Bool {
        arguments.contains("--ticket01-mock-recognition-self-test")
    }

    var runsResourceBundleSelfTest: Bool {
        arguments.contains("--ticket01-resource-bundle-self-test")
    }

    var runsOverlayLifecycleSelfTest: Bool {
        arguments.contains("--ticket01-overlay-lifecycle-self-test")
    }

    var runsLocalTokenStoreSelfTest: Bool {
        arguments.contains("--ticket01-local-token-self-test")
    }

    var runsSelfTest: Bool {
        arguments.contains("--self-test")
    }

    var runsTicket01Acceptance: Bool {
        arguments.contains("--ticket01-acceptance") || acceptanceRelaunchMode != nil
    }

    var ticket01Scenario: Ticket01Scenario? {
        let prefix = "--ticket01-scenario="
        if let argument = arguments.first(where: { $0.hasPrefix(prefix) }) {
            return Ticket01Scenario(rawValue: String(argument.dropFirst(prefix.count)))
        }
        guard case let .scenario(rawValue) = acceptanceRelaunchMode else { return nil }
        return Ticket01Scenario(rawValue: rawValue)
    }
}
