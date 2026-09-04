import Foundation

enum RecognitionMode: String, Codable, CaseIterable, Identifiable {
    case fast
    case balanced

    var id: String { rawValue }
    var title: String { self == .fast ? "Fast" : "High Quality" }
}

enum RecognitionStatus: String, Codable {
    case processing
    case complete
    case failed
}

struct HistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    let imageFilename: String
    var markdown: String
    var html: String?
    var status: RecognitionStatus
    var mode: RecognitionMode
    var runtime: Double?
    var costSummary: String?
    var errorMessage: String?

    init(id: UUID = UUID(), imageFilename: String) {
        self.id = id
        self.createdAt = Date()
        self.updatedAt = Date()
        self.imageFilename = imageFilename
        self.markdown = ""
        self.status = .processing
        self.mode = .fast
    }
}

struct DatalabResult: Equatable {
    let markdown: String
    let html: String?
    let runtime: Double?
    let costSummary: String?
    let costValue: Double?
    let parseQualityScore: Double?
    let automaticRetryCount: Int
}

struct UploadPayload: Equatable {
    let pngData: Data
}

struct UsageSnapshot: Codable, Equatable {
    var requestCount = 0
    var successfulCount = 0
    var cumulativeCost: Double = 0
}

enum AppError: LocalizedError {
    case missingToken
    case invalidCredentials
    case networkUnavailable
    case capturePermissionDenied
    case captureInProgress
    case captureFailed
    case captureDisplayUnavailable
    case selectionTooSmall
    case invalidResponse(String)
    case service(String)
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Add your Datalab API token in Settings before capturing."
        case .invalidCredentials:
            return "Datalab rejected the saved token. Open Settings to test and replace it, or clear it."
        case .networkUnavailable:
            return "The connection to Datalab failed. Check the network and retry this saved snippet."
        case .capturePermissionDenied:
            return "Screen Recording permission is required. Open System Settings > Privacy & Security > Screen & System Audio Recording. If MyMathpix is already enabled, turn it off and back on, then quit and reopen MyMathpix."
        case .captureInProgress:
            return "Finish or cancel the current screen selection before starting another capture."
        case .captureFailed:
            return "The selected screen region could not be captured."
        case .captureDisplayUnavailable:
            return "The selected display is no longer available. Start a new screen capture."
        case .selectionTooSmall:
            return "The selected region was too small. Drag a larger rectangle and try again."
        case .invalidResponse(let detail):
            return "Datalab returned an invalid response: \(detail)"
        case .service(let detail):
            return detail
        case .requestTimedOut:
            return "Recognition did not finish within 60 seconds. The snippet was kept so you can retry."
        }
    }

    var safeDiagnosticCode: String {
        switch self {
        case .missingToken: "missing_token"
        case .invalidCredentials: "invalid_credentials"
        case .networkUnavailable: "network_failure"
        case .capturePermissionDenied: "permission_denied"
        case .captureInProgress: "capture_in_progress"
        case .captureFailed: "capture_api_failure"
        case .captureDisplayUnavailable: "display_unavailable"
        case .selectionTooSmall: "selection_too_small"
        case .invalidResponse: "invalid_response"
        case .service: "service_failure"
        case .requestTimedOut: "timeout"
        }
    }
}
