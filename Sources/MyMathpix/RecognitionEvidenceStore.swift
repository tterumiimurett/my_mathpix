import Foundation

enum RecognitionAttemptOutcome: String, Codable, Equatable {
    case complete
    case failed
    case cancelled
}

struct RecognitionAttemptEvidence: Codable, Equatable, Identifiable {
    let id: UUID
    let historyItemID: UUID
    let startedAt: TimeInterval
    let finishedAt: TimeInterval
    let mode: RecognitionMode
    let outcome: RecognitionAttemptOutcome
    let elapsedSeconds: Double
    let serviceRuntimeSeconds: Double?
    let costCents: Double?
    let parseQualityScore: Double?
    let automaticRetryCount: Int?
    let failureCode: String?
}

@MainActor
final class RecognitionEvidenceStore: ObservableObject {
    @Published private(set) var records: [RecognitionAttemptEvidence] = []

    private let rootURL: URL
    private let storageURL: URL
    private let inMemory: Bool

    init(rootURL: URL? = nil, inMemory: Bool = false) {
        let root = rootURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MyMathpix", isDirectory: true)
        self.rootURL = root
        self.storageURL = root.appendingPathComponent("recognition-evidence.json")
        self.inMemory = inMemory
        load()
    }

    func record(_ evidence: RecognitionAttemptEvidence) throws {
        records.append(evidence)
        if records.count > 200 {
            records.removeFirst(records.count - 200)
        }
        try persist()
    }

    func latest(for historyItemID: UUID) -> RecognitionAttemptEvidence? {
        records.last { $0.historyItemID == historyItemID }
    }

    private func load() {
        guard !inMemory,
              let data = try? Data(contentsOf: storageURL),
              let loaded = try? JSONDecoder().decode(
                  [RecognitionAttemptEvidence].self,
                  from: data
              ) else {
            records = []
            return
        }
        records = Array(loaded.suffix(200))
    }

    private func persist() throws {
        guard !inMemory else { return }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: storageURL, options: .atomic)
    }
}
