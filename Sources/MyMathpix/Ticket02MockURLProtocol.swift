import Foundation

final class Ticket02MockURLProtocol: URLProtocol {
    enum Scenario {
        case healthOK
        case invalidCredentials
        case recognitionInvalidCredentials
        case conversionSuccess
        case transientPollThenSuccess
        case persistentTransientPoll
        case untrustedCheckURL
        case unapprovedDatalabSubdomainCheckURL
        case nonStatusCheckURL
        case pollHTTPRejection
        case malformedPollJSON
        case completionMissingHTML
        case unknownPollStatus
        case serviceFailure
        case processingForever
        case slowSubmit
        case untrustedRedirect
    }

    struct Snapshot: Equatable, Sendable {
        var healthCount = 0
        var submitCount = 0
        var usedGET = false
        var authenticationPresent = false
        var requestBodyAbsent = false
        var pollCount = 0
        var pngMatched = false
        var approvedFieldsOnly = false
        var fastMode = false
        var balancedMode = false
        var pollingAuthenticationPresent = false
        var untrustedRequestCount = 0
    }

    private struct MultipartPart {
        let name: String
        let filename: String?
        let contentType: String?
        let data: Data
    }

    private static let lock = NSLock()
    private static var scenario: Scenario = .healthOK
    private static var current = Snapshot()
    private static var expectedPNG: Data?
    private var delayedWorkItem: DispatchWorkItem?

    static func makeSession(scenario: Scenario, expectedPNG: Data? = nil) -> URLSession {
        configure(scenario: scenario, expectedPNG: expectedPNG)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Ticket02MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func configure(scenario: Scenario, expectedPNG: Data? = nil) {
        lock.withLock {
            self.scenario = scenario
            self.expectedPNG = expectedPNG
            current = Snapshot()
        }
    }

    static func snapshot() -> Snapshot {
        lock.withLock { current }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host?.lowercased() else { return false }
        return host == "datalab.to"
            || host == "www.datalab.to"
            || host.hasSuffix(".datalab.to")
            || host == "attacker.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if Self.delaysResponse(for: request) {
            let workItem = DispatchWorkItem { [weak self] in
                self?.deliverResponse()
            }
            delayedWorkItem = workItem
            DispatchQueue.global().asyncAfter(
                deadline: .now() + .milliseconds(30),
                execute: workItem
            )
            return
        }
        deliverResponse()
    }

    override func stopLoading() {
        delayedWorkItem?.cancel()
        delayedWorkItem = nil
    }

    private func deliverResponse() {
        let response = Self.response(for: request)
        client?.urlProtocol(self, didReceive: response.http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func delaysResponse(for request: URLRequest) -> Bool {
        lock.withLock {
            scenario == .slowSubmit
                && request.url?.path == "/api/v1/convert"
                && request.httpMethod == "POST"
        }
    }

    private static func response(for request: URLRequest) -> (http: HTTPURLResponse, data: Data) {
        let url = request.url ?? URL(string: "https://www.datalab.to/invalid")!
        if url.host == "attacker.invalid" {
            lock.withLock { current.untrustedRequestCount += 1 }
            return (httpResponse(url: url, statusCode: 418), jsonData(["error": "Blocked fixture."]))
        }
        if url.path == "/api/v1/user_health" {
            return healthResponse(for: request, url: url)
        }
        if url.path == "/api/v1/convert", request.httpMethod == "POST" {
            return submitResponse(for: request, url: url)
        }
        if url.path == "/api/v1/convert/ticket02", request.httpMethod == "GET" {
            return pollResponse(for: request, url: url)
        }
        return (httpResponse(url: url, statusCode: 404), jsonData(["error": "Unexpected request."]))
    }

    private static func healthResponse(
        for request: URLRequest,
        url: URL
    ) -> (http: HTTPURLResponse, data: Data) {
        let selectedScenario = lock.withLock { () -> Scenario in
            current.healthCount += 1
            current.usedGET = request.httpMethod == "GET"
            current.authenticationPresent = request.value(forHTTPHeaderField: "X-API-Key") != nil
            current.requestBodyAbsent = request.httpBody == nil && request.httpBodyStream == nil
            return scenario
        }
        switch selectedScenario {
        case .healthOK:
            return (httpResponse(url: url), jsonData(["status": "ok"]))
        case .invalidCredentials:
            return (httpResponse(url: url, statusCode: 401), jsonData(["error": "Invalid API key."]))
        case .conversionSuccess, .transientPollThenSuccess, .persistentTransientPoll,
             .recognitionInvalidCredentials,
             .untrustedCheckURL, .unapprovedDatalabSubdomainCheckURL,
             .nonStatusCheckURL, .pollHTTPRejection, .malformedPollJSON,
             .completionMissingHTML,
             .unknownPollStatus, .serviceFailure, .processingForever, .untrustedRedirect:
             return (httpResponse(url: url, statusCode: 404), jsonData(["error": "Unexpected request."]))
        case .slowSubmit:
            return (httpResponse(url: url, statusCode: 404), jsonData(["error": "Unexpected request."]))
        }
    }

    private static func submitResponse(
        for request: URLRequest,
        url: URL
    ) -> (http: HTTPURLResponse, data: Data) {
        let selectedScenario = lock.withLock { () -> Scenario in
            current.submitCount += 1
            return scenario
        }
        guard [
            .conversionSuccess,
            .recognitionInvalidCredentials,
            .transientPollThenSuccess,
            .persistentTransientPoll,
            .untrustedCheckURL,
            .unapprovedDatalabSubdomainCheckURL,
            .nonStatusCheckURL,
            .pollHTTPRejection,
            .malformedPollJSON,
            .completionMissingHTML,
            .unknownPollStatus,
            .serviceFailure,
            .processingForever,
            .slowSubmit,
            .untrustedRedirect
        ].contains(selectedScenario),
              let contentType = request.value(forHTTPHeaderField: "Content-Type"),
              let boundary = multipartBoundary(from: contentType),
              let body = requestBody(request),
              let parts = multipartParts(in: body, boundary: boundary) else {
            return (httpResponse(url: url, statusCode: 422), jsonData(["error": "Rejected request contract."]))
        }

        let expectedFields = [
            "mode": "fast",
            "output_format": "markdown,html",
            "disable_image_extraction": "true",
            "disable_image_captions": "true",
            "save_checkpoint": "false"
        ]
        let scalarParts = parts.filter { $0.filename == nil }
        let fileParts = parts.filter { $0.filename != nil }
        var scalarValues: [String: String] = [:]
        for part in scalarParts {
            guard scalarValues[part.name] == nil,
                  let value = String(data: part.data, encoding: .utf8) else { continue }
            scalarValues[part.name] = value
        }
        let file = fileParts.first
        lock.withLock {
            current.pngMatched = fileParts.count == 1
                && file?.name == "file"
                && file?.filename == "snippet.png"
                && file?.contentType?.lowercased() == "image/png"
                && file?.data == expectedPNG
            current.approvedFieldsOnly = parts.count == expectedFields.count + 1
                && scalarValues == expectedFields
            current.fastMode = scalarValues["mode"] == "fast"
            current.balancedMode = scalarValues["mode"] == "balanced"
        }
        if selectedScenario == .recognitionInvalidCredentials {
            return (
                httpResponse(url: url, statusCode: 401),
                jsonData(["error": "Invalid API key."])
            )
        }
        let checkURL: String
        switch selectedScenario {
        case .untrustedCheckURL:
            checkURL = "https://datalab.to.attacker.invalid/api/v1/convert/ticket02"
        case .unapprovedDatalabSubdomainCheckURL:
            checkURL = "https://unapproved.datalab.to/api/v1/convert/ticket02"
        case .nonStatusCheckURL:
            checkURL = "https://www.datalab.to/api/v1/user_health"
        default:
            checkURL = "https://www.datalab.to/api/v1/convert/ticket02"
        }
        return (
            httpResponse(url: url),
            jsonData([
                "success": true,
                "request_check_url": checkURL
            ])
        )
    }

    private static func pollResponse(
        for request: URLRequest,
        url: URL
    ) -> (http: HTTPURLResponse, data: Data) {
        let count = lock.withLock { () -> Int in
            current.pollCount += 1
            current.pollingAuthenticationPresent = request.value(forHTTPHeaderField: "X-API-Key") != nil
            return current.pollCount
        }
        let selectedScenario = lock.withLock { scenario }
        switch selectedScenario {
        case .untrustedRedirect:
            return (
                HTTPURLResponse(
                    url: url,
                    statusCode: 302,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "application/json",
                        "Location": "https://attacker.invalid/ticket02"
                    ]
                )!,
                Data()
            )
        case .pollHTTPRejection:
            return (httpResponse(url: url, statusCode: 422), jsonData(["error": "Request rejected."]))
        case .malformedPollJSON:
            return (httpResponse(url: url), Data("not-json".utf8))
        case .completionMissingHTML:
            return (
                httpResponse(url: url),
                jsonData([
                    "status": "complete",
                    "success": true,
                    "markdown": "ticket02 result"
                ])
            )
        case .unknownPollStatus:
            return (httpResponse(url: url), jsonData(["status": "unknown", "success": true]))
        case .serviceFailure:
            return (
                httpResponse(url: url),
                jsonData(["status": "failed", "success": false, "error": "Recognition failed."])
            )
        case .processingForever:
            return (httpResponse(url: url), jsonData(["status": "processing", "success": true]))
        default:
            break
        }
        if selectedScenario == .persistentTransientPoll
            || (selectedScenario == .transientPollThenSuccess && count == 1) {
            return (
                httpResponse(url: url, statusCode: 503),
                jsonData(["error": "Temporarily unavailable."])
            )
        }
        if count == 1 {
            return (httpResponse(url: url), jsonData(["status": "processing", "success": true]))
        }
        return (
            httpResponse(url: url),
            jsonData([
                "status": "complete",
                "success": true,
                "markdown": "ticket02 result",
                "html": "<p>ticket02</p>",
                "runtime": 1.25,
                "cost_breakdown": ["final_cost": 0.42],
                "parse_quality_score": 4.5
            ])
        )
    }

    private static func requestBody(_ request: URLRequest) -> Data? {
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

    private static func multipartBoundary(from contentType: String) -> String? {
        let components = contentType.split(separator: ";", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard components.count == 2,
              components[0].lowercased() == "multipart/form-data",
              components[1].hasPrefix("boundary=") else { return nil }
        return String(components[1].dropFirst("boundary=".count))
    }

    private static func multipartParts(in body: Data, boundary: String) -> [MultipartPart]? {
        let delimiter = Data("--\(boundary)\r\n".utf8)
        let closing = Data("--\(boundary)--\r\n".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        let nextBoundary = Data("\r\n--\(boundary)".utf8)
        guard body.starts(with: delimiter) else { return nil }
        var parts: [MultipartPart] = []
        var boundaryStart = body.startIndex

        while true {
            let partStart = body.index(boundaryStart, offsetBy: delimiter.count)
            guard let headerRange = body.range(of: headerSeparator, in: partStart..<body.endIndex),
                  let nextRange = body.range(of: nextBoundary, in: headerRange.upperBound..<body.endIndex),
                  let part = multipartPart(
                      headers: body.subdata(in: partStart..<headerRange.lowerBound),
                      data: body.subdata(in: headerRange.upperBound..<nextRange.lowerBound)
                  ) else { return nil }
            parts.append(part)
            let nextStart = body.index(nextRange.lowerBound, offsetBy: 2)
            if body[nextStart...].starts(with: closing) { return parts }
            guard body[nextStart...].starts(with: delimiter) else { return nil }
            boundaryStart = nextStart
        }
    }

    private static func multipartPart(headers: Data, data: Data) -> MultipartPart? {
        guard let headerText = String(data: headers, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        let prefix = "Content-Disposition: form-data; name=\""
        guard let first = lines.first, first.hasPrefix(prefix),
              let nameEnd = first.dropFirst(prefix.count).firstIndex(of: "\"") else { return nil }
        let nameStart = first.index(first.startIndex, offsetBy: prefix.count)
        let name = String(first[nameStart..<nameEnd])
        let filenamePrefix = "; filename=\""
        let filename: String?
        if let range = first.range(of: filenamePrefix),
           let end = first[range.upperBound...].firstIndex(of: "\"") {
            filename = String(first[range.upperBound..<end])
        } else {
            filename = nil
        }
        let contentType = lines.dropFirst().first.flatMap { line -> String? in
            let prefix = "Content-Type: "
            return line.hasPrefix(prefix) ? String(line.dropFirst(prefix.count)) : nil
        }
        return MultipartPart(name: name, filename: filename, contentType: contentType, data: data)
    }

    private static func httpResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    private static func jsonData(_ value: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])) ?? Data()
    }
}
