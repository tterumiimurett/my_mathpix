import Combine
import Foundation

enum DiagnosticEventCode: String, Codable, CaseIterable {
    case appLaunched = "app_launched"
    case captureStarted = "capture_started"
    case captureCancelled = "capture_cancelled"
    case captureFailed = "capture_failed"
    case recognitionStarted = "recognition_started"
    case recognitionCompleted = "recognition_completed"
    case recognitionFailed = "recognition_failed"
    case historyItemDeleted = "history_item_deleted"
    case historyCleared = "history_cleared"
    case shortcutUpdated = "shortcut_updated"
    case shortcutConflict = "shortcut_conflict"
    case launchAtLoginEnabled = "launch_at_login_enabled"
    case launchAtLoginDisabled = "launch_at_login_disabled"
}

struct DiagnosticEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let code: DiagnosticEventCode
    let mode: RecognitionMode?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        code: DiagnosticEventCode,
        mode: RecognitionMode? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.code = code
        self.mode = mode
    }
}

@MainActor
final class DiagnosticLog: ObservableObject {
    static let maximumEntryCount = 200

    @Published private(set) var entries: [DiagnosticEvent] = []

    private let rootURL: URL
    private let storageURL: URL
    private let now: () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        rootURL: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        let root = rootURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("MyMathpix", isDirectory: true)
        .appendingPathComponent("Diagnostics", isDirectory: true)
        self.rootURL = root
        self.storageURL = root.appendingPathComponent("events.json")
        self.now = now
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func record(_ code: DiagnosticEventCode, mode: RecognitionMode? = nil) throws {
        entries.append(DiagnosticEvent(timestamp: now(), code: code, mode: mode))
        if entries.count > Self.maximumEntryCount {
            entries.removeFirst(entries.count - Self.maximumEntryCount)
        }
        try persist()
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }
        entries = []
    }

    func exportData(
        version: AppVersionInfo = .current,
        operatingSystem: String = ProcessInfo.processInfo.operatingSystemVersionString
    ) throws -> Data {
        var lines = [
            "MyMathpix Diagnostics",
            "Version: \(version.displayName)",
            "Operating System: \(operatingSystem)",
            "Events: \(entries.count)"
        ]
        let formatter = ISO8601DateFormatter()
        for event in entries {
            var line = "\(formatter.string(from: event.timestamp)) \(event.code.rawValue)"
            if let mode = event.mode {
                line += " mode=\(mode.rawValue)"
            }
            lines.append(line)
        }
        lines.append("")
        return Data(lines.joined(separator: "\n").utf8)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? decoder.decode([DiagnosticEvent].self, from: data) else {
            entries = []
            return
        }
        entries = Array(decoded.suffix(Self.maximumEntryCount))
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o700))],
            ofItemAtPath: rootURL.path
        )
        try encoder.encode(entries).write(to: storageURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: storageURL.path
        )
    }
}
