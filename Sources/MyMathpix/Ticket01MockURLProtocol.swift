import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Ticket01MockContract {
    static let sentinelToken = "ticket01-non-secret-sentinel"
    static let expectedCanonicalMarkdown = """
    $$x^2 + y^2 = z^2$$

    | a | b |
    |---|---|
    | 1 | 2 |

    TICKET 01 SAFE FIXTURE
    """
}

final class Ticket01MockURLProtocol: URLProtocol {
    struct Snapshot: Equatable, Sendable {
        var submitCount = 0
        var pollCount = 0
        var pngWasValid = false
        var fieldsWereApproved = false
        var fixtureWasValid = false
        var guardBandWasAbsent = false
        var resultWasReturned = false
        var pixelWidth = 0
        var pixelHeight = 0
    }

    private struct MultipartPart {
        let name: String
        let filename: String?
        let contentType: String?
        let data: Data
    }

    private struct MultipartInspection {
        let png: Data?
        let fieldsWereApproved: Bool
    }

    private enum RejectionReason {
        case requestContract
        case multipartContract
        case invalidPNG
        case fixtureMarkers
        case fixtureCoverage
        case fixtureContent
        case guardBand
        case unexpectedRequest

        var code: String {
            switch self {
            case .requestContract: "request_contract"
            case .multipartContract: "multipart_contract"
            case .invalidPNG: "invalid_png"
            case .fixtureMarkers: "fixture_markers"
            case .fixtureCoverage: "fixture_coverage"
            case .fixtureContent: "fixture_content"
            case .guardBand: "guard_band"
            case .unexpectedRequest: "unexpected_request"
            }
        }

        var message: String {
            switch self {
            case .requestContract:
                "Ticket 01 mock rejected the request contract."
            case .multipartContract:
                "Ticket 01 mock rejected the multipart contract."
            case .invalidPNG:
                "Ticket 01 mock rejected an invalid PNG."
            case .fixtureMarkers:
                "Ticket 01 mock rejected incomplete fixture markers."
            case .fixtureCoverage:
                "Ticket 01 mock rejected incomplete fixture coverage."
            case .fixtureContent:
                "Ticket 01 mock rejected missing formula or table content."
            case .guardBand:
                "Ticket 01 mock rejected a selection containing the red guard band."
            case .unexpectedRequest:
                "Ticket 01 mock rejected an unexpected request contract."
            }
        }
    }

    private static let lock = NSLock()
    private static var current = Snapshot()

    static func makeSession() -> URLSession {
        reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Ticket01MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        lock.withLock { current = Snapshot() }
    }

    static func snapshot() -> Snapshot {
        lock.withLock { current }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host?.lowercased() else { return false }
        return host == "datalab.to"
            || host == "www.datalab.to"
            || host.hasSuffix(".datalab.to")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let response = try response(for: request)
            client?.urlProtocol(self, didReceive: response.http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            let url = request.url ?? URL(string: "https://www.datalab.to/mock/invalid")!
            let rejection = rejectionResponse(url: url, reason: .unexpectedRequest)
            client?.urlProtocol(self, didReceive: rejection.http, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: rejection.data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    private func response(for request: URLRequest) throws -> (http: HTTPURLResponse, data: Data) {
        guard let url = request.url else { throw AppError.invalidResponse("mock request had no URL") }
        if request.httpMethod == "POST", url.path == "/api/v1/convert" {
            return try submitResponse(request: request, url: url)
        }
        if request.httpMethod == "GET", url.path == "/mock/ticket01-check" {
            return pollResponse(url: url)
        }
        throw AppError.invalidResponse("mock received an unexpected request")
    }

    private func submitResponse(request: URLRequest, url: URL) throws -> (HTTPURLResponse, Data) {
        Self.lock.withLock { Self.current.submitCount += 1 }
        guard request.value(forHTTPHeaderField: "X-API-Key") == Ticket01MockContract.sentinelToken else {
            return rejectionResponse(url: url, reason: .requestContract)
        }
        guard let contentType = request.value(forHTTPHeaderField: "Content-Type"),
              let boundary = multipartBoundary(from: contentType),
              let body = requestBody(request) else {
            return rejectionResponse(url: url, reason: .multipartContract)
        }

        let inspection = inspectMultipart(body, boundary: boundary)
        let png = inspection.png
        let dimensions = png.flatMap(Self.pngDimensions)
        let fixtureValidation = png.map(Ticket01FixtureImageValidator.validate)
        let validPNG = dimensions != nil
        let approvedFields = inspection.fieldsWereApproved
        let validFixture = fixtureValidation?.fixtureMarkersPresent == true
            && fixtureValidation?.fixtureCoverageComplete == true
            && fixtureValidation?.fixtureContentPresent == true
        let guardBandAbsent = fixtureValidation?.guardBandAbsent == true

        Self.lock.withLock {
            Self.current.pngWasValid = validPNG
            Self.current.fieldsWereApproved = approvedFields
            Self.current.fixtureWasValid = validFixture
            Self.current.guardBandWasAbsent = guardBandAbsent
            Self.current.pixelWidth = dimensions?.width ?? 0
            Self.current.pixelHeight = dimensions?.height ?? 0
        }
        if !approvedFields { return rejectionResponse(url: url, reason: .multipartContract) }
        if !validPNG { return rejectionResponse(url: url, reason: .invalidPNG) }
        if fixtureValidation?.fixtureMarkersPresent != true {
            return rejectionResponse(url: url, reason: .fixtureMarkers)
        }
        if fixtureValidation?.fixtureCoverageComplete != true {
            return rejectionResponse(url: url, reason: .fixtureCoverage)
        }
        if fixtureValidation?.fixtureContentPresent != true {
            return rejectionResponse(url: url, reason: .fixtureContent)
        }
        if !guardBandAbsent { return rejectionResponse(url: url, reason: .guardBand) }

        return (
            httpResponse(url: url),
            jsonData([
                "success": true,
                "request_check_url": "https://www.datalab.to/mock/ticket01-check"
            ])
        )
    }

    private func multipartBoundary(from contentType: String) -> String? {
        let components = contentType.split(
            separator: ";",
            omittingEmptySubsequences: false
        ).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.count == 2,
              components[0].lowercased() == "multipart/form-data" else { return nil }
        let assignment = components[1].split(
            separator: "=",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).map(String.init)
        guard assignment.count == 2,
              assignment[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "boundary" else {
            return nil
        }
        var boundary = assignment[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if boundary.count >= 2, boundary.first == "\"", boundary.last == "\"" {
            boundary.removeFirst()
            boundary.removeLast()
        }
        return boundary.isEmpty ? nil : boundary
    }

    private func rejectionResponse(
        url: URL,
        reason: RejectionReason
    ) -> (http: HTTPURLResponse, data: Data) {
        (
            httpResponse(url: url, statusCode: 422),
            jsonData([
                "success": false,
                "error_code": reason.code,
                "error": reason.message
            ])
        )
    }

    private func pollResponse(url: URL) -> (HTTPURLResponse, Data) {
        let pollCount = Self.lock.withLock { () -> Int in
            Self.current.pollCount += 1
            return Self.current.pollCount
        }
        if pollCount < 5 {
            return (httpResponse(url: url), jsonData(["status": "processing", "success": true]))
        }

        Self.lock.withLock { Self.current.resultWasReturned = true }
        return (
            httpResponse(url: url),
            jsonData([
                "status": "complete",
                "success": true,
                "markdown": Ticket01MockContract.expectedCanonicalMarkdown,
                "html": "<p>Ticket 01 fixture</p>",
                "runtime": 2.8,
                "cost_breakdown": 0
            ])
        )
    }

    private func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { return nil }
            if count == 0 { return data }
            data.append(buffer, count: count)
        }
    }

    private func inspectMultipart(_ body: Data, boundary: String) -> MultipartInspection {
        guard let parts = multipartParts(in: body, boundary: boundary) else {
            return MultipartInspection(png: nil, fieldsWereApproved: false)
        }
        let expectedFields = [
            "mode": "fast",
            "output_format": "markdown,html",
            "disable_image_extraction": "true",
            "disable_image_captions": "true",
            "save_checkpoint": "false"
        ]
        var scalarValues: [String: String] = [:]
        var scalarFieldsAreValid = true
        var fileParts: [MultipartPart] = []
        for part in parts {
            if part.filename != nil || part.name == "file" {
                fileParts.append(part)
                continue
            }
            guard part.contentType == nil,
                  expectedFields[part.name] != nil,
                  scalarValues[part.name] == nil,
                  let value = String(data: part.data, encoding: .utf8) else {
                scalarFieldsAreValid = false
                continue
            }
            scalarValues[part.name] = value
        }
        let file = fileParts.first
        let fileIsValid = fileParts.count == 1
            && file?.name == "file"
            && file?.filename == "snippet.png"
            && file?.contentType?.lowercased() == "image/png"
        return MultipartInspection(
            png: file?.data,
            fieldsWereApproved: parts.count == expectedFields.count + 1
                && scalarFieldsAreValid
                && scalarValues == expectedFields
                && fileIsValid
        )
    }

    private func multipartParts(in body: Data, boundary: String) -> [MultipartPart]? {
        let openingBoundary = Data("--\(boundary)\r\n".utf8)
        let closingBoundary = Data("--\(boundary)--\r\n".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        let nextBoundaryPrefix = Data("\r\n--\(boundary)".utf8)
        guard body.starts(with: openingBoundary) else { return nil }

        var parts: [MultipartPart] = []
        var boundaryStart = body.startIndex
        while true {
            guard body[boundaryStart...].starts(with: openingBoundary) else { return nil }
            let partStart = body.index(boundaryStart, offsetBy: openingBoundary.count)
            guard let headerRange = body.range(
                of: headerSeparator,
                in: partStart..<body.endIndex
            ),
            let nextBoundaryRange = body.range(
                of: nextBoundaryPrefix,
                in: headerRange.upperBound..<body.endIndex
            ),
            let part = multipartPart(
                headers: body.subdata(in: partStart..<headerRange.lowerBound),
                data: body.subdata(in: headerRange.upperBound..<nextBoundaryRange.lowerBound)
            ) else { return nil }
            parts.append(part)

            let nextBoundaryStart = body.index(nextBoundaryRange.lowerBound, offsetBy: 2)
            if body[nextBoundaryStart...].starts(with: closingBoundary) {
                let expectedEnd = body.index(nextBoundaryStart, offsetBy: closingBoundary.count)
                return expectedEnd == body.endIndex ? parts : nil
            }
            guard body[nextBoundaryStart...].starts(with: openingBoundary) else { return nil }
            boundaryStart = nextBoundaryStart
        }
    }

    private func multipartPart(headers: Data, data: Data) -> MultipartPart? {
        guard let headerText = String(data: headers, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard (1...2).contains(lines.count),
              let regex = try? NSRegularExpression(
                pattern: #"^Content-Disposition: form-data; name=\"([^\"]+)\"(?:; filename=\"([^\"]+)\")?$"#
              ),
              let match = regex.firstMatch(
                in: lines[0],
                range: NSRange(lines[0].startIndex..., in: lines[0])
              ),
              match.range == NSRange(lines[0].startIndex..., in: lines[0]),
              let nameRange = Range(match.range(at: 1), in: lines[0]) else { return nil }
        let filename: String?
        if match.range(at: 2).location != NSNotFound,
           let range = Range(match.range(at: 2), in: lines[0]) {
            filename = String(lines[0][range])
        } else {
            filename = nil
        }
        let contentType: String?
        if lines.count == 2 {
            let prefix = "Content-Type: "
            guard lines[1].hasPrefix(prefix) else { return nil }
            contentType = String(lines[1].dropFirst(prefix.count))
        } else {
            contentType = nil
        }
        return MultipartPart(
            name: String(lines[0][nameRange]),
            filename: filename,
            contentType: contentType,
            data: data
        )
    }

    private static func pngDimensions(_ data: Data) -> (width: Int, height: Int)? {
        guard data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (image.width, image.height)
    }

    private func httpResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private func jsonData(_ value: [String: Any]) -> Data {
        // Values here are fixed synthetic fixtures; no request data is reflected.
        (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])) ?? Data()
    }
}

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
                && snapshot.pollCount == 5
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

struct Ticket01FixtureImageValidator {
    struct RGB {
        let red: Int
        let green: Int
        let blue: Int
    }

    struct Result {
        let fixtureMarkersPresent: Bool
        let fixtureCoverageComplete: Bool
        let fixtureContentPresent: Bool
        let guardBandAbsent: Bool
    }

    static let markerColors = [
        RGB(red: 6, green: 182, blue: 212),
        RGB(red: 168, green: 85, blue: 247),
        RGB(red: 245, green: 158, blue: 11),
        RGB(red: 59, green: 130, blue: 246)
    ]
    static let patternColors = [
        RGB(red: 209, green: 250, blue: 229),
        RGB(red: 236, green: 252, blue: 203)
    ]
    private static let guardColor = RGB(red: 244, green: 63, blue: 94)

    static func validate(_ pngData: Data) -> Result {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            return Result(
                fixtureMarkersPresent: false,
                fixtureCoverageComplete: false,
                fixtureContentPresent: false,
                guardBandAbsent: false
            )
        }
        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        guard let validationColorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: validationColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Result(
                fixtureMarkersPresent: false,
                fixtureCoverageComplete: false,
                fixtureContentPresent: false,
                guardBandAbsent: false
            )
        }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let stride = max(1, min(image.width, image.height) / 300)
        var markerMatches = Array(repeating: 0, count: markerColors.count)
        var spatialMarkerMatches = Array(repeating: 0, count: 4)
        var fixturePatternMatches = Array(repeating: 0, count: 9)
        var fixtureInkMatches = Array(repeating: 0, count: 9)
        var guardMatches = 0
        var sampledPixels = 0
        for y in Swift.stride(from: 0, to: image.height, by: stride) {
            for x in Swift.stride(from: 0, to: image.width, by: stride) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let sample = RGB(
                    red: Int(pixels[offset]),
                    green: Int(pixels[offset + 1]),
                    blue: Int(pixels[offset + 2])
                )
                sampledPixels += 1
                let column = min(2, x * 3 / image.width)
                let row = min(2, y * 3 / image.height)
                let region = row * 3 + column
                for (index, marker) in markerColors.enumerated() where matches(sample, marker, tolerance: 40) {
                    markerMatches[index] += 1
                }
                if isHighlySaturated(sample),
                   let corner = markerCorner(x: x, y: y, width: image.width, height: image.height) {
                    spatialMarkerMatches[corner] += 1
                }
                if patternColors.contains(where: { matches(sample, $0, tolerance: 40) }) {
                    fixturePatternMatches[region] += 1
                }
                if sample.red <= 80, sample.green <= 80, sample.blue <= 80 {
                    fixtureInkMatches[region] += 1
                }
                if isGuardColor(sample) {
                    guardMatches += 1
                }
            }
        }
        let markerThreshold = 4
        let guardThreshold = max(8, sampledPixels / 5_000)
        let exactMarkersPresent = markerMatches.allSatisfy { $0 >= markerThreshold }
        let spatialMarkersPresent = spatialMarkerMatches.allSatisfy { $0 >= markerThreshold }
        return Result(
            fixtureMarkersPresent: exactMarkersPresent || spatialMarkersPresent,
            fixtureCoverageComplete: fixturePatternMatches.allSatisfy { $0 >= 5 },
            fixtureContentPresent: fixtureInkMatches.filter { $0 >= 5 }.count >= 4,
            guardBandAbsent: guardMatches < guardThreshold
        )
    }

    private static func matches(_ lhs: RGB, _ rhs: RGB, tolerance: Int) -> Bool {
        abs(lhs.red - rhs.red) <= tolerance
            && abs(lhs.green - rhs.green) <= tolerance
            && abs(lhs.blue - rhs.blue) <= tolerance
    }

    private static func isHighlySaturated(_ color: RGB) -> Bool {
        let high = max(color.red, color.green, color.blue)
        let low = min(color.red, color.green, color.blue)
        return high >= 140 && high - low >= 80
    }

    private static func isGuardColor(_ color: RGB) -> Bool {
        if matches(color, guardColor, tolerance: 40) { return true }
        return color.red >= 150
            && color.red - color.green >= 95
            && color.red - color.blue >= 95
    }

    private static func markerCorner(
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) -> Int? {
        let horizontal: Int
        if x >= max(1, width / 40), x < width / 5 {
            horizontal = 0
        } else if x >= width * 4 / 5, x < width - max(1, width / 40) {
            horizontal = 1
        } else {
            return nil
        }

        let vertical: Int
        if y >= max(1, height / 20), y < height * 3 / 10 {
            vertical = 0
        } else if y >= height * 7 / 10, y < height - max(1, height / 20) {
            vertical = 1
        } else {
            return nil
        }
        return vertical * 2 + horizontal
    }
}

private extension NSLock {
    func withLock<T>(_ action: () -> T) -> T {
        lock()
        defer { unlock() }
        return action()
    }
}
