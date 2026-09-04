import Foundation

struct Ticket01FixedScreenCapturePermission: ScreenCapturePermissionProviding {
    let hasAccess: Bool
    let requestResult: Bool

    func requestAccess() -> Bool { requestResult }
}

struct Ticket01FailingImageCapturer: ScreenImageCapturing {
    enum Failure: Sendable {
        case captureAPI
        case displayUnavailable
    }

    let failure: Failure

    func capture(request: ScreenCaptureRequest) async throws -> UploadPayload {
        switch failure {
        case .captureAPI:
            throw AppError.captureFailed
        case .displayUnavailable:
            throw AppError.captureDisplayUnavailable
        }
    }
}
