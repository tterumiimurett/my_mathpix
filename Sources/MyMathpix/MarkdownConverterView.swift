import AppKit
import SwiftUI

struct MarkdownConverterView: View {
    let pasteboard: NSPasteboard
    @Environment(\.dismiss) private var dismiss
    @FocusState private var sourceIsFocused: Bool
    @State private var markdown = ""
    @State private var previewMarkdown = ""
    @State private var copyFeedback: String?
    @State private var copyFailed = false

    private var hasSource: Bool {
        !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Convert Markdown")
                .font(.title2.bold())
                .padding(16)

            Divider()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    paneTitle("Markdown")
                    TextEditor(text: $markdown)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .focused($sourceIsFocused)
                        .accessibilityLabel("Markdown Source")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 0) {
                    paneTitle("Preview")
                    if hasSource {
                        MarkdownPreview(markdown: previewMarkdown)
                            .accessibilityLabel("Offline Preview")
                    } else {
                        Text("Type or paste Markdown to preview it here.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            HStack(spacing: 8) {
                ForEach(CopyFormat.visibleFormats) { format in
                    Button("Copy \(format.title)") { copy(format) }
                        .disabled(!hasSource)
                        .help(format.helpText)
                }

                Spacer()

                if let copyFeedback {
                    Label(copyFeedback, systemImage: copyFailed ? "exclamationmark.triangle" : "checkmark")
                        .font(.caption)
                        .foregroundStyle(copyFailed ? Color.red : Color.secondary)
                }

                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(minWidth: 720, minHeight: 420)
        .defaultFocus($sourceIsFocused, true)
        .onChange(of: markdown) { copyFeedback = nil }
        .task(id: markdown) {
            do { try await Task.sleep(for: .milliseconds(150)) }
            catch { return }
            previewMarkdown = markdown
        }
    }

    private func paneTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }

    private func copy(_ format: CopyFormat) {
        let payload = ClipboardPayload(canonicalMarkdown: markdown, complexTableHTML: nil, originalPNG: nil)
        do {
            try ClipboardService.copy(format, payload: payload, to: pasteboard)
            copyFeedback = "\(format.title) copied"
            copyFailed = false
        } catch {
            copyFeedback = error.localizedDescription
            copyFailed = true
        }
    }
}
