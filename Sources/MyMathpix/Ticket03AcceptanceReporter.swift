import Foundation

@MainActor
final class Ticket03AcceptanceReporter {
    enum PreviewAction {
        case none
        case applyEditedSource
        case copyMixedFormatsAndShowPureFormula
        case copyFormulaAndRestoreEditedSource
        case finish
    }

    struct Evidence: Codable, Equatable {
        var schema = 1
        var acceptanceRunID = ""
        var processID = 0
        var phase = "launched"
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
        canonicalMarkdown: String
    ) {
        evidence.resultEditorVisible = true
        evidence.originalSnippetVisible = originalSnippetVisible
        evidence.canonicalMarkdownVisible = true
        evidence.copyFormatsVisible = CopyFormat.allCases.count == 6
        evidence.nativePasteBoundaryVisible = CopyFormat.explanation.contains("Native Paste")
            && CopyFormat.explanation.contains("does not create native Notion or Feishu blocks")
        if canonicalMarkdown == Ticket03AcceptanceFixture.editedMarkdown {
            evidence.editedSourceVisible = true
        }
        if evidence.phase == "launched" { evidence.phase = "editor-visible" }
        persist()
    }

    func markPreviewRendered(
        canonicalMarkdown: String,
        renderedFormulaVisible: Bool,
        renderedTableVisible: Bool
    ) -> PreviewAction {
        guard renderedFormulaVisible else { return .none }
        evidence.renderedFormulaVisible = true
        let document = MarkdownRenderer.document(for: canonicalMarkdown)
        evidence.offlinePolicyPresent = document.contains("Content-Security-Policy")
            && document.contains("default-src 'none'")
            && document.contains("connect-src 'none'")
            && document.contains("frame-src 'none'")

        switch evidence.phase {
        case "editor-visible" where canonicalMarkdown == Ticket03AcceptanceFixture.initialMarkdown:
            guard renderedTableVisible else { return .none }
            evidence.initialPreviewVisible = true
            evidence.renderedTableVisible = true
            evidence.phase = "initial-preview"
            persist()
            return .applyEditedSource
        case "initial-preview" where canonicalMarkdown == Ticket03AcceptanceFixture.editedMarkdown:
            guard renderedTableVisible else { return .none }
            evidence.editedPreviewVisible = true
            evidence.renderedTableVisible = true
            evidence.phase = "copying-mixed"
            persist()
            return .copyMixedFormatsAndShowPureFormula
        case "awaiting-pure-preview" where canonicalMarkdown == Ticket03PasteboardInspector.pureFormulaSource:
            evidence.pureFormulaPreviewVisible = true
            evidence.phase = "copying-formula"
            persist()
            return .copyFormulaAndRestoreEditedSource
        case "awaiting-final-preview" where canonicalMarkdown == Ticket03AcceptanceFixture.editedMarkdown:
            guard renderedTableVisible else { return .none }
            evidence.finalEditedPreviewVisible = true
            evidence.renderedTableVisible = true
            persist()
            return .finish
        default:
            return .none
        }
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
        persist()
    }

    func expectPureFormulaPreview() {
        evidence.phase = "awaiting-pure-preview"
        persist()
    }

    func expectFinalEditedPreview() {
        evidence.phase = "awaiting-final-preview"
        persist()
    }

    func finish() {
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
        evidence.phase = complete ? "complete" : "failed"
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(evidence) else { return }
        try? data.write(to: evidenceURL, options: .atomic)
    }
}
