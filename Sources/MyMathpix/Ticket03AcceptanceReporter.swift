import Foundation

struct PreviewRenderObservation {
    let canonicalMarkdown: String
    let renderedFormulaVisible: Bool
    let renderedTableVisible: Bool
}

struct ResultEditorObservation {
    let originalSnippetVisible: Bool
    let canonicalMarkdown: String
    let copyFormatsVisible: Bool
    let nativePasteBoundaryVisible: Bool
    var canonicalMarkdownVisible = true
}

@MainActor
final class Ticket03AcceptanceReporter {
    enum Phase: String, Codable {
        case launched
        case editorVisible = "editor-visible"
        case initialPreview = "initial-preview"
        case editedPreview = "edited-preview"
        case pureFormulaPreview = "pure-formula-preview"
        case finalEditedPreview = "final-edited-preview"
        case complete
    }

    struct Evidence: Codable, Equatable {
        var schema = 1
        var acceptanceRunID = ""
        var processID = 0
        var phase = Phase.launched
        var resultEditorVisible = false
        var originalSnippetVisible = false
        var canonicalMarkdownVisible = false
        var copyFormatsVisible = false
        var nativePasteBoundaryVisible = false
        var initialPreviewVisible = false
        var editedSourceVisible = false
        var editedPreviewVisible = false
        var pureFormulaPreviewVisible = false
        var finalEditedPreviewVisible = false
        var renderedFormulaVisible = false
        var renderedTableVisible = false
        var offlinePolicyPresent = false
        var formulaOutputCopied = false
        var markdownCopied = false
        var combinedOutputCopied = false
        var tsvTableCopied = false
        var richTableCopied = false
        var originalImageCopied = false
        var notionCopied = false
        var larkCopied = false
    }

    private(set) var evidence = Evidence()
    private let evidenceURL: URL
    private let encoder: JSONEncoder

    init(runID: UUID) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMathpix/Ticket03Acceptance", isDirectory: true)
        evidenceURL = base.appendingPathComponent("evidence.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        evidence.acceptanceRunID = runID.uuidString.lowercased()
        evidence.processID = Int(ProcessInfo.processInfo.processIdentifier)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        persist()
    }

    func markResultEditorVisible(_ observation: ResultEditorObservation) {
        evidence.resultEditorVisible = true
        evidence.originalSnippetVisible = evidence.originalSnippetVisible || observation.originalSnippetVisible
        evidence.canonicalMarkdownVisible = evidence.canonicalMarkdownVisible || observation.canonicalMarkdownVisible
        evidence.copyFormatsVisible = observation.copyFormatsVisible
        evidence.nativePasteBoundaryVisible = observation.nativePasteBoundaryVisible
        if observation.canonicalMarkdownVisible,
           observation.canonicalMarkdown == Ticket03AcceptanceFixture.editedMarkdown {
            evidence.editedSourceVisible = true
        }
        if evidence.phase == .launched { evidence.phase = .editorVisible }
        finishIfComplete()
        persist()
    }

    func markPreviewRendered(_ observation: PreviewRenderObservation) {
        guard observation.renderedFormulaVisible else { return }
        evidence.renderedFormulaVisible = true
        let document = MarkdownRenderer.document(for: observation.canonicalMarkdown)
        evidence.offlinePolicyPresent = document.contains("Content-Security-Policy")
            && document.contains("default-src 'none'")
            && document.contains("connect-src 'none'")
            && document.contains("frame-src 'none'")

        if observation.canonicalMarkdown == Ticket03AcceptanceFixture.initialMarkdown,
           observation.renderedTableVisible {
            evidence.initialPreviewVisible = true
            evidence.renderedTableVisible = true
            evidence.phase = .initialPreview
        } else if observation.canonicalMarkdown == Ticket03PasteboardInspector.pureFormulaSource {
            evidence.pureFormulaPreviewVisible = true
            evidence.phase = .pureFormulaPreview
        } else if observation.canonicalMarkdown == Ticket03AcceptanceFixture.editedMarkdown,
                  observation.renderedTableVisible,
                  evidence.initialPreviewVisible {
            evidence.editedSourceVisible = true
            evidence.editedPreviewVisible = true
            evidence.renderedTableVisible = true
            if evidence.pureFormulaPreviewVisible {
                evidence.finalEditedPreviewVisible = true
                evidence.phase = .finalEditedPreview
            } else {
                evidence.phase = .editedPreview
            }
        }
        finishIfComplete()
        persist()
    }

    func markCopy(_ format: CopyFormat, passed: Bool) {
        evidence[keyPath: Self.copyEvidenceKeyPaths[format]!] = passed
        finishIfComplete()
        persist()
    }

    private static let copyEvidenceKeyPaths: [CopyFormat: WritableKeyPath<Evidence, Bool>] = [
        .formulaOutput: \Evidence.formulaOutputCopied,
        .markdown: \Evidence.markdownCopied,
        .combinedOutput: \Evidence.combinedOutputCopied,
        .tsvTable: \Evidence.tsvTableCopied,
        .richTable: \Evidence.richTableCopied,
        .originalImage: \Evidence.originalImageCopied,
        .notion: \Evidence.notionCopied,
        .lark: \Evidence.larkCopied
    ]

    private func finishIfComplete() {
        // Local editor/clipboard evidence only, not destination paste acceptance.
        let complete = evidence.resultEditorVisible
            && evidence.copyFormatsVisible
            && evidence.nativePasteBoundaryVisible
            && evidence.initialPreviewVisible
            && evidence.originalSnippetVisible
            && evidence.canonicalMarkdownVisible
            && evidence.editedSourceVisible
            && evidence.editedPreviewVisible
            && evidence.renderedFormulaVisible
            && evidence.renderedTableVisible
            && evidence.offlinePolicyPresent
            && evidence.markdownCopied
            && evidence.notionCopied
            && evidence.larkCopied
        if complete { evidence.phase = .complete }
    }

    private func persist() {
        guard let data = try? encoder.encode(evidence) else { return }
        try? data.write(to: evidenceURL, options: .atomic)
    }
}
