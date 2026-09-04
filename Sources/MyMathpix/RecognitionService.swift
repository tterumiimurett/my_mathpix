import Foundation

@MainActor
protocol RecognitionService: AnyObject {
    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult
}

@MainActor
protocol RecognitionConfiguration: AnyObject {
    var isConfigured: Bool { get }
    func saveToken(_ token: String) throws
    func testAndSaveToken(_ token: String) async throws
    func clearToken() throws
}

@MainActor
final class LiveRecognitionService: RecognitionService, RecognitionConfiguration {
    private let tokenStore: LocalTokenStore
    private let client: DatalabClient

    init(tokenStore: LocalTokenStore = LocalTokenStore(), client: DatalabClient = DatalabClient()) {
        self.tokenStore = tokenStore
        self.client = client
    }

    var isConfigured: Bool {
        tokenStore.readToken() != nil
    }

    func saveToken(_ token: String) throws {
        try tokenStore.saveToken(token)
    }

    func testAndSaveToken(_ token: String) async throws {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.validateToken(normalized)
        try tokenStore.saveToken(normalized)
    }

    func clearToken() throws {
        try tokenStore.clearToken()
    }

    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        guard let token = tokenStore.readToken() else { throw AppError.missingToken }
        return try await client.recognize(pngData: uploadPayload.pngData, token: token, mode: mode)
    }
}

@MainActor
final class Ticket01RecognitionService: RecognitionService {
    private let client: DatalabClient

    init() {
        client = DatalabClient(session: Ticket01MockURLProtocol.makeSession())
    }

    func recognize(uploadPayload: UploadPayload, mode: RecognitionMode) async throws -> DatalabResult {
        try await client.recognize(
            pngData: uploadPayload.pngData,
            token: Ticket01MockContract.sentinelToken,
            mode: mode
        )
    }
}
