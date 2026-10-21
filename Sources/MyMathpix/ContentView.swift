import AppKit
import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

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
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.isProcessing {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.statusMessage)
                        .font(.callout)
                    ProgressView()
                        .progressViewStyle(.linear)
                        .accessibilityLabel("Recognition in progress")
                        .accessibilityIdentifier("recognition-progress-bar")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
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
                    Button("Cancel Recognition") {
                        model.cancelRecognition()
                    }
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
            if model.needsCredentialRecovery {
                Button("Open Settings") {
                    model.errorMessage = nil
                    openSettings()
                }
            }
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
    @State private var confirmsHighQualityReplacement = false
    @State private var retryingFailedRecord = false

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
                    MarkdownPreview(markdown: item.markdown) {
                        renderedFormulaVisible,
                        renderedTableVisible in
                        model.ticket01MarkPreviewVisible(
                            renderedFormulaVisible: renderedFormulaVisible,
                            renderedTableVisible: renderedTableVisible
                        )
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
        .confirmationDialog(
            "Replace the current edits?",
            isPresented: $confirmsHighQualityReplacement,
            titleVisibility: .visible
        ) {
            Button("Retry and Replace", role: .destructive) {
                if retryingFailedRecord {
                    model.retryFailed(replacingCurrentContent: true)
                } else {
                    model.retryHighQuality(replacingCurrentContent: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Retry will replace the current source with a new Datalab result.")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if item.status == .failed {
                Label(item.errorMessage ?? "Recognition failed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .lineLimit(1)
                Button("Retry") {
                    retryingFailedRecord = true
                    if model.retryNeedsConfirmation {
                        confirmsHighQualityReplacement = true
                    } else {
                        model.retryFailed()
                    }
                }
                Button("Copy Original Image") {
                    if let data = model.history.imageData(for: item) {
                        _ = ClipboardService.copyImage(data)
                    }
                }
            } else {
                Button("High Quality Retry") {
                    retryingFailedRecord = false
                    if model.retryNeedsConfirmation {
                        confirmsHighQualityReplacement = true
                    } else {
                        model.retryHighQuality(replacingCurrentContent: true)
                    }
                }
                    .disabled(model.isProcessing)
                Menu("Copy") {
                    Button("Combined Markdown") { ClipboardService.copyMarkdown(item.markdown) }
                    Button("LaTeX") {
                        if !ClipboardService.copyLaTeX(from: item.markdown) {
                            model.errorMessage = "This result is not a single pure formula."
                        }
                    }
                    Button("Table as TSV") {
                        if !ClipboardService.copyTSV(from: item.markdown) {
                            model.errorMessage = "No simple Markdown table was found."
                        }
                    }
                    Button("Rich Table") {
                        if !ClipboardService.copyRichTable(from: item.markdown) {
                            model.errorMessage = "No simple Markdown table was found."
                        }
                    }
                    Button("Original Image") {
                        if let data = model.history.imageData(for: item) { _ = ClipboardService.copyImage(data) }
                    }
                }
            }
            Spacer()
            if let usageRecord = model.usageRecords.latest(for: item.id) {
                if let runtime = usageRecord.serviceRuntimeSeconds {
                    Text(String(format: "Datalab %.2fs", runtime)).foregroundStyle(.secondary)
                }
                if let cost = usageRecord.costCents {
                    Text(String(format: "%.4f¢", cost)).foregroundStyle(.secondary)
                }
            }
            Text(item.mode.title).foregroundStyle(.secondary)
            Button(role: .destructive) { model.deleteSelected() } label: {
                Image(systemName: "trash")
            }
            .help("Delete this snippet")
        }
        .padding(10)
    }

    private func reportFinalSurface() {
        model.ticket01MarkResultEditorVisible(
            originalSnippetVisible: model.history.image(for: item) != nil,
            canonicalMarkdown: item.markdown,
            isComplete: item.status == .complete
        )
    }
}

struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    let onRendered: (Bool, Bool) -> Void

    init(
        markdown: String,
        onRendered: @escaping (Bool, Bool) -> Void = { _, _ in }
    ) {
        self.markdown = markdown
        self.onRendered = onRendered
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRendered: onRendered)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.setAccessibilityIdentifier("offline-preview-webview")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onRendered = onRendered
        let baseURL = AppResources.directoryURL
        webView.loadHTMLString(MarkdownRenderer.document(for: markdown), baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onRendered: (Bool, Bool) -> Void

        init(onRendered: @escaping (Bool, Bool) -> Void) {
            self.onRendered = onRendered
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
