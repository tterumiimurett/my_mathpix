import Foundation

@MainActor
enum Ticket04DailyWorkflowSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("MyMathpix-Ticket04SelfTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        do {
            let interruptedRoot = root.appendingPathComponent("InterruptedHistory", isDirectory: true)
            let interruptedStore = HistoryStore(rootURL: interruptedRoot)
            let interruptedItem = try interruptedStore.create(
                uploadPayload: UploadPayload(pngData: Data("interrupted-image".utf8))
            )
            let recoveredStore = HistoryStore(rootURL: interruptedRoot)
            expect(
                recoveredStore.item(id: interruptedItem.id)?.status == .failed
                    && recoveredStore.imageData(for: interruptedItem) == Data("interrupted-image".utf8),
                "relaunch recovers an interrupted attempt as a Failed Record",
                failures: &failures
            )

            let historyRoot = root.appendingPathComponent("History", isDirectory: true)
            let store = HistoryStore(rootURL: historyRoot)
            var created: [HistoryItem] = []

            for index in 0..<21 {
                let pixels = Data("ticket04-image-\(index)".utf8)
                var item = try store.create(uploadPayload: UploadPayload(pngData: pixels))
                item.markdown = "initial result \(index)"
                item.status = index == 7 ? .failed : .complete
                item.errorMessage = index == 7 ? "Recoverable recognition failure" : nil
                try store.update(item)
                created.append(item)
            }

            var edited = created[12]
            edited.markdown = "owner corrected final output"
            try store.update(edited)

            let relaunched = HistoryStore(rootURL: historyRoot)
            expect(relaunched.items.count == 20, "Recent History relaunch limit", failures: &failures)
            expect(relaunched.item(id: created[0].id) == nil, "twenty-first record eviction", failures: &failures)
            expect(
                !fileManager.fileExists(
                    atPath: historyRoot.appendingPathComponent(created[0].imageFilename).path
                ),
                "evicted Snippet image deletion",
                failures: &failures
            )
            expect(
                relaunched.item(id: edited.id)?.markdown == "owner corrected final output",
                "edited output survives relaunch",
                failures: &failures
            )
            expect(
                relaunched.item(id: created[7].id)?.status == .failed
                    && relaunched.imageData(for: created[7]) == Data("ticket04-image-7".utf8),
                "Failed Record keeps its original Snippet",
                failures: &failures
            )

            let deleted = created[8]
            try relaunched.delete(id: deleted.id)
            expect(
                relaunched.item(id: deleted.id) == nil
                    && !fileManager.fileExists(
                        atPath: historyRoot.appendingPathComponent(deleted.imageFilename).path
                    ),
                "single Recent History deletion removes its image",
                failures: &failures
            )
            try relaunched.clear()
            let afterClear = HistoryStore(rootURL: historyRoot)
            let remainingImages = (try? fileManager.contentsOfDirectory(
                at: historyRoot,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "png" }) ?? []
            expect(
                afterClear.items.isEmpty && remainingImages.isEmpty,
                "clear Recent History removes records and images",
                failures: &failures
            )

            let protectedHistoryRoot = root.appendingPathComponent("ProtectedHistory", isDirectory: true)
            let protectedStore = HistoryStore(rootURL: protectedHistoryRoot)
            let protectedItem = try protectedStore.create(
                uploadPayload: UploadPayload(pngData: Data("retained-image".utf8))
            )
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o500))],
                ofItemAtPath: protectedHistoryRoot.path
            )
            var rejectedDelete = false
            do {
                try protectedStore.delete(id: protectedItem.id)
            } catch {
                rejectedDelete = true
            }
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o700))],
                ofItemAtPath: protectedHistoryRoot.path
            )
            expect(
                rejectedDelete
                    && protectedStore.item(id: protectedItem.id) != nil
                    && protectedStore.imageData(for: protectedItem) == Data("retained-image".utf8),
                "failed deletion keeps the Recent History record and image together",
                failures: &failures
            )

            let diagnosticRoot = root.appendingPathComponent("Diagnostics", isDirectory: true)
            let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
            let diagnostics = DiagnosticLog(rootURL: diagnosticRoot, now: { fixedDate })
            try diagnostics.record(.appLaunched)
            try diagnostics.record(.recognitionFailed, mode: .balanced)
            let reloadedDiagnostics = DiagnosticLog(rootURL: diagnosticRoot, now: { fixedDate })
            expect(
                reloadedDiagnostics.entries.map(\.code) == [.appLaunched, .recognitionFailed],
                "local diagnostics survive relaunch",
                failures: &failures
            )
            let report = try reloadedDiagnostics.exportData(
                version: AppVersionInfo(marketingVersion: "0.1.0", build: "1"),
                operatingSystem: "macOS test"
            )
            let reportText = String(decoding: report, as: UTF8.self)
            let prohibited = [
                "ticket04-private-token",
                "X-API-Key",
                "ticket04-image-7",
                "owner corrected final output"
            ]
            expect(
                reportText.contains("MyMathpix 0.1.0 (1)")
                    && reportText.contains("recognition_failed")
                    && prohibited.allSatisfy { !reportText.contains($0) },
                "diagnostic export is useful and content-free",
                failures: &failures
            )
            try reloadedDiagnostics.clear()
            expect(
                DiagnosticLog(rootURL: diagnosticRoot).entries.isEmpty,
                "local diagnostics can be cleared",
                failures: &failures
            )

            let workflowHistoryRoot = root.appendingPathComponent("WorkflowHistory", isDirectory: true)
            let workflowHistory = HistoryStore(rootURL: workflowHistoryRoot)
            var firstWorkflowItem = try workflowHistory.create(
                uploadPayload: UploadPayload(pngData: Data("first-workflow-image".utf8))
            )
            firstWorkflowItem.status = .complete
            firstWorkflowItem.markdown = "first result"
            try workflowHistory.update(firstWorkflowItem)
            var failedWorkflowItem = try workflowHistory.create(
                uploadPayload: UploadPayload(pngData: Data("failed-workflow-image".utf8))
            )
            failedWorkflowItem.status = .failed
            failedWorkflowItem.errorMessage = "Recoverable recognition failure"
            try workflowHistory.update(failedWorkflowItem)

            let workflowDefaultsName = "com.byterumi.mymathpix.ticket04.workflow.\(UUID().uuidString)"
            let workflowDefaults = UserDefaults(suiteName: workflowDefaultsName)!
            defer { workflowDefaults.removePersistentDomain(forName: workflowDefaultsName) }
            let workflowModel = AppModel(
                recognitionService: Ticket04SuccessfulRecognitionService(),
                history: workflowHistory,
                defaults: workflowDefaults,
                hotKeyRegistrar: Ticket04HotKeyRegistrar(),
                launchAtLoginController: Ticket04LaunchAtLoginController(isEnabled: false),
                diagnosticLog: DiagnosticLog(
                    rootURL: root.appendingPathComponent("WorkflowDiagnostics", isDirectory: true),
                    now: { fixedDate }
                )
            )
            workflowModel.selectedID = firstWorkflowItem.id
            workflowModel.updateMarkdown("owner autosaved edit")
            workflowModel.selectedID = failedWorkflowItem.id
            let afterNavigation = HistoryStore(rootURL: workflowHistoryRoot)
            expect(
                afterNavigation.item(id: firstWorkflowItem.id)?.markdown == "owner autosaved edit",
                "edited output autosaves across navigation and relaunch",
                failures: &failures
            )

            let originalRetryImageFilename = failedWorkflowItem.imageFilename
            workflowModel.retryFailed()
            let retryFinished = waitUntil { !workflowModel.isProcessing }
            let afterRetry = HistoryStore(rootURL: workflowHistoryRoot)
            let retriedItem = afterRetry.item(id: failedWorkflowItem.id)
            expect(
                retryFinished
                    && afterRetry.items.count == 2
                    && retriedItem?.status == .complete
                    && retriedItem?.markdown == "retried final output"
                    && retriedItem?.imageFilename == originalRetryImageFilename
                    && afterRetry.imageData(for: failedWorkflowItem) == Data("failed-workflow-image".utf8),
                "retry updates the existing record and keeps its original Snippet",
                failures: &failures
            )

            let defaultsName = "com.byterumi.mymathpix.ticket04.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: defaultsName)!
            defer { defaults.removePersistentDomain(forName: defaultsName) }
            let hotKeys = Ticket04HotKeyRegistrar()
            let login = Ticket04LaunchAtLoginController(isEnabled: false)
            let settingsDiagnostics = DiagnosticLog(
                rootURL: root.appendingPathComponent("SettingsDiagnostics", isDirectory: true),
                now: { fixedDate }
            )
            let model = AppModel(
                recognitionService: Ticket04RecognitionService(),
                history: HistoryStore(inMemory: true),
                defaults: defaults,
                hotKeyRegistrar: hotKeys,
                launchAtLoginController: login,
                diagnosticLog: settingsDiagnostics
            )
            expect(!model.launchAtLogin, "launch at login is disabled by default", failures: &failures)
            expect(
                hotKeys.registeredConfigurations == [HotKeyConfiguration()],
                "default global shortcut is registered at launch",
                failures: &failures
            )

            let customShortcut = HotKeyConfiguration(
                key: "K",
                command: true,
                control: false,
                option: true,
                shift: false
            )
            try model.saveHotKey(customShortcut)
            expect(
                model.hotKeyConfiguration == customShortcut
                    && Self.savedHotKey(in: defaults) == customShortcut,
                "custom shortcut is active and persisted",
                failures: &failures
            )

            hotKeys.shouldRejectNextRegistration = true
            let conflictingShortcut = HotKeyConfiguration(
                key: "J",
                command: true,
                control: true,
                option: false,
                shift: false
            )
            do {
                try model.saveHotKey(conflictingShortcut)
                failures.append("shortcut conflict is reported immediately")
            } catch {
                expect(
                    model.hotKeyConfiguration == customShortcut
                        && Self.savedHotKey(in: defaults) == customShortcut,
                    "shortcut conflict preserves the working shortcut",
                    failures: &failures
                )
            }

            try model.setLaunchAtLogin(true)
            expect(
                model.launchAtLogin && login.isEnabled,
                "launch at login changes only after an owner action",
                failures: &failures
            )
            expect(
                settingsDiagnostics.entries.map(\.code) == [
                    .appLaunched,
                    .shortcutUpdated,
                    .shortcutConflict,
                    .launchAtLoginEnabled
                ],
                "settings actions write fixed content-free diagnostics",
                failures: &failures
            )
            let relaunchedHotKeys = Ticket04HotKeyRegistrar()
            let relaunchedModel = AppModel(
                recognitionService: Ticket04RecognitionService(),
                history: HistoryStore(inMemory: true),
                defaults: defaults,
                hotKeyRegistrar: relaunchedHotKeys,
                launchAtLoginController: login,
                diagnosticLog: DiagnosticLog(
                    rootURL: root.appendingPathComponent("RelaunchedSettingsDiagnostics", isDirectory: true),
                    now: { fixedDate }
                )
            )
            expect(
                relaunchedModel.hotKeyConfiguration == customShortcut
                    && relaunchedHotKeys.registeredConfigurations == [customShortcut]
                    && relaunchedModel.launchAtLogin,
                "custom shortcut and launch-at-login state restore on relaunch",
                failures: &failures
            )

            var openMainWindowCount = 0
            model.installMainWindowOpener { openMainWindowCount += 1 }
            model.showMainWindow()
            expect(
                openMainWindowCount == 1,
                "menu bar can reopen a closed normal window",
                failures: &failures
            )

            let exportedDiagnosticsURL = root.appendingPathComponent("MyMathpix-Diagnostics.txt")
            try model.exportDiagnostics(to: exportedDiagnosticsURL)
            let exportedDiagnostics = try String(contentsOf: exportedDiagnosticsURL, encoding: .utf8)
            expect(
                exportedDiagnostics.contains("shortcut_updated")
                    && exportedDiagnostics.contains("launch_at_login_enabled")
                    && !exportedDiagnostics.contains("owner corrected final output"),
                "owner-triggered diagnostic export stays content-free",
                failures: &failures
            )
            try model.clearDiagnostics()
            expect(model.diagnosticLog.entries.isEmpty, "owner can clear diagnostics", failures: &failures)
        } catch {
            failures.append("daily workflow persistence: \(error.localizedDescription)")
        }

        let shortcut = HotKeyConfiguration()
        expect(
            shortcut.key == "M" && shortcut.control && shortcut.command
                && !shortcut.option && !shortcut.shift
                && shortcut.displayName == "⌃⌘M",
            "default global shortcut is Control-Command-M",
            failures: &failures
        )
        do {
            let firstRegistrar = HotKeyManager()
            let conflictingRegistrar = HotKeyManager()
            let conflictProbe = HotKeyConfiguration(
                key: "Z",
                command: true,
                control: true,
                option: true,
                shift: true
            )
            try firstRegistrar.register(conflictProbe) {}
            do {
                try conflictingRegistrar.register(conflictProbe) {}
                failures.append("real global shortcut conflict is reported immediately")
            } catch {
                expect(
                    error.localizedDescription.contains("conflict"),
                    "real global shortcut conflict is reported immediately",
                    failures: &failures
                )
            }
        } catch {
            failures.append("real global shortcut conflict probe: \(error.localizedDescription)")
        }

        let version = AppVersionInfo.current
        expect(!version.marketingVersion.isEmpty && !version.build.isEmpty, "App version is exposed", failures: &failures)
        let licenses = ThirdPartyLicenses.bundled
        expect(
            licenses.contains { license in
                license.name == "KaTeX"
                    && license.text.contains("The MIT License")
                    && license.text.contains("Copyright")
            },
            "bundled KaTeX license is exposed",
            failures: &failures
        )

        if failures.isEmpty {
            print("TICKET04_DAILY_WORKFLOW_OK")
            return true
        }
        print("Ticket 04 daily workflow self-test failed:")
        failures.forEach { print("- \($0)") }
        return false
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ name: String,
        failures: inout [String]
    ) {
        if !condition() { failures.append(name) }
    }

    private static func savedHotKey(in defaults: UserDefaults) -> HotKeyConfiguration? {
        guard let data = defaults.data(forKey: "hot-key") else { return nil }
        return try? JSONDecoder().decode(HotKeyConfiguration.self, from: data)
    }

    private static func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}

@MainActor
private final class Ticket04HotKeyRegistrar: HotKeyRegistering {
    var registeredConfigurations: [HotKeyConfiguration] = []
    var shouldRejectNextRegistration = false

    func register(_ configuration: HotKeyConfiguration, action: @escaping () -> Void) throws {
        if shouldRejectNextRegistration {
            shouldRejectNextRegistration = false
            throw AppError.service("The shortcut conflicts with another app.")
        }
        registeredConfigurations.append(configuration)
    }
}

@MainActor
private final class Ticket04LaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}

@MainActor
private final class Ticket04RecognitionService: RecognitionService {
    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        throw AppError.service("This settings-only test must not recognize content.")
    }
}

@MainActor
private final class Ticket04SuccessfulRecognitionService: RecognitionService {
    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        DatalabResult(
            markdown: "retried final output",
            html: nil,
            runtime: 0.2,
            costSummary: nil,
            costValue: nil,
            parseQualityScore: nil
        )
    }
}
