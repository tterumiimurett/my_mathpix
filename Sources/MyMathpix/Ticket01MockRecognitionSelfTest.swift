import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Ticket01MockRecognitionSelfTest {
    static func runBlocking() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        let result = LockedResult()
        Task.detached {
            result.value = await run()
            semaphore.signal()
        }
        semaphore.wait()
        if !result.value {
            let snapshot = Ticket01MockURLProtocol.snapshot()
            print(
                "TICKET01_MOCK_PROTOCOL_FAIL "
                + "submit=\(snapshot.submitCount) polls=\(snapshot.pollCount) "
                + "png=\(snapshot.pngWasValid ? "yes" : "no") "
                + "fields=\(snapshot.fieldsWereApproved ? "yes" : "no") "
                + "fixture=\(snapshot.fixtureWasValid ? "yes" : "no") "
                + "guard=\(snapshot.guardBandWasAbsent ? "yes" : "no") "
                + "result=\(snapshot.resultWasReturned ? "yes" : "no")"
            )
        }
        return result.value
    }

    private static func run() async -> Bool {
        guard let png = syntheticPNG(includeGuardBand: false),
              let contentlessPNG = syntheticPNG(
                  includeGuardBand: false,
                  includeRecognitionContent: false
              ),
              let missingMarkerPNG = syntheticPNG(
                  includeGuardBand: false,
                  omittedMarkerIndex: 2
              ),
              let guardedPNG = syntheticPNG(includeGuardBand: true),
              let displayConvertedGuardedPNG = syntheticPNG(
                  includeGuardBand: true,
                  useDisplayConvertedGuardColor: true
              ),
              let obscuredPNG = syntheticPNG(
                  includeGuardBand: false,
                  obscureCenterCell: true
              ),
              let realisticPNG = syntheticPNG(
                  includeGuardBand: false,
                  colorShift: -22
              ),
              let displayConvertedPNG = syntheticPNG(
                  includeGuardBand: false,
                  useDisplayConvertedMarkerColors: true
              ),
              let displayP3PNG = convertedToDisplayP3PNG(png),
              let displayP3GuardedPNG = convertedToDisplayP3PNG(guardedPNG) else {
            return false
        }
        let safeValidation = Ticket01FixtureImageValidator.validate(png)
        let contentlessValidation = Ticket01FixtureImageValidator.validate(contentlessPNG)
        let guardedValidation = Ticket01FixtureImageValidator.validate(guardedPNG)
        let displayConvertedGuardedValidation = Ticket01FixtureImageValidator.validate(
            displayConvertedGuardedPNG
        )
        let obscuredValidation = Ticket01FixtureImageValidator.validate(obscuredPNG)
        let realisticValidation = Ticket01FixtureImageValidator.validate(realisticPNG)
        let displayConvertedValidation = Ticket01FixtureImageValidator.validate(displayConvertedPNG)
        let displayP3Validation = Ticket01FixtureImageValidator.validate(displayP3PNG)
        let displayP3GuardedValidation = Ticket01FixtureImageValidator.validate(displayP3GuardedPNG)
        guard safeValidation.fixtureMarkersPresent,
              safeValidation.fixtureCoverageComplete,
              safeValidation.fixtureContentPresent,
              safeValidation.guardBandAbsent,
              contentlessValidation.fixtureMarkersPresent,
              contentlessValidation.fixtureCoverageComplete,
              !contentlessValidation.fixtureContentPresent,
              contentlessValidation.guardBandAbsent,
              realisticValidation.fixtureMarkersPresent,
              realisticValidation.fixtureCoverageComplete,
              realisticValidation.fixtureContentPresent,
              realisticValidation.guardBandAbsent,
              displayConvertedValidation.fixtureMarkersPresent,
              displayConvertedValidation.fixtureCoverageComplete,
              displayConvertedValidation.fixtureContentPresent,
              displayConvertedValidation.guardBandAbsent,
              displayP3Validation.fixtureMarkersPresent,
              displayP3Validation.fixtureCoverageComplete,
              displayP3Validation.fixtureContentPresent,
              displayP3Validation.guardBandAbsent,
              displayP3GuardedValidation.fixtureMarkersPresent,
              displayP3GuardedValidation.fixtureCoverageComplete,
              !displayP3GuardedValidation.guardBandAbsent,
              obscuredValidation.fixtureMarkersPresent,
              !obscuredValidation.fixtureCoverageComplete,
              obscuredValidation.guardBandAbsent,
              guardedValidation.fixtureMarkersPresent,
              guardedValidation.fixtureCoverageComplete,
              !guardedValidation.guardBandAbsent,
              displayConvertedGuardedValidation.fixtureMarkersPresent,
              displayConvertedGuardedValidation.fixtureCoverageComplete,
              !displayConvertedGuardedValidation.guardBandAbsent else {
            print(
                "TICKET01_FIXTURE_VALIDATOR_FAIL "
                + "safe_fixture=\(safeValidation.fixtureMarkersPresent ? "yes" : "no") "
                + "safe_content=\(safeValidation.fixtureContentPresent ? "yes" : "no") "
                + "safe_guard=\(safeValidation.guardBandAbsent ? "yes" : "no") "
                + "contentless_content=\(contentlessValidation.fixtureContentPresent ? "yes" : "no") "
                + "realistic_fixture=\(realisticValidation.fixtureMarkersPresent ? "yes" : "no") "
                + "realistic_coverage=\(realisticValidation.fixtureCoverageComplete ? "yes" : "no") "
                + "converted_markers=\(displayConvertedValidation.fixtureMarkersPresent ? "yes" : "no") "
                + "obscured_coverage=\(obscuredValidation.fixtureCoverageComplete ? "yes" : "no") "
                + "guarded_fixture=\(guardedValidation.fixtureMarkersPresent ? "yes" : "no") "
                + "guarded_guard=\(guardedValidation.guardBandAbsent ? "yes" : "no") "
                + "converted_guard=\(displayConvertedGuardedValidation.guardBandAbsent ? "missed" : "detected")"
            )
            return false
        }
        let duplicateModeRejected = await rejectsMalformedMultipart(
            png: png,
            duplicateMode: true
        )
        let wrongModeRejected = await rejectsMalformedMultipart(
            png: png,
            mode: "unexpected"
        )
        let duplicateFileRejected = await rejectsMalformedMultipart(
            png: png,
            duplicateFile: true
        )
        let invalidMediaTypeRejected = await rejectsMalformedMultipart(
            png: png,
            mediaType: "application/json"
        )
        let missingSentinelRecorded = await rejectsMalformedMultipart(
            png: png,
            includeSentinel: false,
            expectedCode: "request_contract"
        )
        let invalidPNGRejected = await rejectsMalformedMultipart(
            png: Data("not-a-png".utf8),
            expectedCode: "invalid_png"
        )
        let missingMarkersRejected = await rejectsMalformedMultipart(
            png: missingMarkerPNG,
            expectedCode: "fixture_markers"
        )
        let missingCoverageRejected = await rejectsMalformedMultipart(
            png: obscuredPNG,
            expectedCode: "fixture_coverage"
        )
        let missingContentRejected = await rejectsMalformedMultipart(
            png: contentlessPNG,
            expectedCode: "fixture_content"
        )
        let guardBandRejected = await rejectsMalformedMultipart(
            png: guardedPNG,
            expectedCode: "guard_band"
        )
        let unexpectedRequestRejected = await rejectsUnexpectedRequest()
        let trustedHostMatched = Ticket01MockURLProtocol.canInit(
            with: URLRequest(url: URL(string: "https://api.datalab.to/mock/check")!)
        )
        let deceptiveHostRejected = !Ticket01MockURLProtocol.canInit(
            with: URLRequest(url: URL(string: "https://notdatalab.to/mock/check")!)
        )
        guard duplicateModeRejected,
              wrongModeRejected,
              duplicateFileRejected,
              invalidMediaTypeRejected,
              missingSentinelRecorded,
              invalidPNGRejected,
              missingMarkersRejected,
              missingCoverageRejected,
              missingContentRejected,
              guardBandRejected,
              unexpectedRequestRejected else {
            print(
                "TICKET01_MULTIPART_VALIDATION "
                + "duplicate_mode=\(duplicateModeRejected ? "rejected" : "accepted") "
                + "wrong_mode=\(wrongModeRejected ? "rejected" : "accepted") "
                + "duplicate_file=\(duplicateFileRejected ? "rejected" : "accepted") "
                + "invalid_media_type=\(invalidMediaTypeRejected ? "rejected" : "accepted") "
                + "missing_sentinel_submit=\(missingSentinelRecorded ? "recorded" : "missing") "
                + "invalid_png=\(invalidPNGRejected ? "rejected" : "ambiguous") "
                + "markers=\(missingMarkersRejected ? "rejected" : "ambiguous") "
                + "coverage=\(missingCoverageRejected ? "rejected" : "ambiguous") "
                + "content=\(missingContentRejected ? "rejected" : "ambiguous") "
                + "guard=\(guardBandRejected ? "rejected" : "ambiguous") "
                + "unexpected_request=\(unexpectedRequestRejected ? "rejected" : "unreadable")"
            )
            return false
        }
        guard trustedHostMatched, deceptiveHostRejected else {
            print(
                "TICKET01_MOCK_HOST_VALIDATION "
                + "trusted=\(trustedHostMatched ? "accepted" : "rejected") "
                + "deceptive=\(deceptiveHostRejected ? "rejected" : "accepted")"
            )
            return false
        }
        do {
            let rejectingClient = DatalabClient(session: Ticket01MockURLProtocol.makeSession())
            _ = try await rejectingClient.recognize(
                pngData: guardedPNG,
                token: Ticket01MockContract.sentinelToken,
                mode: .fast
            )
            print("TICKET01_MOCK_REJECTION_MESSAGE readable=no")
            return false
        } catch {
            guard error.localizedDescription.contains("red guard band") else {
                print("TICKET01_MOCK_REJECTION_MESSAGE readable=no")
                return false
            }
        }
        let failedEvidence = Ticket01AcceptanceReporter.recognitionFailureEvidence(
            starting: Ticket01AcceptanceReporter.Evidence(),
            snapshot: Ticket01MockURLProtocol.snapshot(),
            recentHistoryCount: 1
        )
        let failureEvidenceRecorded = failedEvidence.phase == "failed"
            && failedEvidence.failureCode == "recognition_failed"
            && failedEvidence.submitCount == 1
            && failedEvidence.pngValid
            && failedEvidence.fieldsApproved
            && failedEvidence.fixtureValid
            && !failedEvidence.guardBandAbsent
            && failedEvidence.recentHistoryCount == 1
        guard failureEvidenceRecorded else {
            print("TICKET01_RECOGNITION_FAILURE_EVIDENCE recorded=no")
            return false
        }
        do {
            let client = DatalabClient(session: Ticket01MockURLProtocol.makeSession())
            let recognition = try await client.recognize(
                pngData: png,
                token: Ticket01MockContract.sentinelToken,
                mode: .fast
            )
            let snapshot = Ticket01MockURLProtocol.snapshot()
            let independentlyExpectedMarkdown = """
            $$x^2 + y^2 = z^2$$

            | a | b |
            |---|---|
            | 1 | 2 |

            TICKET 01 SAFE FIXTURE
            """
            return snapshot.submitCount == 1
                && snapshot.pollCount >= 2
                && snapshot.pngWasValid
                && snapshot.fieldsWereApproved
                && snapshot.fixtureWasValid
                && snapshot.guardBandWasAbsent
                && snapshot.resultWasReturned
                && recognition.markdown == independentlyExpectedMarkdown
                && MarkdownRenderer.document(for: recognition.markdown).contains("<table>")
        } catch {
            return false
        }
    }

    private static func syntheticPNG(
        includeGuardBand: Bool,
        includeRecognitionContent: Bool = true,
        obscureCenterCell: Bool = false,
        colorShift: Int = 0,
        omittedMarkerIndex: Int? = nil,
        useDisplayConvertedMarkerColors: Bool = false,
        useDisplayConvertedGuardColor: Bool = false
    ) -> Data? {
        let width = 80
        let height = 60
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        for y in 0..<height {
            for x in 0..<width {
                let pattern = syntheticPatternColors[(x / 8 + y / 8) % 2]
                bitmap.setColor(
                    color(pattern, shiftedBy: colorShift),
                    atX: x,
                    y: y
                )
            }
        }
        if includeRecognitionContent {
            let ink = NSColor(
                deviceRed: 17 / 255,
                green: 24 / 255,
                blue: 39 / 255,
                alpha: 1
            )
            for y in [18, 30, 42] {
                for x in 8..<(width - 8) {
                    bitmap.setColor(ink, atX: x, y: y)
                }
            }
            for x in [20, 40, 60] {
                for y in 18...42 {
                    bitmap.setColor(ink, atX: x, y: y)
                }
            }
        }
        let markerPalette = useDisplayConvertedMarkerColors
            ? displayConvertedMarkerColors
            : syntheticMarkerColors
        let markerColors = markerPalette.map {
            color($0, shiftedBy: colorShift)
        }
        let origins = [(4, 4), (66, 4), (4, 46), (66, 46)]
        for (index, origin) in origins.enumerated() {
            if index == omittedMarkerIndex { continue }
            for y in origin.1..<(origin.1 + 10) {
                for x in origin.0..<(origin.0 + 10) {
                    bitmap.setColor(markerColors[index], atX: x, y: y)
                }
            }
        }
        if obscureCenterCell {
            let obstructionColor = NSColor(
                deviceRed: 0,
                green: 0,
                blue: 0,
                alpha: 1
            )
            for y in 0..<height {
                for x in 0..<width where x * 3 / width == 1 && y * 3 / height == 1 {
                    bitmap.setColor(obstructionColor, atX: x, y: y)
                }
            }
        }
        if includeGuardBand {
            let guardColor = color(
                useDisplayConvertedGuardColor
                    ? displayConvertedGuardColor
                    : syntheticGuardColor,
                shiftedBy: colorShift
            )
            for y in 26..<34 {
                for x in 0..<width {
                    bitmap.setColor(guardColor, atX: x, y: y)
                }
            }
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func convertedToDisplayP3PNG(_ png: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let displayP3 = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(
                  data: nil,
                  width: image.width,
                  height: image.height,
                  bitsPerComponent: 8,
                  bytesPerRow: image.width * 4,
                  space: displayP3,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let convertedImage = context.makeImage() else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, convertedImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private static func rejectsMalformedMultipart(
        png: Data,
        mode: String = "fast",
        duplicateMode: Bool = false,
        duplicateFile: Bool = false,
        mediaType: String = "multipart/form-data",
        includeSentinel: Bool = true,
        expectedCode: String = "multipart_contract"
    ) async -> Bool {
        let boundary = "Ticket01MalformedBoundary"
        var body = Data()
        let fields = [
            ("mode", mode),
            ("output_format", "markdown,html"),
            ("disable_image_extraction", "true"),
            ("disable_image_captions", "true"),
            ("save_checkpoint", "false")
        ]
        for (name, value) in fields {
            appendTextPart(name: name, value: value, boundary: boundary, to: &body)
        }
        if duplicateMode {
            appendTextPart(name: "mode", value: "fast", boundary: boundary, to: &body)
        }
        appendFilePart(png: png, boundary: boundary, to: &body)
        if duplicateFile {
            appendFilePart(png: png, boundary: boundary, to: &body)
        }
        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: URL(string: "https://www.datalab.to/api/v1/convert")!)
        request.httpMethod = "POST"
        if includeSentinel {
            request.setValue(Ticket01MockContract.sentinelToken, forHTTPHeaderField: "X-API-Key")
        }
        request.setValue("\(mediaType); boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (data, response) = try await Ticket01MockURLProtocol.makeSession().data(for: request)
            let snapshot = Ticket01MockURLProtocol.snapshot()
            guard (response as? HTTPURLResponse)?.statusCode == 422,
                  snapshot.submitCount == 1,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["error"] as? String,
                  let code = json["error_code"] as? String else { return false }
            return code == expectedCode && message.contains("mock rejected")
        } catch {
            return false
        }
    }

    private static func rejectsUnexpectedRequest() async -> Bool {
        let request = URLRequest(url: URL(string: "https://www.datalab.to/mock/unexpected")!)
        do {
            let (data, response) = try await Ticket01MockURLProtocol.makeSession().data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 422,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["error"] as? String,
                  let code = json["error_code"] as? String else { return false }
            return code == "unexpected_request" && message.contains("mock rejected")
        } catch {
            return false
        }
    }

    private static func appendTextPart(
        name: String,
        value: String,
        boundary: String,
        to body: inout Data
    ) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        body.append(Data("\(value)\r\n".utf8))
    }

    private static func appendFilePart(png: Data, boundary: String, to body: inout Data) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"snippet.png\"\r\n".utf8))
        body.append(Data("Content-Type: image/png\r\n\r\n".utf8))
        body.append(png)
        body.append(Data("\r\n".utf8))
    }

    private static func color(
        _ rgb: Ticket01FixtureImageValidator.RGB,
        shiftedBy shift: Int
    ) -> NSColor {
        NSColor(
            deviceRed: CGFloat(max(0, min(255, rgb.red + shift))) / 255,
            green: CGFloat(max(0, min(255, rgb.green + shift))) / 255,
            blue: CGFloat(max(0, min(255, rgb.blue + shift))) / 255,
            alpha: 1
        )
    }

    // Independent literals mirror ticket01_fixture.html rather than reusing the
    // validator's implementation constants.
    private static let syntheticMarkerColors = [
        Ticket01FixtureImageValidator.RGB(red: 6, green: 182, blue: 212),
        Ticket01FixtureImageValidator.RGB(red: 168, green: 85, blue: 247),
        Ticket01FixtureImageValidator.RGB(red: 245, green: 158, blue: 11),
        Ticket01FixtureImageValidator.RGB(red: 59, green: 130, blue: 246)
    ]
    private static let syntheticPatternColors = [
        Ticket01FixtureImageValidator.RGB(red: 209, green: 250, blue: 229),
        Ticket01FixtureImageValidator.RGB(red: 236, green: 252, blue: 203)
    ]
    private static let syntheticGuardColor = Ticket01FixtureImageValidator.RGB(
        red: 244,
        green: 63,
        blue: 94
    )
    private static let displayConvertedGuardColor =
        Ticket01FixtureImageValidator.RGB(red: 255, green: 0, blue: 100)
    private static let displayConvertedMarkerColors = [
        Ticket01FixtureImageValidator.RGB(red: 0, green: 140, blue: 255),
        Ticket01FixtureImageValidator.RGB(red: 255, green: 0, blue: 180),
        Ticket01FixtureImageValidator.RGB(red: 255, green: 210, blue: 0),
        Ticket01FixtureImageValidator.RGB(red: 0, green: 90, blue: 255)
    ]

    private final class LockedResult: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = false

        var value: Bool {
            get { lock.withLock { storage } }
            set { lock.withLock { storage = newValue } }
        }
    }
}
