import AppKit
import SwiftUI

/// The compact result surface can also be hosted by the capture-result window.
struct ResultEditorView: View {
    @EnvironmentObject private var model: AppModel
    let item: HistoryItem

    @State private var showsOriginal = false
    @State private var showsEditor = false
    @State private var showsCopyHelp = false
    @State private var copiedFormat: CopyFormat?
    @State private var copyError: String?
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                preview
                    .frame(height: 260)
                Divider()
                disclosureBar
                if showsOriginal { originalSnippet }
                if showsEditor { sourceEditor }
                copyFormats
                if let copyError {
                    Text(copyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("copy-error")
                }
                footer
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityIdentifier("result-editor")
        .onAppear { reportSurface() }
        .onChange(of: item.status) { _, _ in reportSurface() }
        .onChange(of: item.markdown) { _, _ in
            clearFeedback()
            reportSurface()
        }
        .onChange(of: showsOriginal) { _, _ in reportSurface() }
        .onChange(of: showsEditor) { _, _ in reportSurface() }
        .onChange(of: item.id) { _, _ in
            showsOriginal = false
            showsEditor = false
            clearFeedback()
        }
        .onDisappear { clearFeedback() }
    }

    private var preview: some View {
        MarkdownPreview(markdown: item.markdown, complexTableHTML: item.html) { formula, table in
            model.ticket01MarkPreviewVisible(renderedFormulaVisible: formula, renderedTableVisible: table)
            model.ticket03MarkPreviewVisible(PreviewRenderObservation(
                canonicalMarkdown: item.markdown,
                renderedFormulaVisible: formula,
                renderedTableVisible: table
            ))
        }
        .accessibilityLabel("Offline Preview")
        .accessibilityIdentifier("offline-preview")
    }

    private var disclosureBar: some View {
        HStack(spacing: 16) {
            Button { showsOriginal.toggle() } label: {
                Label(showsOriginal ? "Hide Original" : "Original", systemImage: "photo")
            }
            .accessibilityIdentifier("toggle-original")
            .accessibilityValue(showsOriginal ? "Expanded" : "Collapsed")
            Button { showsEditor.toggle() } label: {
                Label(showsEditor ? "Done Editing" : "Edit", systemImage: "pencil")
            }
            .accessibilityIdentifier("toggle-editor")
            .accessibilityValue(showsEditor ? "Expanded" : "Collapsed")
            Spacer()
        }
        .buttonStyle(.borderless)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var originalSnippet: some View {
        Group {
            if let image = model.history.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label("Original Snippet unavailable", systemImage: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .accessibilityLabel("Original Snippet")
        .accessibilityIdentifier("original-snippet")
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Canonical Markdown")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: Binding(get: { item.markdown }, set: model.updateMarkdown))
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 180)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .accessibilityLabel("Canonical Markdown")
                .accessibilityIdentifier("canonical-markdown")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var copyFormats: some View {
        let payload = ClipboardPayload(
            canonicalMarkdown: item.markdown,
            complexTableHTML: item.html,
            originalPNG: model.history.imageData(for: item)
        )
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Copy Formats")
                    .font(.system(size: 11, weight: .medium))
                Button { showsCopyHelp.toggle() } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy Formats and Native Paste")
                .accessibilityIdentifier("copy-formats-native-paste-boundary")
                .popover(isPresented: $showsCopyHelp) {
                    Text(CopyFormat.explanation)
                        .font(.callout)
                        .padding(16)
                        .frame(width: 290)
                }
                .help(CopyFormat.explanation)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 14)
            .padding(.bottom, 6)
            ForEach(CopyFormat.visibleFormats) { format in
                let preparation = Result { try ClipboardService.prepare(format, payload: payload) }
                let prepared = try? preparation.get()
                let unavailable: CopyFormatError? = if case .failure(let error) = preparation {
                    error as? CopyFormatError ?? .pasteboardWriteFailed
                } else { nil }
                let status = format != .originalImage && item.status != .complete
                    ? (item.status == .failed ? "Recognition failed" : "Recognizing…")
                    : unavailable?.shortDescription
                CopyFormatRow(format: format, prepared: prepared, unavailable: status, copied: copiedFormat == format) {
                    clearFeedback()
                    guard let prepared, model.copyPrepared(prepared) else {
                        copyError = model.errorMessage ?? "Copy failed. Please try again."
                        return
                    }
                    copiedFormat = format
                    feedbackTask = Task { @MainActor in
                        do { try await Task.sleep(for: .milliseconds(1600)) }
                        catch { return }
                        copiedFormat = nil
                    }
                }
                if format != CopyFormat.visibleFormats.last { Divider().padding(.horizontal, 8) }
            }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("copy-formats-list")
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if item.status == .failed {
                Label(item.errorMessage ?? "Recognition failed", systemImage: "exclamationmark.triangle")
                    .lineLimit(2)
                Spacer()
                Button("Retry") { model.retryFailed() }
            } else {
                Text(item.mode.title)
                if let runtime = item.runtime { Text(String(format: "· %.2fs", runtime)) }
                Spacer()
                Button("High Quality Retry") { model.retryHighQuality() }
                    .disabled(model.isProcessing)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func clearFeedback() {
        feedbackTask?.cancel()
        feedbackTask = nil
        copiedFormat = nil
        copyError = nil
    }

    private func reportSurface() {
        model.ticket01MarkResultEditorVisible(
            originalSnippetVisible: showsOriginal && model.history.image(for: item) != nil,
            canonicalMarkdown: item.markdown,
            isComplete: item.status == .complete
        )
        model.ticket03MarkResultEditorVisible(ResultEditorObservation(
            originalSnippetVisible: showsOriginal && model.history.image(for: item) != nil,
            canonicalMarkdown: item.markdown,
            copyFormatsVisible: true,
            nativePasteBoundaryVisible: true,
            canonicalMarkdownVisible: showsEditor
        ))
    }
}

private struct CopyFormatRow: View {
    let format: CopyFormat
    let prepared: PreparedClipboardCopy?
    let unavailable: String?
    let copied: Bool
    let copy: () -> Void
    @State private var isHovered = false

    private var shortTitle: String {
        switch format {
        case .formulaOutput: "LaTeX"
        case .markdown: "Markdown"
        case .combinedOutput: "Combined"
        case .tsvTable: "TSV"
        case .richTable: "Rich Table"
        case .originalImage: "Image"
        case .notion: "Notion"
        case .lark: "Lark"
        }
    }

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 12) {
                Text(shortTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                if let unavailable {
                    Text(unavailable)
                        .font(.system(size: 12))
                        .lineLimit(1)
                } else if let text = prepared?.previewText {
                    Text(text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " "))
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let image = prepared?.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 28, alignment: .leading)
                }
                Spacer(minLength: 8)
                if copied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.system(size: 12))
                } else if unavailable == nil {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(unavailable != nil ? Color.secondary : (copied ? Color.accentColor : Color.primary))
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(isHovered && unavailable == nil ? Color.primary.opacity(0.04) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(unavailable != nil)
        .onHover { isHovered = $0 }
        .help("\(format.title): \(format.helpText)")
        .accessibilityLabel("Copy \(format.title)")
        .accessibilityValue(unavailable ?? (copied ? "Copied" : "Available"))
        .accessibilityIdentifier("copy-format-\(format.rawValue)")
    }
}
