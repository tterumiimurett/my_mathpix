import Foundation
import ImageIO

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

        var payload: (code: String, message: String) {
            switch self {
            case .requestContract:
                ("request_contract", "Ticket 01 mock rejected the request contract.")
            case .multipartContract:
                ("multipart_contract", "Ticket 01 mock rejected the multipart contract.")
            case .invalidPNG:
                ("invalid_png", "Ticket 01 mock rejected an invalid PNG.")
            case .fixtureMarkers:
                ("fixture_markers", "Ticket 01 mock rejected incomplete fixture markers.")
            case .fixtureCoverage:
                ("fixture_coverage", "Ticket 01 mock rejected incomplete fixture coverage.")
            case .fixtureContent:
                ("fixture_content", "Ticket 01 mock rejected missing formula or table content.")
            case .guardBand:
                ("guard_band", "Ticket 01 mock rejected a selection containing the red guard band.")
            case .unexpectedRequest:
                ("unexpected_request", "Ticket 01 mock rejected an unexpected request contract.")
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
        let payload = reason.payload
        return (
            httpResponse(url: url, statusCode: 422),
            jsonData([
                "success": false,
                "error_code": payload.code,
                "error": payload.message
            ])
        )
    }

    private func pollResponse(url: URL) -> (HTTPURLResponse, Data) {
        let pollCount = Self.lock.withLock { () -> Int in
            Self.current.pollCount += 1
            return Self.current.pollCount
        }
        if pollCount < 10 {
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
                "runtime": 7.8,
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
