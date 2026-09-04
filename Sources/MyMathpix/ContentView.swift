import AppKit
import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            historySidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 320)
        } detail: {
            if let item = model.selectedItem {
                ResultDetailView(item: item)
            } else {
                emptyState
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.startCapture()
                } label: {
                    Label("Capture", systemImage: "viewfinder")
                }
                .keyboardShortcut("m", modifiers: [.control, .command])
                .disabled(model.isProcessing)

                if model.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .onAppear { model.ticket01MarkRecognizingVisible() }
                }
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let summary = model.ticket01SafeSummary {
                    Text(summary)
                        .font(.caption.monospaced())
                        .accessibilityIdentifier("ticket01-safe-evidence")
                }
            }
        }
        .alert("MyMathpix", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var historySidebar: some View {
        List(selection: $model.selectedID) {
            Section("Recent 20") {
                ForEach(model.history.items) { item in
                    HistoryRow(item: item, image: model.history.image(for: item))
                        .tag(item.id)
                        .accessibilityIdentifier("recent-history-item")
                        .onAppear { model.ticket01MarkRecentHistoryVisible() }
                        .onChange(of: item.status) { _, status in
                            if status == .complete {
                                model.ticket01MarkRecentHistoryVisible()
                            }
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                model.selectedID = item.id
                                model.deleteSelected()
                            }
                        }
                }
            }
        }
        .overlay {
            if model.history.items.isEmpty {
                ContentUnavailableView("No snippets yet", systemImage: "viewfinder", description: Text("Use \(model.hotKeyConfiguration.displayName) to capture one."))
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(model.hasToken ? "Capture your first snippet" : "Add your Datalab token", systemImage: model.hasToken ? "viewfinder" : "key")
        } description: {
            Text(model.hasToken
                 ? "Press \(model.hotKeyConfiguration.displayName), select a formula or table, and release."
                 : "Open Settings, test your token, then capture a screen region.")
        } actions: {
            Button("Capture Snippet") { model.startCapture() }
                .disabled(!model.hasToken || model.isProcessing)
            SettingsLink { Text("Open Settings") }
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let image: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 52, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.markdown.isEmpty ? statusTitle : firstLine)
                    .lineLimit(1)
                Text(item.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var firstLine: String {
        item.markdown.split(separator: "\n").first.map(String.init) ?? "Snippet"
    }

    private var statusTitle: String {
        switch item.status {
        case .processing: "Recognizing…"
        case .failed: "Recognition failed"
        case .complete: "Empty result"
        }
    }
}

private struct ResultDetailView: View {
    @EnvironmentObject private var model: AppModel
    let item: HistoryItem

    var body: some View {
        VStack(spacing: 0) {
            actionBar
            Divider()
            HSplitView {
                VSplitView {
                    GroupBox("Original Snippet") {
                        if let image = model.history.image(for: item) {
                            ScrollView([.horizontal, .vertical]) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                            }
                        }
                    }
                    .accessibilityIdentifier("original-snippet")
                    .frame(minHeight: 180)

                    GroupBox("Canonical Markdown") {
                        TextEditor(text: Binding(
                            get: { item.markdown },
                            set: { model.updateMarkdown($0) }
                        ))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(4)
                    }
                    .accessibilityIdentifier("canonical-markdown")
                    .frame(minHeight: 220)
                }
                .frame(minWidth: 400)

                GroupBox("Offline Preview") {
                    MarkdownPreview(
                        markdown: item.markdown,
                        complexTableHTML: item.html
                    ) {
                        renderedFormulaVisible,
                        renderedTableVisible in
                        model.ticket01MarkPreviewVisible(
                            renderedFormulaVisible: renderedFormulaVisible,
                            renderedTableVisible: renderedTableVisible
                        )
                        model.ticket03MarkPreviewVisible(PreviewRenderObservation(
                            canonicalMarkdown: item.markdown,
                            renderedFormulaVisible: renderedFormulaVisible,
                            renderedTableVisible: renderedTableVisible
                        ))
                    }
                }
                .accessibilityIdentifier("offline-preview")
                .frame(minWidth: 400)
            }
            .padding(10)
        }
        .accessibilityIdentifier("result-editor")
        .onAppear { reportFinalSurface() }
        .onChange(of: item.status) { _, status in
            if status == .complete { reportFinalSurface() }
        }
        .onChange(of: item.markdown) { _, _ in reportFinalSurface() }
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if item.status == .failed {
                    Label(item.errorMessage ?? "Recognition failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .lineLimit(1)
                    Button("Retry") { model.retryFailed() }
                } else {
                    Button("High Quality Retry") { model.retryHighQuality() }
                        .disabled(model.isProcessing)
                    Menu("Copy Formats") {
                        ForEach(CopyFormat.allCases) { format in
                            Button(format.title) { model.copySelected(as: format) }
                                .help(format.helpText)
                        }
                    }
                    .disabled(item.status != .complete)
                    .accessibilityIdentifier("copy-formats-menu")
                }
                Spacer()
                if let runtime = item.runtime {
                    Text(String(format: "%.2fs", runtime)).foregroundStyle(.secondary)
                }
                Text(item.mode.title).foregroundStyle(.secondary)
                Button(role: .destructive) { model.deleteSelected() } label: {
                    Image(systemName: "trash")
                }
                .help("Delete this snippet")
            }
            Text(CopyFormat.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("copy-formats-native-paste-boundary")
        }
        .padding(10)
    }

    private func reportFinalSurface() {
        model.ticket01MarkResultEditorVisible(
            originalSnippetVisible: model.history.image(for: item) != nil,
            canonicalMarkdown: item.markdown,
            isComplete: item.status == .complete
        )
        model.ticket03MarkResultEditorVisible(
            originalSnippetVisible: model.history.image(for: item) != nil,
            canonicalMarkdown: item.markdown,
            copyFormatsVisible: item.status == .complete,
            nativePasteBoundaryVisible: CopyFormat.explanation.contains("Native Paste")
                && CopyFormat.explanation.contains("does not create native Notion or Feishu blocks")
        )
    }
}

struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    let complexTableHTML: String?
    let onRendered: (Bool, Bool) -> Void

    init(
        markdown: String,
        complexTableHTML: String? = nil,
        onRendered: @escaping (Bool, Bool) -> Void = { _, _ in }
    ) {
        self.markdown = markdown
        self.complexTableHTML = complexTableHTML
        self.onRendered = onRendered
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRendered: onRendered)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.setAccessibilityIdentifier("offline-preview-webview")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onRendered = onRendered
        context.coordinator.prepareForDocumentLoad()
        let baseURL = AppResources.directoryURL
        webView.loadHTMLString(
            MarkdownRenderer.document(
                for: markdown,
                complexTableHTML: complexTableHTML
            ),
            baseURL: baseURL
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onRendered: (Bool, Bool) -> Void
        private var isAwaitingDocumentLoad = false

        init(onRendered: @escaping (Bool, Bool) -> Void) {
            self.onRendered = onRendered
        }

        func prepareForDocumentLoad() {
            isAwaitingDocumentLoad = true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard isAwaitingDocumentLoad,
                  navigationAction.navigationType == .other,
                  navigationAction.targetFrame?.isMainFrame == true,
                  let url = navigationAction.request.url,
                  OfflinePreviewNavigationPolicy.allows(url) else {
                decisionHandler(.cancel)
                return
            }
            isAwaitingDocumentLoad = false
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(
                "[document.querySelectorAll('.katex').length, document.querySelectorAll('table').length]"
            ) {
                [weak self] value, error in
                let counts = value as? [NSNumber]
                let formulaCount = counts?.first?.intValue ?? 0
                let tableCount = counts?.dropFirst().first?.intValue ?? 0
                self?.onRendered(
                    error == nil && formulaCount > 0,
                    error == nil && tableCount > 0
                )
            }
        }
    }
}
