import Foundation

@MainActor
enum SelfCheck {
    static func run() -> Bool {
        var failures: [String] = []

        check(
            MarkdownNormalizer.normalize("# Result  \r\n\r\n\r\n$x$\t\r\n") == "# Result\n\n$x$",
            "Markdown normalization",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: "$$ x^2 + y^2 $$") == "x^2 + y^2",
            "display formula detection",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: "The answer is $x$.") == nil,
            "mixed content is not a pure formula",
            failures: &failures
        )
        check(
            MarkdownNormalizer.pureFormula(in: "$$x$$\n\n$$y$$") == nil,
            "multiple formulas are not a pure formula",
            failures: &failures
        )

        let table = """
        | Name | Value |
        | --- | ---: |
        | x | $1$ |
        | y | 2 |
        """
        check(
            MarkdownNormalizer.markdownTableTSV(from: table) == "Name\tValue\nx\t$1$\ny\t2",
            "Markdown table to TSV",
            failures: &failures
        )

        let preview = MarkdownRenderer.document(for: "$$x^2$$\n\n\(table)")
        check(preview.contains("data-display=\"1\""), "formula preview marker", failures: &failures)
        check(preview.contains("<table>"), "table preview", failures: &failures)
        check(
            !preview.contains("src=\"http") && !preview.contains("href=\"http") && !preview.contains("url(http"),
            "offline preview",
            failures: &failures
        )
        let escaped = MarkdownRenderer.renderBody("<script>alert('x')</script>")
        check(!escaped.contains("<script>alert") && escaped.contains("&lt;script&gt;"), "raw HTML escaping", failures: &failures)

        let secondaryDisplayFrame = CGRect(x: -1_440, y: 200, width: 1_440, height: 900)
        let captureRequest = ScreenCaptureRequest(
            displayID: 42,
            selectionInDisplay: CGRect(x: 100.25, y: 50.5, width: 300.25, height: 120.25),
            displayFrame: secondaryDisplayFrame,
            scale: 2
        )
        check(
            captureRequest?.sourceRect == CGRect(x: 100.25, y: 729.25, width: 300.25, height: 120.25),
            "secondary display coordinate conversion",
            failures: &failures
        )
        check(
            captureRequest?.pixelWidth == 601 && captureRequest?.pixelHeight == 241,
            "Retina selection preserves fractional edge pixels",
            failures: &failures
        )
        check(
            !DisplayRole.isSecondary(displayID: 42, mainDisplayID: 42),
            "CG main display is classified as primary",
            failures: &failures
        )
        check(
            DisplayRole.isSecondary(displayID: 43, mainDisplayID: 42),
            "non-main display remains secondary after key-window changes",
            failures: &failures
        )
        check(
            ScreenCaptureRequest(
                displayID: 42,
                selectionInDisplay: CGRect(x: 10, y: 10, width: 3.9, height: 20),
                displayFrame: secondaryDisplayFrame,
                scale: 2
            ) == nil,
            "tiny selection is rejected before ScreenCaptureKit",
            failures: &failures
        )

        var captureLifecycle = ScreenCaptureLifecycle()
        check(captureLifecycle.begin(), "idle capture can begin", failures: &failures)
        check(
            !captureLifecycle.begin() && captureLifecycle.phase == .selecting,
            "second capture is blocked while selecting",
            failures: &failures
        )
        captureLifecycle.selectionCompleted()
        check(
            !captureLifecycle.begin() && captureLifecycle.phase == .capturing,
            "second capture is blocked while capturing",
            failures: &failures
        )
        captureLifecycle.finish()
        check(
            captureLifecycle.phase == .idle && captureLifecycle.begin(),
            "capture is operable again after completion",
            failures: &failures
        )
        captureLifecycle.cancel()

        let acceptanceRunID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let relaunchedAcceptance = AppLaunchConfiguration(
            arguments: ["MyMathpix"],
            acceptanceRelaunchMode: .acceptance(runID: acceptanceRunID)
        )
        check(
            relaunchedAcceptance.runsTicket01Acceptance
                && relaunchedAcceptance.ticket01Scenario == nil,
            "acceptance mode survives a LaunchServices restart",
            failures: &failures
        )
        let relaunchedPermissionScenario = AppLaunchConfiguration(
            arguments: ["MyMathpix"],
            acceptanceRelaunchMode: .scenario(.permissionRevoked, runID: acceptanceRunID)
        )
        check(
            relaunchedPermissionScenario.ticket01Scenario == .permissionRevoked,
            "acceptance scenario survives a LaunchServices restart",
            failures: &failures
        )
        check(
            Ticket01AcceptanceRelaunchMode.parse(
                "scenario:permission-denied:\(acceptanceRunID.uuidString)"
            ) == .scenario(.permissionDenied, runID: acceptanceRunID),
            "acceptance relaunch marker parses an approved scenario",
            failures: &failures
        )
        check(
            Ticket01AcceptanceRelaunchMode.parse("unexpected") == nil,
            "invalid acceptance relaunch marker is rejected",
            failures: &failures
        )
        check(
            !AppLaunchConfiguration(
                arguments: ["MyMathpix"],
                acceptanceRelaunchMode: nil
            ).runsTicket01Acceptance,
            "ordinary launch does not enter acceptance mode",
            failures: &failures
        )
        let explicitAcceptance = AppLaunchConfiguration(
            arguments: [
                "MyMathpix",
                "--ticket01-acceptance",
                "--ticket01-run-id=\(acceptanceRunID.uuidString)"
            ]
        )
        check(
            explicitAcceptance.runsTicket01Acceptance
                && explicitAcceptance.acceptanceRunID == acceptanceRunID,
            "explicit acceptance requires and preserves its run ID",
            failures: &failures
        )
        check(
            !AppLaunchConfiguration(
                arguments: ["MyMathpix", "--ticket01-acceptance"]
            ).runsTicket01Acceptance,
            "unbound acceptance argument is rejected",
            failures: &failures
        )
        do {
            let markerRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("MyMathpix-RelaunchMarker-SelfCheck-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: markerRoot) }
            try FileManager.default.createDirectory(at: markerRoot, withIntermediateDirectories: true)
            let markerURL = markerRoot.appendingPathComponent("relaunch-mode.txt")
            try Data("acceptance:\(acceptanceRunID.uuidString)\n".utf8).write(
                to: markerURL,
                options: .atomic
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: markerURL.path
            )
            let markerDate = Date(timeIntervalSince1970: 1_800_000_000)
            try FileManager.default.setAttributes(
                [.modificationDate: markerDate],
                ofItemAtPath: markerURL.path
            )
            check(
                Ticket01AcceptanceRelaunchMarker.load(
                    from: markerURL,
                    now: markerDate.addingTimeInterval(60)
                ) == .acceptance(runID: acceptanceRunID),
                "fresh private acceptance marker is accepted",
                failures: &failures
            )
            check(
                Ticket01AcceptanceRelaunchMarker.load(
                    from: markerURL,
                    now: markerDate.addingTimeInterval(16 * 60)
                ) == nil,
                "stale acceptance marker is rejected",
                failures: &failures
            )
            try FileManager.default.setAttributes(
                [
                    .posixPermissions: NSNumber(value: Int16(0o644)),
                    .modificationDate: markerDate
                ],
                ofItemAtPath: markerURL.path
            )
            check(
                Ticket01AcceptanceRelaunchMarker.load(
                    from: markerURL,
                    now: markerDate.addingTimeInterval(60)
                ) == nil,
                "non-private acceptance marker is rejected",
                failures: &failures
            )
            try FileManager.default.setAttributes(
                [
                    .posixPermissions: NSNumber(value: Int16(0o600)),
                    .modificationDate: markerDate
                ],
                ofItemAtPath: markerURL.path
            )
            check(
                Ticket01AcceptanceRelaunchMarker.consume(
                    from: markerURL,
                    now: markerDate.addingTimeInterval(60)
                ) == .acceptance(runID: acceptanceRunID),
                "private acceptance marker is consumed once",
                failures: &failures
            )
            check(
                !FileManager.default.fileExists(atPath: markerURL.path),
                "consumed acceptance marker cannot leak into a later launch",
                failures: &failures
            )
        } catch {
            failures.append("acceptance relaunch marker: \(error.localizedDescription)")
        }

        var failedEvidence = Ticket01AcceptanceReporter.Evidence()
        failedEvidence.phase = "failed"
        failedEvidence.failureCode = "recognition_failed"
        let restartedEvidence = Ticket01AcceptanceReporter.selectionStartedEvidence(
            starting: failedEvidence
        )
        check(
            restartedEvidence.phase == "selecting"
                && restartedEvidence.failureCode == nil
                && restartedEvidence.recoveryProbeStarted,
            "new capture clears stale acceptance failure state",
            failures: &failures
        )
        let permissionEvidence = Ticket01AcceptanceReporter.permissionObservationEvidence(
            starting: Ticket01AcceptanceReporter.Evidence(),
            preflightGranted: false,
            requestAttempted: true,
            requestGranted: false
        )
        check(
            permissionEvidence.permissionPreflightGranted == false
                && permissionEvidence.permissionRequestAttempted
                && permissionEvidence.permissionRequestGranted == false,
            "acceptance evidence records the real permission decision path",
            failures: &failures
        )

        let syntheticCaptureError = NSError(domain: "Ticket01Capture", code: 1)
        check(
            ScreenCaptureFailureMapper.map(
                syntheticCaptureError,
                hasScreenCaptureAccess: false
            ).diagnosticCode == .permissionDenied,
            "revoked ScreenCaptureKit failure maps to permission explanation",
            failures: &failures
        )
        check(
            ScreenCaptureFailureMapper.map(
                syntheticCaptureError,
                hasScreenCaptureAccess: true
            ).diagnosticCode == .captureAPIFailure,
            "ScreenCaptureKit failure maps to capture explanation",
            failures: &failures
        )
        check(
            ScreenCaptureFailureMapper.map(
                AppError.captureDisplayUnavailable,
                hasScreenCaptureAccess: true
            ).diagnosticCode == .displayUnavailable,
            "domain capture failures keep their diagnostic code",
            failures: &failures
        )

        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("MyMathpix-SelfCheck-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            let store = HistoryStore(rootURL: root)
            for index in 0..<21 {
                let item = try store.create(uploadPayload: UploadPayload(pngData: Data("image-\(index)".utf8)))
                var completed = item
                completed.status = .complete
                completed.markdown = "result \(index)"
                try store.update(completed)
            }
            check(store.items.count == 20, "history limit", failures: &failures)
            check(store.items.first?.markdown == "result 20", "newest history first", failures: &failures)
            check(store.items.first(where: { $0.markdown == "result 0" }) == nil, "oldest history deletion", failures: &failures)
        } catch {
            failures.append("history persistence: \(error.localizedDescription)")
        }

        do {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("MyMathpix-LocalToken-SelfCheck-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            let tokenStore = LocalTokenStore(rootURL: root)
            check(tokenStore.readToken() == nil, "local token starts empty", failures: &failures)
            try tokenStore.saveToken("  ticket01-local-non-secret  ")
            check(
                tokenStore.readToken() == "ticket01-local-non-secret",
                "local token save and read",
                failures: &failures
            )
            let attributes = try FileManager.default.attributesOfItem(atPath: tokenStore.storageURL.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
            check(permissions == 0o600, "local token file permissions", failures: &failures)
            try tokenStore.saveToken("ticket01-local-replacement-non-secret")
            check(
                tokenStore.readToken() == "ticket01-local-replacement-non-secret",
                "local token replacement",
                failures: &failures
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o644))],
                ofItemAtPath: tokenStore.storageURL.path
            )
            check(tokenStore.readToken() == nil, "unsafe local token is rejected", failures: &failures)
            try tokenStore.saveToken("ticket01-local-repaired-non-secret")
            check(
                tokenStore.hasPrivatePermissions,
                "local token replacement repairs permissions",
                failures: &failures
            )
            try tokenStore.saveToken("")
            check(tokenStore.readToken() == nil, "local token clear", failures: &failures)
        } catch {
            failures.append("local token persistence: \(error.localizedDescription)")
        }

        if failures.isEmpty {
            print("MyMathpix self-test passed (45 checks).")
            return true
        }
        print("MyMathpix self-test failed:")
        failures.forEach { print("- \($0)") }
        return false
    }

    private static func check(_ condition: Bool, _ name: String, failures: inout [String]) {
        if !condition { failures.append(name) }
    }
}
