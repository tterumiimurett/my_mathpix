import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var token = ""
    @State private var hotKey = HotKeyConfiguration()
    @State private var testingToken = false
    @State private var status: String?
    @State private var shortcutStatus: String?
    @State private var shortcutStatusIsError = false
    @State private var confirmsHistoryClear = false

    var body: some View {
        Form {
            Section("Datalab") {
                SecureField(model.hasToken ? "A token is saved — enter a replacement" : "API token", text: $token)
                HStack {
                    Button(testingToken ? "Testing…" : "Test & Save") {
                        Task { await testToken() }
                    }
                    .disabled(testingToken || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.hasToken { Label("Stored locally on this Mac", systemImage: "externaldrive") }
                }
                Text("The test calls Datalab's authenticated health endpoint. A verified token is stored as a 0600 file inside the App Sandbox; MyMathpix does not access Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Capture shortcut") {
                HStack {
                    Toggle("⌃ Control", isOn: $hotKey.control)
                    Toggle("⌥ Option", isOn: $hotKey.option)
                    Toggle("⇧ Shift", isOn: $hotKey.shift)
                    Toggle("⌘ Command", isOn: $hotKey.command)
                }
                HStack {
                    TextField("Key", text: $hotKey.key).frame(width: 60)
                    Text(hotKey.displayName).font(.title3.monospaced())
                    Button("Save Shortcut") {
                        do {
                            try model.saveHotKey(hotKey)
                            shortcutStatus = "Shortcut saved."
                            shortcutStatusIsError = false
                        } catch {
                            shortcutStatus = error.localizedDescription
                            shortcutStatusIsError = true
                        }
                    }
                }
                if let shortcutStatus {
                    Text(shortcutStatus)
                        .font(.caption)
                        .foregroundStyle(shortcutStatusIsError ? Color.red : Color.secondary)
                }
            }

            Section("System") {
                Button("Request Screen Recording Permission") { model.requestScreenCapturePermission() }
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { value in
                        do { try model.setLaunchAtLogin(value) }
                        catch { status = error.localizedDescription }
                    }
                ))
            }

            Section("Usage") {
                LabeledContent("Requests", value: "\(model.usage.requestCount)")
                LabeledContent("Successful", value: "\(model.usage.successfulCount)")
                LabeledContent("Recorded cost", value: String(format: "%.4f", model.usage.cumulativeCost))
            }

            Section("Local data") {
                Button("Clear Recent History", role: .destructive) {
                    confirmsHistoryClear = true
                }
                Text("The twenty newest Successful or Failed Records stay in this Mac's App Sandbox container, including each original Snippet and final edited output.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                LabeledContent("Local events", value: "\(model.diagnosticLog.entries.count)")
                if let latest = model.diagnosticLog.entries.last {
                    LabeledContent("Latest", value: latest.code.rawValue)
                }
                HStack {
                    Button("Export Diagnostics…") { exportDiagnostics() }
                    Button("Clear Diagnostics", role: .destructive) {
                        do {
                            try model.clearDiagnostics()
                            status = "Diagnostics cleared."
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
                Text("Diagnostics stay local unless you export them. They contain fixed operational event codes only—never credentials, authentication headers, Snippet pixels, or complete output.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("About MyMathpix") {
                LabeledContent("Version", value: AppVersionInfo.current.displayName)
                if ThirdPartyLicenses.bundled.isEmpty {
                    Text("No bundled license notice is available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ThirdPartyLicenses.bundled) { license in
                        DisclosureGroup("\(license.name) — License Notice") {
                            ScrollView {
                                Text(license.text)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 150)
                        }
                    }
                }
            }

            if let status {
                Section { Text(status).font(.caption) }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { hotKey = model.hotKeyConfiguration }
        .confirmationDialog(
            "Clear all Recent History?",
            isPresented: $confirmsHistoryClear,
            titleVisibility: .visible
        ) {
            Button("Clear All Snippets", role: .destructive) {
                do {
                    try model.clearHistory()
                    status = "History cleared."
                } catch {
                    status = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every retained Snippet image and edited output from the App Sandbox.")
        }
    }

    @MainActor
    private func testToken() async {
        testingToken = true
        defer { testingToken = false }
        do {
            try await model.testAndSaveToken(token)
            token = ""
            status = "Token verified and saved locally in the App Sandbox."
        } catch {
            status = error.localizedDescription
        }
    }

    @MainActor
    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export MyMathpix Diagnostics"
        panel.nameFieldStringValue = "MyMathpix-Diagnostics.txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportDiagnostics(to: url)
            status = "Diagnostics exported."
        } catch {
            status = error.localizedDescription
        }
    }
}
