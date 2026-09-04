import AppKit
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var items: [HistoryItem] = []

    private let rootURL: URL
    private let indexURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let inMemory: Bool
    private var inMemoryImages: [String: Data] = [:]

    init(rootURL: URL? = nil, inMemory: Bool = false) {
        let base = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMathpix", isDirectory: true)
        self.rootURL = base
        self.indexURL = base.appendingPathComponent("history.json")
        self.inMemory = inMemory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func create(uploadPayload: UploadPayload) throws -> HistoryItem {
        try ensureDirectory()
        let filename = "\(UUID().uuidString).png"
        if inMemory {
            inMemoryImages[filename] = uploadPayload.pngData
        } else {
            try uploadPayload.pngData.write(to: rootURL.appendingPathComponent(filename), options: .atomic)
        }
        let item = HistoryItem(imageFilename: filename)
        items.insert(item, at: 0)
        trimToLimit()
        try persist()
        return item
    }

    func update(_ item: HistoryItem) throws {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var changed = item
        changed.updatedAt = Date()
        items[index] = changed
        try persist()
    }

    func item(id: UUID?) -> HistoryItem? {
        guard let id else { return nil }
        return items.first(where: { $0.id == id })
    }

    func imageData(for item: HistoryItem) -> Data? {
        if inMemory { return inMemoryImages[item.imageFilename] }
        return try? Data(contentsOf: rootURL.appendingPathComponent(item.imageFilename))
    }

    func image(for item: HistoryItem) -> NSImage? {
        imageData(for: item).flatMap(NSImage.init(data:))
    }

    func delete(id: UUID) throws {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if inMemory { inMemoryImages.removeValue(forKey: item.imageFilename) }
        else { try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(item.imageFilename)) }
        items.removeAll { $0.id == id }
        try persist()
    }

    func clear() throws {
        for item in items {
            if inMemory { inMemoryImages.removeValue(forKey: item.imageFilename) }
            else { try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(item.imageFilename)) }
        }
        items = []
        try persist()
    }

    private func ensureDirectory() throws {
        if inMemory { return }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func load() {
        guard !inMemory else {
            items = []
            return
        }
        do {
            try ensureDirectory()
            let data = try Data(contentsOf: indexURL)
            items = try decoder.decode([HistoryItem].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            trimToLimit()
        } catch {
            items = []
        }
    }

    private func trimToLimit() {
        guard items.count > 20 else { return }
        let removed = items.suffix(from: 20)
        for item in removed {
            if inMemory { inMemoryImages.removeValue(forKey: item.imageFilename) }
            else { try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(item.imageFilename)) }
        }
        items = Array(items.prefix(20))
    }

    private func persist() throws {
        if inMemory { return }
        try ensureDirectory()
        try encoder.encode(items).write(to: indexURL, options: .atomic)
    }
}
