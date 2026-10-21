import AppKit
import CryptoKit
import Foundation
import WebKit

/// Development-only, explicit command interface. Never touches production Recent History.
@MainActor
enum GoldenSetRunner {
    static func handles(_ arguments: [String]) -> Bool {
        arguments.contains { $0.hasPrefix("--golden-set-") }
    }

    static func runBlocking(arguments: [String]) -> Int32 {
        var outcome: Int32?
        Task { @MainActor in outcome = await run(arguments: arguments) }
        while outcome == nil {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return outcome ?? 1
    }

    private static func value(_ prefix: String, in arguments: [String]) -> String? {
        arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
    }

    private static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMathpix/GoldenSet", isDirectory: true)
    }

    private static func run(arguments: [String]) async -> Int32 {
        do {
            guard let resources = AppResources.directoryURL else { throw GoldenError.resources }
            let corpus = resources.appendingPathComponent("GoldenSet", isDirectory: true)
            let manifestData = try Data(contentsOf: corpus.appendingPathComponent("manifest.json"))
            guard var manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
                  var cases = manifest["cases"] as? [[String: Any]], cases.count == 80 else {
                throw GoldenError.manifest
            }
            if arguments.contains("--golden-set-render") {
                let output = root.appendingPathComponent("Corpus", isDirectory: true)
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                let snapshotter = GoldenSnapshotter(resources: resources)
                for index in cases.indices {
                    guard let id = cases[index]["id"] as? String,
                          let body = cases[index]["fixtureBody"] as? String else { throw GoldenError.manifest }
                    let document = try fixtureDocument(body: body, style: cases[index]["fixtureStyle"] as? String ?? "", resources: resources)
                    let png = try await snapshotter.png(document: document)
                    try png.write(to: output.appendingPathComponent(id + ".png"), options: .atomic)
                    cases[index]["inputSHA256"] = digest(png)
                    print("GOLDEN_RENDER case=\(id) bytes=\(png.count)")
                }
                manifest["cases"] = cases
                try write(manifest, to: output.appendingPathComponent("manifest.json"))
                print("GOLDEN_RENDER_COMPLETE cases=80 output=\(output.path)")
                return 0
            }
            guard let runID = value("--golden-set-run=", in: arguments),
                  !runID.isEmpty, runID.count < 80,
                  runID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
                throw GoldenError.arguments
            }
            let service = LiveRecognitionService()
            guard service.isConfigured else {
                print("GOLDEN_LIVE_BLOCKED credential=missing-or-unreadable")
                return 2
            }
            let output = root.appendingPathComponent("Runs/" + runID, isDirectory: true)
            let resultDirectory = output.appendingPathComponent("results", isDirectory: true)
            let previewDirectory = output.appendingPathComponent("previews", isDirectory: true)
            try FileManager.default.createDirectory(at: resultDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
            let configuration: [String: Any] = ["schema": 1, "corpusSHA256": digest(manifestData), "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unbundled", "policy": "fixed-case-order-fast-and-balanced-no-quality-retries", "runID": runID]
            let configurationURL = output.appendingPathComponent("configuration.json")
            if FileManager.default.fileExists(atPath: configurationURL.path) {
                let existing = try Data(contentsOf: configurationURL)
                guard let previous = try JSONSerialization.jsonObject(with: existing) as? NSDictionary,
                      previous == configuration as NSDictionary else { throw GoldenError.changedRun }
            } else { try write(configuration, to: configurationURL) }
            try manifestData.write(to: output.appendingPathComponent("manifest.json"), options: .atomic)
            let limit = value("--golden-set-limit=", in: arguments).flatMap(Int.init) ?? 160
            guard limit > 0, limit <= 160 else { throw GoldenError.arguments }
            let requestedMode = value("--golden-set-mode=", in: arguments)
            guard requestedMode == nil || RecognitionMode(rawValue: requestedMode!) != nil else { throw GoldenError.arguments }
            let snapshotter = GoldenSnapshotter(resources: resources)
            var attempted = 0
            for item in cases {
                guard let id = item["id"] as? String,
                      let inputHash = item["inputSHA256"] as? String, inputHash.count == 64 else { throw GoldenError.manifest }
                let png = try Data(contentsOf: corpus.appendingPathComponent(id + ".png"))
                guard digest(png) == inputHash else { throw GoldenError.changedInput }
                for mode in RecognitionMode.allCases where requestedMode == nil || mode.rawValue == requestedMode {
                    let resultURL = resultDirectory.appendingPathComponent(id + "-" + mode.rawValue + ".json")
                    if FileManager.default.fileExists(atPath: resultURL.path) {
                        let old = try JSONSerialization.jsonObject(with: Data(contentsOf: resultURL)) as? [String: Any]
                        guard old?["inputSHA256"] as? String == inputHash else { throw GoldenError.changedInput }
                        continue
                    }
                    if attempted >= limit {
                        print("GOLDEN_LIVE_PAUSED newAttempts=\(attempted) output=\(output.path)")
                        return 0
                    }
                    let start = Date()
                    var record: [String: Any] = ["schema": 1, "caseID": id, "mode": mode.rawValue, "inputSHA256": inputHash, "startedAt": ISO8601DateFormatter().string(from: start)]
                    do {
                        let result = try await service.recognize(uploadPayload: UploadPayload(pngData: png), mode: mode)
                        let canonical = MarkdownNormalizer.normalize(result.markdown)
                        let safeHTML = result.html.flatMap { ComplexTableOutputSanitizer.sanitize($0)?.html }
                        record["status"] = "complete"
                        record["canonicalMarkdown"] = canonical
                        record["complexTableHTML"] = safeHTML ?? NSNull()
                        record["outputSHA256"] = digest(Data((canonical + "\0" + (safeHTML ?? "")).utf8))
                        record["runtimeSeconds"] = result.runtime ?? NSNull()
                        record["costCents"] = result.costValue ?? NSNull()
                        record["costBreakdownJSON"] = result.costSummary ?? NSNull()
                        record["automaticRetryCount"] = result.automaticRetryCount
                        record["wallSeconds"] = Date().timeIntervalSince(start)
                        // Save the actual service result before preview/clipboard work; resume cannot spend again.
                        try write(record, to: resultURL)
                        let consumption = try await consumptionEvidence(canonical: canonical, safeHTML: safeHTML, png: png, snapshotter: snapshotter, stem: id + "-" + mode.rawValue, output: previewDirectory)
                        record["consumption"] = consumption
                    } catch {
                        if record["status"] == nil {
                            record["status"] = "failed"
                            record["errorCode"] = (error as? AppError)?.diagnosticCode.rawValue ?? "recognition_or_local_io_failure"
                            record["outputSHA256"] = NSNull()
                            record["wallSeconds"] = Date().timeIntervalSince(start)
                        } else { record["consumptionError"] = "preview_or_clipboard_failed" }
                    }
                    try write(record, to: resultURL)
                    attempted += 1
                    let cost = record["costCents"] as? Double
                    let costText = cost.map { String(format: "%.4f", $0) } ?? "unknown"
                    print("GOLDEN_LIVE case=\(id) mode=\(mode.rawValue) status=\(record["status"] as? String ?? "failed") wall=\(String(format: "%.2f", Date().timeIntervalSince(start))) costCents=\(costText)")
                }
            }
            print("GOLDEN_LIVE_COMPLETE newAttempts=\(attempted) output=\(output.path)")
            return 0
        } catch {
            // Fixed codes only: service messages and credentials never enter console artifacts.
            print("GOLDEN_COMMAND_FAILED code=\((error as? GoldenError)?.rawValue ?? "local_io_or_render")")
            return 1
        }
    }

    private static func consumptionEvidence(canonical: String, safeHTML: String?, png: Data, snapshotter: GoldenSnapshotter, stem: String, output: URL) async throws -> [String: Any] {
        let document = MarkdownRenderer.document(for: canonical, complexTableHTML: safeHTML)
        let preview = try await snapshotter.png(document: document)
        try preview.write(to: output.appendingPathComponent(stem + ".png"), options: .atomic)
        try Data(document.utf8).write(to: output.appendingPathComponent(stem + ".html"), options: .atomic)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        var values: [String: Any] = [:]
        let payload = ClipboardPayload(canonicalMarkdown: canonical, complexTableHTML: safeHTML, originalPNG: png)
        for name in ["markdown", "lark", "notion", "tsvTable", "richTable"] {
            guard let format = CopyFormat(rawValue: name), ClipboardService.unavailability(of: format, payload: payload) == nil else { continue }
            do {
                try ClipboardService.copy(format, payload: payload, to: board)
                var representation: [String: Any] = ["types": (board.types ?? []).map(\.rawValue)]
                representation["plain"] = board.string(forType: .string) ?? ""
                representation["html"] = board.string(forType: .html) ?? NSNull()
                representation["tsv"] = board.string(forType: .tabularText) ?? NSNull()
                values[name] = representation
            } catch { values[name] = ["error": "clipboard_failed"] }
        }
        let correction = canonical + "\n\nCorrection check."
        let corrected = MarkdownRenderer.document(for: correction, complexTableHTML: safeHTML)
        _ = try await snapshotter.png(document: corrected)
        try ClipboardService.copy(.markdown, payload: ClipboardPayload(canonicalMarkdown: correction, complexTableHTML: safeHTML, originalPNG: png), to: board)
        return ["previewPNG": stem + ".png", "clipboard": values, "correctionMarkdownCopied": board.string(forType: .string) == correction, "correctedPreviewContainsMarker": corrected.contains("Correction check."), "destinationAcceptance": "Not performed by batch runner; Notion inline math is a known deferred defect"]
    }

    private static func fixtureDocument(body: String, style: String, resources: URL) throws -> String {
        let css = try String(contentsOf: resources.appendingPathComponent("katex.min.css"), encoding: .utf8)
        let js = try String(contentsOf: resources.appendingPathComponent("katex.min.js"), encoding: .utf8)
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; connect-src 'none'; font-src file: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'"><style>\(css)
        html{background:white;color:black;}body{font:24px -apple-system,sans-serif;margin:0;padding:28px;line-height:1.6;width:744px;}table{border-collapse:collapse;width:100%;margin:16px 0;}th,td{border:1px solid #444;padding:9px 12px;text-align:left;}th{background:#eee;}p{margin:14px 0;}.display{margin:18px 0;}\(style)</style></head><body>\(body)<script>\(js)
        document.querySelectorAll('[data-tex]').forEach(el=>katex.render(el.dataset.tex,el,{displayMode:el.dataset.display==='1',throwOnError:true}));</script></body></html>
        """
    }

    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func write(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }
    private enum GoldenError: String, Error { case resources, manifest, arguments, changedRun, changedInput }
}

@MainActor
private final class GoldenSnapshotter: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let window: NSWindow
    let resources: URL
    var navigation: CheckedContinuation<Void, Error>?

    init(resources: URL) {
        self.resources = resources
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        window = NSWindow(contentRect: webView.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        webView.navigationDelegate = self
        webView.appearance = NSAppearance(named: .aqua)
        window.contentView = webView
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
    }

    func png(document: String) async throws -> Data {
        webView.setFrameSize(NSSize(width: 800, height: 600))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            navigation = continuation
            webView.loadHTMLString(document, baseURL: resources)
        }
        _ = try await webView.callAsyncJavaScript("await document.fonts.ready; return true;", arguments: [:], in: nil, contentWorld: .page)
        let height = try await webView.evaluateJavaScript("Math.max(120,document.body.scrollHeight)") as? Double ?? 600
        webView.setFrameSize(NSSize(width: 800, height: min(1600, height)))
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        config.snapshotWidth = 1600
        let image = try await webView.takeSnapshot(configuration: config)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return png
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { self.navigation?.resume(); self.navigation = nil }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { self.navigation?.resume(throwing: error); self.navigation = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { self.navigation?.resume(throwing: error); self.navigation = nil }
}
