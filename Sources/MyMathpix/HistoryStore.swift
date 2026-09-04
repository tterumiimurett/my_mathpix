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
        try writeImage(uploadPayload.pngData, named: filename)
        let item = HistoryItem(imageFilename: filename)
        let priorItems = items
        let nextItems = Array(([item] + priorItems).prefix(20))
        let evicted = ([item] + priorItems).dropFirst(20).first
        var evictedImage: Data?
        do {
            if let evicted {
                evictedImage = try removeImage(named: evicted.imageFilename)
            }
            items = nextItems
            try persist()
        } catch {
            items = priorItems
            _ = try? removeImage(named: filename)
            if let evicted, let evictedImage {
                try? writeImage(evictedImage, named: evicted.imageFilename)
            }
            throw error
        }
        return item
    }

    func update(_ item: HistoryItem) throws {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let priorItems = items
        var changed = item
        changed.updatedAt = Date()
        items[index] = changed
        do {
            try persist()
        } catch {
            items = priorItems
            throw error
        }
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
        let priorItems = items
        let removedImage = try removeImage(named: item.imageFilename)
        items.removeAll { $0.id == id }
        do {
            try persist()
        } catch {
            items = priorItems
            if let removedImage {
                try? writeImage(removedImage, named: item.imageFilename)
            }
            throw error
        }
    }

    func clear() throws {
        let priorItems = items
        var removedImages: [String: Data] = [:]
        do {
            for item in priorItems {
                if let data = try removeImage(named: item.imageFilename) {
                    removedImages[item.imageFilename] = data
                }
            }
        } catch {
            restoreImages(removedImages)
            throw error
        }
        items = []
        do {
            try persist()
        } catch {
            items = priorItems
            restoreImages(removedImages)
            throw error
        }
    }

    private func writeImage(_ data: Data, named filename: String) throws {
        if inMemory {
            inMemoryImages[filename] = data
            return
        }
        let url = rootURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }

    @discardableResult
    private func removeImage(named filename: String) throws -> Data? {
        if inMemory {
            return inMemoryImages.removeValue(forKey: filename)
        }
        let url = rootURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        return data
    }

    private func removeImagesBestEffort(for removed: ArraySlice<HistoryItem>) {
        for item in removed {
            _ = try? removeImage(named: item.imageFilename)
        }
    }

    private func restoreImages(_ images: [String: Data]) {
        for (filename, data) in images {
            try? writeImage(data, named: filename)
        }
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
            let decoded = try decoder.decode([HistoryItem].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            var needsPersist = decoded.count > 20
            let recovered = decoded.map { item in
                guard item.status == .processing else { return item }
                var failed = item
                failed.status = .failed
                failed.errorMessage = "Recognition was interrupted when MyMathpix closed. Retry this Failed Record to reuse the original Snippet."
                failed.updatedAt = Date()
                needsPersist = true
                return failed
            }
            items = Array(recovered.prefix(20))
            removeImagesBestEffort(for: decoded.dropFirst(20))
            if needsPersist { try? persist() }
        } catch {
            items = []
        }
    }

    private func persist() throws {
        if inMemory { return }
        try ensureDirectory()
        try encoder.encode(items).write(to: indexURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: indexURL.path
        )
    }
}
