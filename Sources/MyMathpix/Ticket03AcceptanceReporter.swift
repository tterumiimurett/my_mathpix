import Foundation

struct PreviewRenderObservation {
    let canonicalMarkdown: String
    let renderedFormulaVisible: Bool
    let renderedTableVisible: Bool
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

    func markResultEditorVisible(
        originalSnippetVisible: Bool,
        canonicalMarkdown: String,
        copyFormatsVisible: Bool,
        nativePasteBoundaryVisible: Bool
    ) {
        evidence.resultEditorVisible = true
        evidence.originalSnippetVisible = originalSnippetVisible
        evidence.canonicalMarkdownVisible = true
        evidence.copyFormatsVisible = copyFormatsVisible
        evidence.nativePasteBoundaryVisible = nativePasteBoundaryVisible
        if canonicalMarkdown == Ticket03AcceptanceFixture.editedMarkdown {
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
        switch format {
        case .formulaOutput: evidence.formulaOutputCopied = passed
        case .markdown: evidence.markdownCopied = passed
        case .combinedOutput: evidence.combinedOutputCopied = passed
        case .tsvTable: evidence.tsvTableCopied = passed
        case .richTable: evidence.richTableCopied = passed
        case .originalImage: evidence.originalImageCopied = passed
        }
        finishIfComplete()
        persist()
    }

    private func finishIfComplete() {
        let complete = evidence.resultEditorVisible
            && evidence.originalSnippetVisible
            && evidence.canonicalMarkdownVisible
            && evidence.copyFormatsVisible
            && evidence.nativePasteBoundaryVisible
            && evidence.initialPreviewVisible
            && evidence.editedSourceVisible
            && evidence.editedPreviewVisible
            && evidence.pureFormulaPreviewVisible
            && evidence.finalEditedPreviewVisible
            && evidence.renderedFormulaVisible
            && evidence.renderedTableVisible
            && evidence.offlinePolicyPresent
            && evidence.formulaOutputCopied
            && evidence.markdownCopied
            && evidence.combinedOutputCopied
            && evidence.tsvTableCopied
            && evidence.richTableCopied
            && evidence.originalImageCopied
        if complete { evidence.phase = .complete }
    }

    private func persist() {
        guard let data = try? encoder.encode(evidence) else { return }
        try? data.write(to: evidenceURL, options: .atomic)
    }
}
