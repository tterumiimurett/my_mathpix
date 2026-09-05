import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var token = ""
    @State private var hotKey = HotKeyConfiguration()
    @State private var testingToken = false
    @State private var status: String?

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
                if model.hasToken {
                    Button("Clear Saved Token", role: .destructive) {
                        do {
                            try model.clearToken()
                            token = ""
                            status = "Saved token cleared."
                        } catch {
                            status = error.localizedDescription
                        }
                    }
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
                        do { try model.saveHotKey(hotKey); status = "Shortcut saved." }
                        catch { status = error.localizedDescription }
                    }
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
                LabeledContent("Recorded cost (cents)", value: String(format: "%.4f", model.usage.cumulativeCost))
            }

            Section("Local data") {
                Button("Clear Recent History", role: .destructive) {
                    do { try model.clearHistory(); status = "History cleared." }
                    catch { status = error.localizedDescription }
                }
                Text("History stays in this Mac's sandbox container. Snippet pixels and complete outputs are not written to diagnostic logs.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let status {
                Section { Text(status).font(.caption) }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { hotKey = model.hotKeyConfiguration }
    }

    @MainActor
    private func testToken() async {
        testingToken = true
        defer { testingToken = false }
        do {
            try await model.testAndSaveToken(token)
            token = ""
            status = "Token verified and saved locally in the App Sandbox."
        } catch is CancellationError {
            // A newer credential action owns the visible status.
        } catch {
            status = error.localizedDescription
        }
    }
}
