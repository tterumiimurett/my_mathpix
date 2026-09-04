import Foundation

private enum DatalabURLTrust {
    private static let approvedHosts = ["datalab.to", "www.datalab.to"]

    static func isApprovedAPIURL(_ url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              approvedHosts.contains(host),
              url.user == nil,
              url.password == nil,
              url.port == nil || url.port == 443 else { return false }
        return true
    }

    static func isApprovedStatusURL(_ url: URL?) -> Bool {
        guard isApprovedAPIURL(url), let url else { return false }
        let path = url.path.split(separator: "/", omittingEmptySubsequences: true)
        return path.count == 4
            && path[0] == "api"
            && path[1] == "v1"
            && path[2] == "convert"
            && !path[3].isEmpty
    }

    static func isApprovedRedirect(from originalURL: URL?, to redirectedURL: URL?) -> Bool {
        guard isApprovedAPIURL(redirectedURL),
              let originalURL,
              let redirectedURL else { return false }
        if isApprovedStatusURL(originalURL) {
            return isApprovedStatusURL(redirectedURL)
        }
        return redirectedURL.path == originalURL.path
    }
}

private final class DatalabRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(
            DatalabURLTrust.isApprovedRedirect(
                from: task.originalRequest?.url,
                to: request.url
            ) ? request : nil
        )
    }
}

actor DatalabClient {
    struct Policy: Sendable {
        let timeout: Duration
        let initialPollDelay: Duration
        let maximumPollDelay: Duration
        let transientRetryDelay: Duration

        init(
            timeout: Duration = .seconds(60),
            initialPollDelay: Duration = .milliseconds(400),
            maximumPollDelay: Duration = .seconds(1),
            transientRetryDelay: Duration = .milliseconds(500)
        ) {
            self.timeout = timeout
            self.initialPollDelay = initialPollDelay
            self.maximumPollDelay = maximumPollDelay
            self.transientRetryDelay = transientRetryDelay
        }
    }

    private final class RetryBudget {
        private(set) var used = 0

        func consume() -> Bool {
            guard used == 0 else { return false }
            used = 1
            return true
        }
    }

    private let session: URLSession
    private let policy: Policy
    private let redirectDelegate: DatalabRedirectDelegate
    private let submitURL = URL(string: "https://www.datalab.to/api/v1/convert")!

    init(session: URLSession = .shared, policy: Policy = Policy()) {
        let redirectDelegate = DatalabRedirectDelegate()
        self.redirectDelegate = redirectDelegate
        self.session = URLSession(
            configuration: session.configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
        self.policy = policy
    }

    func validateToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: "https://www.datalab.to/api/v1/user_health")!)
        request.timeoutInterval = 15
        request.setValue(token, forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await responseData(
            for: request,
            retryBudget: RetryBudget(),
            permitsAutomaticRetry: true
        )
        try validateHTTP(response, data: data)
        let json = try jsonObject(data)
        guard (json["status"] as? String)?.lowercased() == "ok" else {
            throw AppError.service("Datalab did not confirm that this token is healthy.")
        }
    }

    func recognize(pngData: Data, token: String, mode: RecognitionMode) async throws -> DatalabResult {
        let clock = ContinuousClock()
        let timeout = policy.timeout
        let deadline = clock.now.advanced(by: timeout)
        return try await withThrowingTaskGroup(of: DatalabResult.self) { group in
            group.addTask { [self] in
                try await performRecognition(
                    pngData: pngData,
                    token: token,
                    mode: mode,
                    deadline: deadline
                )
            }
            group.addTask {
                try await ContinuousClock().sleep(for: timeout)
                throw AppError.requestTimedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw AppError.invalidResponse("recognition produced no result")
            }
            return result
        }
    }

    private func performRecognition(
        pngData: Data,
        token: String,
        mode: RecognitionMode,
        deadline: ContinuousClock.Instant
    ) async throws -> DatalabResult {
        try Task.checkCancellation()
        let retryBudget = RetryBudget()
        let checkURL = try await submit(
            pngData: pngData,
            token: token,
            mode: mode,
            retryBudget: retryBudget
        )
        try Task.checkCancellation()
        guard ContinuousClock().now < deadline else {
            throw AppError.requestTimedOut
        }
        return try await poll(
            checkURL: checkURL,
            token: token,
            retryBudget: retryBudget,
            deadline: deadline
        )
    }

    private func submit(
        pngData: Data,
        token: String,
        mode: RecognitionMode,
        retryBudget: RetryBudget
    ) async throws -> URL {
        let boundary = "MyMathpix-\(UUID().uuidString)"
        var request = URLRequest(url: submitURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(token, forHTTPHeaderField: "X-API-Key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fields: [
                "mode": mode.rawValue,
                "output_format": "markdown,html",
                "disable_image_extraction": "true",
                "disable_image_captions": "true",
                "save_checkpoint": "false"
            ],
            fileData: pngData
        )

        let (data, response) = try await responseData(
            for: request,
            retryBudget: retryBudget,
            permitsAutomaticRetry: false
        )
        try validateHTTP(response, data: data)
        let json = try jsonObject(data)
        if json["success"] as? Bool == false {
            throw AppError.service(json["error"] as? String ?? "Datalab rejected the recognition request.")
        }
        guard let rawURL = json["request_check_url"] as? String,
              let url = URL(string: rawURL),
              DatalabURLTrust.isApprovedStatusURL(url) else {
            throw AppError.invalidResponse("missing or untrusted request_check_url")
        }
        return url
    }

    private func poll(
        checkURL: URL,
        token: String,
        retryBudget: RetryBudget,
        deadline: ContinuousClock.Instant
    ) async throws -> DatalabResult {
        let clock = ContinuousClock()
        var delay = policy.initialPollDelay

        while true {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                throw AppError.requestTimedOut
            }
            var request = URLRequest(url: checkURL)
            request.timeoutInterval = 15
            request.setValue(token, forHTTPHeaderField: "X-API-Key")
            let (data, response) = try await responseData(
                for: request,
                retryBudget: retryBudget,
                permitsAutomaticRetry: true
            )
            try validateHTTP(response, data: data)
            let json = try jsonObject(data)
            guard let rawStatus = json["status"] as? String else {
                throw AppError.invalidResponse("poll response had no status")
            }
            let status = rawStatus.lowercased()

            if status == "complete" {
                if json["success"] as? Bool == false {
                    throw AppError.service(json["error"] as? String ?? "Datalab could not recognize this snippet.")
                }
                guard json["success"] as? Bool == true,
                      let markdown = json["markdown"] as? String,
                      let html = json["html"] as? String else {
                    throw AppError.invalidResponse("completed response lacked requested Markdown or HTML")
                }
                return DatalabResult(
                    markdown: markdown,
                    html: html,
                    runtime: number(json["runtime"]),
                    costSummary: costSummary(json["cost_breakdown"]),
                    costValue: costValue(json["cost_breakdown"]),
                    parseQualityScore: number(json["parse_quality_score"]),
                    automaticRetryCount: retryBudget.used
                )
            }
            if ["failed", "error", "cancelled", "canceled"].contains(status) || json["success"] as? Bool == false {
                throw AppError.service(json["error"] as? String ?? "Datalab recognition failed.")
            }
            guard status == "processing" else {
                throw AppError.invalidResponse("unrecognized poll status")
            }

            try await clock.sleep(for: delay)
            delay = min(delay + .milliseconds(200), policy.maximumPollDelay)
        }
    }

    private func responseData(
        for request: URLRequest,
        retryBudget: RetryBudget,
        permitsAutomaticRetry: Bool
    ) async throws -> (Data, URLResponse) {
        while true {
            do {
                let response = try await session.data(for: request)
                try Task.checkCancellation()
                guard DatalabURLTrust.isApprovedAPIURL(response.1.url) else {
                    throw AppError.invalidResponse("request left the approved Datalab host")
                }
                if let http = response.1 as? HTTPURLResponse,
                   isTransientStatus(http.statusCode),
                   permitsAutomaticRetry,
                   retryBudget.consume() {
                    try await ContinuousClock().sleep(for: policy.transientRetryDelay)
                    continue
                }
                return response
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError {
                if error.code == .cancelled || Task.isCancelled {
                    throw CancellationError()
                }
                if isTransient(error),
                   permitsAutomaticRetry,
                   retryBudget.consume() {
                    try await ContinuousClock().sleep(for: policy.transientRetryDelay)
                    continue
                }
                throw AppError.networkUnavailable
            }
        }
    }

    private func isTransientStatus(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 425 || statusCode == 429 || 500...599 ~= statusCode
    }

    private func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
             .networkConnectionLost, .notConnectedToInternet, .internationalRoamingOff,
             .callIsActive, .dataNotAllowed, .resourceUnavailable:
            true
        default:
            false
        }
    }

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        fileData: Data
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            body.appendUTF8("--\(boundary)\(crlf)")
            body.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
            body.appendUTF8("\(value)\(crlf)")
        }
        body.appendUTF8("--\(boundary)\(crlf)")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"snippet.png\"\(crlf)")
        body.appendUTF8("Content-Type: image/png\(crlf)\(crlf)")
        body.append(fileData)
        body.appendUTF8("\(crlf)--\(boundary)--\(crlf)")
        return body
    }

    private func validateHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AppError.invalidResponse("non-HTTP response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw AppError.invalidCredentials
        }
        guard 200..<300 ~= http.statusCode else {
            let json = try? jsonObject(data)
            let message = json?["error"] as? String
                ?? json?["detail"] as? String
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AppError.service("Datalab request failed (HTTP \(http.statusCode)): \(message)")
        }
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            throw AppError.invalidResponse("expected a JSON object")
        }
        return object
    }

    private func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func costSummary(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let number = value as? NSNumber {
            return String(format: "%.4f", number.doubleValue)
        }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return text
    }

    private func costValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        guard let dictionary = value as? [String: Any] else { return nil }
        for key in ["final_cost", "total_cost", "cost", "client_cost"] {
            if let value = number(dictionary[key]) { return value }
        }
        return nil
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(contentsOf: string.utf8)
    }
}
