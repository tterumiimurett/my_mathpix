import AppKit
import Combine
import CryptoKit
import Foundation

/// Explicit development launch mode; it never falls back to the owner's stores.
struct Ticket06AcceptanceConfiguration {
    enum Service: String {
        case live, failure, timeout, malformed
    }

    let runID: UUID
    let service: Service

    static func parse(_ arguments: [String]) throws -> Self? {
        let options = arguments.dropFirst().filter { $0.hasPrefix("--ticket06") }
        guard !options.isEmpty else { return nil }
        let ids = options.filter { $0.hasPrefix("--ticket06-acceptance=") }
        let services = options.filter { $0.hasPrefix("--ticket06-service=") }
        guard ids.count == 1, services.count <= 1,
              ids.count + services.count == options.count,
              !arguments.contains(where: {
                  ($0.hasPrefix("--ticket") && !$0.hasPrefix("--ticket06-"))
                      || $0 == "--self-test" || $0.hasPrefix("--golden-set-")
              }),
              let rawID = ids.first?.dropFirst("--ticket06-acceptance=".count),
              let id = UUID(uuidString: String(rawID)),
              id.uuidString.lowercased() == rawID.lowercased(),
              let service = Service(rawValue: services.first.map {
                  String($0.dropFirst("--ticket06-service=".count))
              } ?? "live") else { throw ConfigurationError.invalid }
        return Self(runID: id, service: service)
    }

    var rootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMathpix/Ticket06Acceptance", isDirectory: true)
            .appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
    }

    var defaultsName: String { "com.byterumi.mymathpix.ticket06.\(runID.uuidString.lowercased())" }

    enum ConfigurationError: Error { case invalid }
}

@MainActor
enum Ticket06Acceptance {
    private static var observation: AnyCancellable?

    static func makeModel(
        configuration: Ticket06AcceptanceConfiguration,
        appInteractionEnabled: Bool = true
    ) throws -> AppModel {
        let root = configuration.rootURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        guard let defaults = UserDefaults(suiteName: configuration.defaultsName) else {
            throw Ticket06AcceptanceConfiguration.ConfigurationError.invalid
        }
        let recognitionService: any RecognitionService
        var recognitionConfiguration: (any RecognitionConfiguration)? = nil
        switch configuration.service {
        case .live:
            let live = LiveRecognitionService()
            recognitionService = live
            recognitionConfiguration = live
        case .failure:
            recognitionService = Ticket06MockRecognitionService(scenario: .serviceFailure)
        case .timeout:
            recognitionService = Ticket06MockRecognitionService(scenario: .processingForever)
        case .malformed:
            recognitionService = Ticket06MockRecognitionService(scenario: .malformedPollJSON)
        }
        let model = AppModel(
            recognitionService: recognitionService,
            recognitionConfiguration: recognitionConfiguration,
            history: HistoryStore(rootURL: root.appendingPathComponent("History", isDirectory: true)),
            usageRecords: UsageRecordStore(rootURL: root.appendingPathComponent("Usage", isDirectory: true)),
            defaults: defaults,
            launchAtLoginController: Ticket06LoginItems(),
            diagnosticLog: DiagnosticLog(rootURL: root.appendingPathComponent("Diagnostics", isDirectory: true)),
            appInteractionEnabled: appInteractionEnabled
        )
        try writeObservation(model: model, configuration: configuration)
        observation = model.objectWillChange.sink { [weak model] _ in
            DispatchQueue.main.async {
                guard let model else { return }
                try? writeObservation(model: model, configuration: configuration)
            }
        }
        return model
    }

    private static func writeObservation(model: AppModel, configuration: Ticket06AcceptanceConfiguration) throws {
        let selected = model.selectedItem
        let source = (selected?.markdown ?? "") + "\0" + (selected?.html ?? "")
        let report: [String: Any] = [
            "schema": 1,
            "runID": configuration.runID.uuidString.lowercased(),
            "processID": ProcessInfo.processInfo.processIdentifier,
            "service": configuration.service.rawValue,
            "historyCount": model.history.items.count,
            "usageRecordCount": model.usageRecords.records.count,
            "isProcessing": model.isProcessing,
            "selectedStatus": selected?.status.rawValue ?? "none",
            "selectedMode": selected?.mode.rawValue ?? "none",
            "selectedSourceSHA256": SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined(),
            "selectedImageRetained": selected.flatMap { model.history.imageData(for: $0) } != nil,
            "allImagesRetained": model.history.items.allSatisfy { model.history.imageData(for: $0) != nil },
            "scope": "Disposable UUID history/usage/defaults. No destination or GUI acceptance asserted."
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configuration.rootURL.appendingPathComponent("session.json"), options: .atomic)
    }
}

@MainActor
private final class Ticket06MockRecognitionService: RecognitionService {
    private let scenario: Ticket02MockURLProtocol.Scenario

    init(scenario: Ticket02MockURLProtocol.Scenario) { self.scenario = scenario }

    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        let client = DatalabClient(
            session: Ticket02MockURLProtocol.makeSession(scenario: scenario, expectedPNG: uploadPayload.pngData),
            policy: DatalabClient.Policy(timeout: .seconds(7))
        )
        return try await client.recognize(
            pngData: uploadPayload.pngData, token: "ticket06-non-secret-sentinel", mode: mode
        )
    }
}

@MainActor
private final class Ticket06LoginItems: LaunchAtLoginControlling {
    let isEnabled = false
    func setEnabled(_ enabled: Bool) throws {
        throw AppError.service("Login items are unavailable in this isolated acceptance run.")
    }
}
