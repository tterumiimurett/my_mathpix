import Foundation

enum Ticket02RecognitionSelfTest {
    static func runBlocking() -> Bool {
        let result = LockedResult()
        Task.detached {
            result.finish(with: await run())
        }
        while !result.isComplete {
            RunLoop.current.run(
                mode: .default,
                before: Date(timeIntervalSinceNow: 0.01)
            )
        }
        return result.value
    }

    private static func run() async -> Bool {
        guard await validatesTokenWithoutRecognition() else {
            print("TICKET02_SELF_TEST_FAILURE step=health")
            return false
        }
        guard await submitsFastRecognitionContract() else {
            print("TICKET02_SELF_TEST_FAILURE step=fast-contract")
            return false
        }
        guard await retriesOneTransientPoll() else {
            print("TICKET02_SELF_TEST_FAILURE step=transient-retry")
            return false
        }
        guard await handlesPollFailureMatrix() else {
            print("TICKET02_SELF_TEST_FAILURE step=poll-failures")
            return false
        }
        guard await blocksUntrustedPollRedirect() else {
            print("TICKET02_SELF_TEST_FAILURE step=redirect-trust")
            return false
        }
        guard await configuresTokenThroughHealthCheck() else {
            print("TICKET02_SELF_TEST_FAILURE step=token-configuration")
            return false
        }
        guard await recoversFromInvalidRecognitionToken() else {
            print("TICKET02_SELF_TEST_FAILURE step=token-recovery")
            return false
        }
        guard await completesOwnerRecognitionJourney() else {
            print("TICKET02_SELF_TEST_FAILURE step=owner-journey")
            return false
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyMathpix-Ticket02-Token-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalTokenStore(rootURL: root)

        do {
            try store.saveToken("ticket02-non-secret-sentinel")
            guard store.hasPrivatePermissions else {
                print("TICKET02_SELF_TEST_FAILURE step=token-save")
                return false
            }
            try store.saveToken("ticket02-non-secret-replacement")
            guard store.hasPrivatePermissions else {
                print("TICKET02_SELF_TEST_FAILURE step=token-replace")
                return false
            }
            try store.clearToken()
            let cleared = store.readToken() == nil
            if !cleared { print("TICKET02_SELF_TEST_FAILURE step=token-clear") }
            return cleared
        } catch {
            print("TICKET02_SELF_TEST_FAILURE step=token-io")
            return false
        }
    }

    @MainActor
    private static func recoversFromInvalidRecognitionToken() async -> Bool {
        let png = Data([0x89, 0x50, 0x4e, 0x47])
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyMathpix-Ticket02-Recovery-\(UUID().uuidString)")
        let defaultsName = "com.byterumi.mymathpix.ticket02.recovery.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }
        let tokenStore = LocalTokenStore(rootURL: root.appendingPathComponent("token"))
        do {
            try tokenStore.saveToken("ticket02-non-secret-sentinel")
        } catch {
            return false
        }
        let service = LiveRecognitionService(
            tokenStore: tokenStore,
            client: DatalabClient(
                session: Ticket02MockURLProtocol.makeSession(
                    scenario: .recognitionInvalidCredentials,
                    expectedPNG: png
                )
            )
        )
        let history = HistoryStore(inMemory: true)
        let usageRecords = UsageRecordStore(inMemory: true)
        let model = AppModel(
            recognitionService: service,
            recognitionConfiguration: service,
            history: history,
            usageRecords: usageRecords,
            defaults: defaults,
            appInteractionEnabled: false
        )

        model.recognizeCapturedSnippet(UploadPayload(pngData: png))
        guard await waitUntil({ !model.isProcessing }),
              model.needsCredentialRecovery,
              let itemID = model.selectedID,
              history.item(id: itemID)?.status == .failed,
              history.imageData(for: history.item(id: itemID)!) == png,
              usageRecords.latest(for: itemID)?.failureCode == .invalidCredentials,
              model.errorMessage?.contains("Settings") == true else { return false }
        do {
            try model.clearToken()
            guard !model.hasToken && !model.needsCredentialRecovery else { return false }
            try model.saveToken("ticket02-non-secret-sentinel")
            Ticket02MockURLProtocol.configure(
                scenario: .recognitionPermissionDenied,
                expectedPNG: png
            )
            model.recognizeCapturedSnippet(UploadPayload(pngData: png))
            guard await waitUntil({ !model.isProcessing }),
                  !model.needsCredentialRecovery,
                  let permissionItemID = model.selectedID,
                  usageRecords.latest(for: permissionItemID)?.failureCode == .serviceFailure else {
                return false
            }
            return true
        } catch {
            return false
        }
    }

    private static func blocksUntrustedPollRedirect() async -> Bool {
        let png = Data([0x89, 0x50, 0x4e, 0x47])
        let client = DatalabClient(
            session: Ticket02MockURLProtocol.makeSession(
                scenario: .untrustedRedirect,
                expectedPNG: png
            ),
            policy: DatalabClient.Policy(
                timeout: .seconds(1),
                initialPollDelay: .milliseconds(1),
                maximumPollDelay: .milliseconds(2),
                transientRetryDelay: .milliseconds(1)
            )
        )
        do {
            _ = try await client.recognize(
                pngData: png,
                token: "ticket02-non-secret-sentinel",
                mode: .fast
            )
            return false
        } catch {
            let snapshot = Ticket02MockURLProtocol.snapshot()
            let passed = snapshot.pollCount == 1 && snapshot.untrustedRequestCount == 0
            if !passed {
                print(
                    "TICKET02_REDIRECT_TRUST polls=\(snapshot.pollCount) "
                    + "untrusted_requests=\(snapshot.untrustedRequestCount)"
                )
            }
            return passed
        }
    }

    @MainActor
    private static func completesOwnerRecognitionJourney() async -> Bool {
        let png = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyMathpix-Ticket02-Journey-\(UUID().uuidString)")
        let tokenRoot = root.appendingPathComponent("token", isDirectory: true)
        let evidenceRoot = root.appendingPathComponent("evidence", isDirectory: true)
        let defaultsName = "com.byterumi.mymathpix.ticket02.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }

        let tokenStore = LocalTokenStore(rootURL: tokenRoot)
        do {
            try tokenStore.saveToken("ticket02-non-secret-sentinel")
        } catch {
            return false
        }
        let session = Ticket02MockURLProtocol.makeSession(
            scenario: .processingForever,
            expectedPNG: png
        )
        let liveService = LiveRecognitionService(
            tokenStore: tokenStore,
            client: DatalabClient(
                session: session,
                policy: DatalabClient.Policy(
                    timeout: .seconds(2),
                    initialPollDelay: .milliseconds(2),
                    maximumPollDelay: .milliseconds(3),
                    transientRetryDelay: .milliseconds(1)
                )
            )
        )
        let usageRecords = UsageRecordStore(rootURL: evidenceRoot)
        let history = HistoryStore(inMemory: true)
        let model = AppModel(
            recognitionService: liveService,
            recognitionConfiguration: liveService,
            history: history,
            usageRecords: usageRecords,
            defaults: defaults,
            appInteractionEnabled: false,
            slowMessageDelay: .milliseconds(10)
        )

        model.recognizeCapturedSnippet(UploadPayload(pngData: png))
        guard model.isProcessing,
              model.statusMessage == "Recognizing…",
              history.items.count == 1 else { return false }
        guard await waitUntil({ model.statusMessage.contains("longer than usual") }) else {
            return false
        }
        model.cancelRecognition()
        guard await waitUntil({ !model.isProcessing }),
              let itemID = model.selectedID,
              history.item(id: itemID)?.status == .failed,
              history.imageData(for: history.item(id: itemID)!) == png,
              usageRecords.latest(for: itemID)?.outcome == .cancelled else { return false }

        Ticket02MockURLProtocol.configure(
            scenario: .pollHTTPRejection,
            expectedPNG: png
        )
        model.retryFailed()
        guard await waitUntil({ !model.isProcessing }),
              history.item(id: itemID)?.status == .failed,
              usageRecords.latest(for: itemID)?.outcome == .failed else { return false }

        Ticket02MockURLProtocol.configure(
            scenario: .conversionSuccess,
            expectedPNG: png
        )
        model.retryFailed()
        guard await waitUntil({ !model.isProcessing }),
              history.item(id: itemID)?.status == .complete,
              history.item(id: itemID)?.markdown == "ticket02 result",
              Ticket02MockURLProtocol.snapshot().fastMode,
              Ticket02MockURLProtocol.snapshot().pngMatched else { return false }

        model.updateMarkdown("owner hand edit")
        Ticket02MockURLProtocol.configure(
            scenario: .conversionSuccess,
            expectedPNG: png
        )
        guard model.highQualityRetryNeedsConfirmation else { return false }
        model.retryHighQuality(replacingCurrentContent: false)
        guard !model.isProcessing,
              Ticket02MockURLProtocol.snapshot().submitCount == 0,
              history.item(id: itemID)?.markdown == "owner hand edit" else { return false }

        model.retryHighQuality(replacingCurrentContent: true)
        guard model.isProcessing,
              history.item(id: itemID)?.markdown == "owner hand edit" else { return false }
        guard await waitUntil({ !model.isProcessing }),
              Ticket02MockURLProtocol.snapshot().balancedMode,
              Ticket02MockURLProtocol.snapshot().pngMatched,
              history.item(id: itemID)?.markdown == "ticket02 result",
              history.item(id: itemID)?.runtime == nil,
              history.item(id: itemID)?.costSummary == nil else { return false }

        let latest = usageRecords.latest(for: itemID)
        guard usageRecords.records.count == 4,
              latest?.outcome == .complete,
              latest?.mode == .balanced,
              latest?.serviceRuntimeSeconds == 1.25,
              latest?.costCents == 0.42,
              latest?.parseQualityScore == 4.5,
              model.usage.requestCount == 4,
              model.usage.successfulCount == 2,
              model.usage.cumulativeCost == 0.84 else { return false }

        let reloadedUsageRecords = UsageRecordStore(rootURL: evidenceRoot)
        guard reloadedUsageRecords.records == usageRecords.records,
              let evidenceData = try? Data(
                  contentsOf: evidenceRoot.appendingPathComponent("usage-records.json")
              ),
              !evidenceData.contains(Data("ticket02-non-secret-sentinel".utf8)),
              !evidenceData.contains(Data("ticket02 result".utf8)),
              !evidenceData.contains(Data("X-API-Key".utf8)) else { return false }

        let preferencesText = String(describing: defaults.dictionaryRepresentation())
        return !preferencesText.contains("ticket02-non-secret-sentinel")
    }

    @MainActor
    private static func waitUntil(
        _ condition: () -> Bool,
        timeout: Duration = .seconds(1)
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return condition()
    }

    @MainActor
    private static func configuresTokenThroughHealthCheck() async -> Bool {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MyMathpix-Ticket02-Configuration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalTokenStore(rootURL: root)
        let validService = LiveRecognitionService(
            tokenStore: store,
            client: DatalabClient(
                session: Ticket02MockURLProtocol.makeSession(scenario: .healthOK)
            )
        )
        do {
            try await validService.testAndSaveToken("ticket02-non-secret-sentinel")
            guard validService.isConfigured,
                  store.hasPrivatePermissions else { return false }

            let rejectingService = LiveRecognitionService(
                tokenStore: store,
                client: DatalabClient(
                    session: Ticket02MockURLProtocol.makeSession(scenario: .invalidCredentials)
                )
            )
            do {
                try await rejectingService.testAndSaveToken("ticket02-non-secret-replacement")
                return false
            } catch {
                guard store.readToken() == "ticket02-non-secret-sentinel" else { return false }
            }

            try rejectingService.clearToken()
            return !rejectingService.isConfigured && store.readToken() == nil
        } catch {
            return false
        }
    }

    private static func handlesPollFailureMatrix() async -> Bool {
        let quickPolicy = DatalabClient.Policy(
            timeout: .seconds(1),
            initialPollDelay: .milliseconds(1),
            maximumPollDelay: .milliseconds(2),
            transientRetryDelay: .milliseconds(1)
        )
        guard await expectsFailure(
            scenario: .persistentTransientPoll,
            policy: quickPolicy,
            code: .serviceFailure,
            pollCount: 2
        ),
        await expectsFailure(
            scenario: .nonRetryableServerStatus,
            policy: quickPolicy,
            code: .serviceFailure,
            pollCount: 1
        ),
        await expectsFailure(
            scenario: .untrustedCheckURL,
            policy: quickPolicy,
            code: .invalidResponse,
            pollCount: 0
        ),
        await expectsFailure(
            scenario: .unapprovedDatalabSubdomainCheckURL,
            policy: quickPolicy,
            code: .invalidResponse,
            pollCount: 0
        ),
        await expectsFailure(
            scenario: .nonStatusCheckURL,
            policy: quickPolicy,
            code: .invalidResponse,
            pollCount: 0
        ),
        await expectsFailure(
            scenario: .pollHTTPRejection,
            policy: quickPolicy,
            code: .serviceFailure,
            pollCount: 1
        ),
        await expectsFailure(
            scenario: .malformedPollJSON,
            policy: quickPolicy,
            code: .invalidResponse,
            pollCount: 1
        ),
        await expectsFailure(
            scenario: .completionMissingHTML,
            policy: quickPolicy,
            code: .invalidResponse,
            pollCount: 1
        ),
        await expectsFailure(
            scenario: .unknownPollStatus,
            policy: quickPolicy,
            code: .invalidResponse,
            pollCount: 1
        ),
        await expectsFailure(
            scenario: .serviceFailure,
            policy: quickPolicy,
            code: .serviceFailure,
            pollCount: 1
        ) else { return false }

        let timeoutPolicy = DatalabClient.Policy(
            timeout: .milliseconds(8),
            initialPollDelay: .milliseconds(1),
            maximumPollDelay: .milliseconds(2),
            transientRetryDelay: .milliseconds(1)
        )
        guard await expectsFailure(
            scenario: .processingForever,
            policy: timeoutPolicy,
            code: .timeout,
            minimumPollCount: 1
        ) else { return false }

        let wholeAttemptTimeoutPolicy = DatalabClient.Policy(
            timeout: .milliseconds(5),
            initialPollDelay: .milliseconds(1),
            maximumPollDelay: .milliseconds(2),
            transientRetryDelay: .milliseconds(1)
        )
        guard await expectsFailure(
            scenario: .slowSubmit,
            policy: wholeAttemptTimeoutPolicy,
            code: .timeout,
            pollCount: 0
        ) else { return false }

        let png = Data([0x89, 0x50, 0x4e, 0x47])
        let cancellationClient = DatalabClient(
            session: Ticket02MockURLProtocol.makeSession(
                scenario: .processingForever,
                expectedPNG: png
            ),
            policy: DatalabClient.Policy(
                timeout: .seconds(1),
                initialPollDelay: .milliseconds(20),
                maximumPollDelay: .milliseconds(20),
                transientRetryDelay: .milliseconds(1)
            )
        )
        let task = Task {
            try await cancellationClient.recognize(
                pngData: png,
                token: "ticket02-non-secret-sentinel",
                mode: .fast
            )
        }
        for _ in 0..<100 where Ticket02MockURLProtocol.snapshot().pollCount == 0 {
            try? await Task.sleep(for: .milliseconds(1))
        }
        task.cancel()
        do {
            _ = try await task.value
            return false
        } catch is CancellationError {
            return Ticket02MockURLProtocol.snapshot().pollCount >= 1
        } catch {
            return false
        }
    }

    private static func expectsFailure(
        scenario: Ticket02MockURLProtocol.Scenario,
        policy: DatalabClient.Policy,
        code: DiagnosticCode,
        pollCount: Int? = nil,
        minimumPollCount: Int? = nil
    ) async -> Bool {
        let png = Data([0x89, 0x50, 0x4e, 0x47])
        let client = DatalabClient(
            session: Ticket02MockURLProtocol.makeSession(
                scenario: scenario,
                expectedPNG: png
            ),
            policy: policy
        )
        do {
            _ = try await client.recognize(
                pngData: png,
                token: "ticket02-non-secret-sentinel",
                mode: .fast
            )
            return false
        } catch {
            let snapshot = Ticket02MockURLProtocol.snapshot()
            let actualCode = (error as? AppError)?.diagnosticCode
            let passed = actualCode == code
                && (pollCount == nil || snapshot.pollCount == pollCount)
                && (minimumPollCount == nil || snapshot.pollCount >= minimumPollCount!)
            if !passed {
                print(
                    "TICKET02_FAILURE_CASE scenario=\(String(describing: scenario)) "
                    + "expected=\(code.rawValue) actual=\(actualCode?.rawValue ?? "non-domain") "
                    + "polls=\(snapshot.pollCount)"
                )
            }
            return passed
        }
    }

    private static func retriesOneTransientPoll() async -> Bool {
        let png = Data([0x89, 0x50, 0x4e, 0x47])
        let policy = DatalabClient.Policy(
            timeout: .seconds(1),
            initialPollDelay: .milliseconds(1),
            maximumPollDelay: .milliseconds(2),
            transientRetryDelay: .milliseconds(1)
        )
        do {
            let client = DatalabClient(
                session: Ticket02MockURLProtocol.makeSession(
                    scenario: .transientPollThenSuccess,
                    expectedPNG: png
                ),
                policy: policy
            )
            let result = try await client.recognize(
                pngData: png,
                token: "ticket02-non-secret-sentinel",
                mode: .fast
            )
            return Ticket02MockURLProtocol.snapshot().pollCount == 2
                && result.automaticRetryCount == 1
        } catch {
            return false
        }
    }

    private static func submitsFastRecognitionContract() async -> Bool {
        let png = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        let client = DatalabClient(
            session: Ticket02MockURLProtocol.makeSession(
                scenario: .conversionSuccess,
                expectedPNG: png
            )
        )
        do {
            let result = try await client.recognize(
                pngData: png,
                token: "ticket02-non-secret-sentinel",
                mode: .fast
            )
            let snapshot = Ticket02MockURLProtocol.snapshot()
            let passed = snapshot.submitCount == 1
                && snapshot.pollCount == 2
                && snapshot.pngMatched
                && snapshot.approvedFieldsOnly
                && snapshot.fastMode
                && snapshot.pollingAuthenticationPresent
                && result.markdown == "ticket02 result"
                && result.html != nil
                && result.runtime == 1.25
                && result.costValue == 0.42
                && result.parseQualityScore == 4.5
            if !passed {
                print(
                    "TICKET02_FAST_CONTRACT "
                    + "submit=\(snapshot.submitCount) poll=\(snapshot.pollCount) "
                    + "png=\(snapshot.pngMatched) fields=\(snapshot.approvedFieldsOnly) "
                    + "fast=\(snapshot.fastMode) poll_auth=\(snapshot.pollingAuthenticationPresent) "
                    + "html=\(result.html != nil) runtime=\(result.runtime != nil) "
                    + "cost=\(result.costValue != nil) quality=\(result.parseQualityScore != nil)"
                )
            }
            return passed
        } catch {
            print("TICKET02_FAST_CONTRACT request=failed")
            return false
        }
    }

    private static func validatesTokenWithoutRecognition() async -> Bool {
        do {
            let client = DatalabClient(
                session: Ticket02MockURLProtocol.makeSession(scenario: .healthOK)
            )
            try await client.validateToken("ticket02-non-secret-sentinel")
            let snapshot = Ticket02MockURLProtocol.snapshot()
            guard snapshot.healthCount == 1,
                  snapshot.submitCount == 0,
                  snapshot.usedGET,
                  snapshot.authenticationPresent,
                  snapshot.requestBodyAbsent else { return false }
        } catch {
            return false
        }

        do {
            let client = DatalabClient(
                session: Ticket02MockURLProtocol.makeSession(scenario: .invalidCredentials)
            )
            try await client.validateToken("ticket02-non-secret-sentinel")
            return false
        } catch {
            return error.localizedDescription == AppError.invalidCredentials.localizedDescription
        }
    }

    private final class LockedResult: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = false
        private var completed = false

        var isComplete: Bool {
            lock.withLock { completed }
        }

        var value: Bool {
            lock.withLock { storage }
        }

        func finish(with value: Bool) {
            lock.withLock {
                storage = value
                completed = true
            }
        }
    }
}
