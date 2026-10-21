import Foundation

enum Ticket01Scenario: String, CaseIterable, Codable, Equatable, Sendable {
    case permissionNotDetermined = "permission-not-determined"
    case permissionDenied = "permission-denied"
    case permissionRevoked = "permission-revoked"
    case captureAPIFailure = "capture-api-failure"
    case displayDisappearance = "display-disappearance"
    case cancellation
    case tinySelection = "tiny-selection"
}

enum Ticket01AcceptanceRelaunchMode: Equatable, Sendable {
    case acceptance(runID: UUID)
    case scenario(Ticket01Scenario, runID: UUID)

    var runID: UUID {
        switch self {
        case .acceptance(let runID), .scenario(_, let runID):
            return runID
        }
    }

    static func parse(_ text: String) -> Self? {
        let components = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if components.count == 2,
           components[0] == "acceptance",
           let runID = UUID(uuidString: components[1]) {
            return .acceptance(runID: runID)
        }
        if components.count == 3,
           components[0] == "scenario",
           let scenario = Ticket01Scenario(rawValue: components[1]),
           let runID = UUID(uuidString: components[2]) {
            return .scenario(scenario, runID: runID)
        }
        return nil
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

    static func consume(fileManager: FileManager = .default) -> Ticket01AcceptanceRelaunchMode? {
        consume(
            from: storageURL(fileManager: fileManager),
            now: Date(),
            fileManager: fileManager
        )
    }

    static func consume(
        from url: URL,
        now: Date,
        fileManager: FileManager = .default
    ) -> Ticket01AcceptanceRelaunchMode? {
        guard let mode = load(from: url, now: now, fileManager: fileManager) else {
            return nil
        }
        do {
            try fileManager.removeItem(at: url)
            return mode
        } catch {
            return nil
        }
    }
}

struct AppLaunchConfiguration {
    let arguments: [String]
    let acceptanceRelaunchMode: Ticket01AcceptanceRelaunchMode?

    init(
        arguments: [String],
        acceptanceRelaunchMode: Ticket01AcceptanceRelaunchMode? = nil
    ) {
        self.arguments = arguments
        self.acceptanceRelaunchMode = acceptanceRelaunchMode
    }

    static func current(arguments: [String]) -> Self {
        let explicitRunID = argumentValue(named: "--ticket01-run-id=", in: arguments)
            .flatMap(UUID.init(uuidString:))
        if arguments.contains("--ticket01-acceptance"), explicitRunID != nil {
            return Self(arguments: arguments, acceptanceRelaunchMode: nil)
        }
        return Self(
            arguments: arguments,
            acceptanceRelaunchMode: Ticket01AcceptanceRelaunchMarker.consume()
        )
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

    var runsTicket02RecognitionSelfTest: Bool {
        arguments.contains("--ticket02-recognition-self-test")
    }

    var runsSelfTest: Bool {
        arguments.contains("--self-test")
    }

    var runsTicket04DailyWorkflowSelfTest: Bool {
        arguments.contains("--ticket04-daily-workflow-self-test")
    }

    var runsTicket04ResultEditorWindowSelfTest: Bool {
        arguments.contains("--ticket04-result-editor-window-self-test")
    }

    var runsTicket03SelfTest: Bool {
        arguments.contains("--ticket03-self-test")
    }

    var runsTicket03Acceptance: Bool {
        ticket03AcceptanceRunID != nil
    }

    var ticket03AcceptanceRunID: UUID? {
        guard arguments.contains("--ticket03-acceptance"),
              let rawValue = Self.argumentValue(named: "--ticket03-run-id=", in: arguments) else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    var ticket03PasteboardInspection: CopyFormat? {
        Self.argumentValue(named: "--ticket03-inspect-pasteboard=", in: arguments)
            .flatMap(CopyFormat.init(rawValue:))
    }

    var reportsScreenPermissionState: Bool {
        arguments.contains("--ticket01-screen-permission-state")
    }

    var runsTicket01Acceptance: Bool {
        acceptanceRunID != nil
    }

    var ticket01Scenario: Ticket01Scenario? {
        let prefix = "--ticket01-scenario="
        if explicitAcceptanceRunID != nil,
           let rawValue = Self.argumentValue(named: prefix, in: arguments) {
            return Ticket01Scenario(rawValue: rawValue)
        }
        guard case let .scenario(scenario, _) = acceptanceRelaunchMode else { return nil }
        return scenario
    }

    var acceptanceRunID: UUID? {
        explicitAcceptanceRunID ?? acceptanceRelaunchMode?.runID
    }

    private var explicitAcceptanceRunID: UUID? {
        guard arguments.contains("--ticket01-acceptance"),
              let rawValue = Self.argumentValue(named: "--ticket01-run-id=", in: arguments) else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    private static func argumentValue(named prefix: String, in arguments: [String]) -> String? {
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return String(argument.dropFirst(prefix.count))
    }
}
