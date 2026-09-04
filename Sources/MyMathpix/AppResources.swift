import Foundation

enum AppResources {
    static var directoryURL: URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let packaged = resourceURL
                .appendingPathComponent("MyMathpix_MyMathpix.bundle", isDirectory: true)
                .appendingPathComponent("Resources", isDirectory: true)
            if hasCompletePreviewAssets(at: packaged) {
                return packaged
            }
        }
        if Bundle.main.bundleURL.pathExtension == "app" {
            return nil
        }
        return Bundle.module.url(forResource: "Resources", withExtension: nil)
    }

    static func hasCompletePreviewAssets(at directory: URL) -> Bool {
        let requiredFiles: [(path: String, minimumBytes: Int)] = [
            ("katex.min.css", 10_000),
            ("katex.min.js", 100_000),
            ("KATEX-LICENSE.txt", 100),
            ("fonts/KaTeX_Main-Regular.woff2", 1_000)
        ]
        return requiredFiles.allSatisfy { requirement in
            let url = directory.appendingPathComponent(requirement.path)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? NSNumber else { return false }
            return size.intValue >= requirement.minimumBytes
        }
    }
}
