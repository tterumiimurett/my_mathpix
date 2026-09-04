import Foundation

actor DatalabClient {
    private let session: URLSession
    private let submitURL = URL(string: "https://www.datalab.to/api/v1/convert")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func validateToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: "https://www.datalab.to/api/v1/user_health")!)
        request.timeoutInterval = 15
        request.setValue(token, forHTTPHeaderField: "X-API-Key")
        let (data, response) = try await session.data(for: request)
        try validateHTTP(response, data: data)
        let json = try jsonObject(data)
        guard (json["status"] as? String)?.lowercased() == "ok" else {
            throw AppError.service("Datalab did not confirm that this token is healthy.")
        }
    }

    func recognize(pngData: Data, token: String, mode: RecognitionMode) async throws -> DatalabResult {
        let checkURL = try await submit(pngData: pngData, token: token, mode: mode)
        return try await poll(checkURL: checkURL, token: token)
    }

    private func submit(pngData: Data, token: String, mode: RecognitionMode) async throws -> URL {
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

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response, data: data)
        let json = try jsonObject(data)
        if json["success"] as? Bool == false {
            throw AppError.service(json["error"] as? String ?? "Datalab rejected the recognition request.")
        }
        guard let rawURL = json["request_check_url"] as? String,
              let url = URL(string: rawURL),
              url.scheme == "https",
              isTrustedDatalabHost(url.host) else {
            throw AppError.invalidResponse("missing or untrusted request_check_url")
        }
        return url
    }

    private func poll(checkURL: URL, token: String) async throws -> DatalabResult {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(60))
        var delay = Duration.milliseconds(400)

        while clock.now < deadline {
            try Task.checkCancellation()
            var request = URLRequest(url: checkURL)
            request.timeoutInterval = 15
            request.setValue(token, forHTTPHeaderField: "X-API-Key")
            let (data, response) = try await session.data(for: request)
            try validateHTTP(response, data: data)
            let json = try jsonObject(data)
            let status = (json["status"] as? String)?.lowercased() ?? ""

            if status == "complete" {
                if json["success"] as? Bool == false {
                    throw AppError.service(json["error"] as? String ?? "Datalab could not recognize this snippet.")
                }
                guard let markdown = json["markdown"] as? String else {
                    throw AppError.invalidResponse("completed response had no Markdown")
                }
                return DatalabResult(
                    markdown: markdown,
                    html: json["html"] as? String,
                    runtime: number(json["runtime"]),
                    costSummary: costSummary(json["cost_breakdown"]),
                    costValue: costValue(json["cost_breakdown"]),
                    parseQualityScore: number(json["parse_quality_score"])
                )
            }
            if ["failed", "error", "cancelled", "canceled"].contains(status) || json["success"] as? Bool == false {
                throw AppError.service(json["error"] as? String ?? "Datalab recognition failed.")
            }

            try await clock.sleep(for: delay)
            delay = min(delay + .milliseconds(200), .seconds(1))
        }
        throw AppError.requestTimedOut
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
        guard 200..<300 ~= http.statusCode else {
            let json = try? jsonObject(data)
            let message = json?["error"] as? String
                ?? json?["detail"] as? String
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AppError.service("Datalab request failed (HTTP \(http.statusCode)): \(message)")
        }
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.invalidResponse("expected a JSON object")
        }
        return object
    }

    private func isTrustedDatalabHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "datalab.to" || host == "www.datalab.to" || host.hasSuffix(".datalab.to")
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
