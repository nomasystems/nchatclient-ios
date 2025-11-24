import AVFoundation

internal class CameraPermission: BasePermission {

    override var shouldRequest: Bool {
        currentResult == .unspecified
    }

    override var currentResult: PermissionResult {
        AVCaptureDevice.authorizationStatus(for: .video).permission
    }

    override func internalRequest(completion: @escaping (PermissionResult) -> Void) {
        DispatchQueue.main.async {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted ? .approved : .notApproved)
            }
        }
    }
}

private extension AVAuthorizationStatus {

    var permission: PermissionResult {
        switch self {
        case .notDetermined:
            return .unspecified
        case .restricted, .denied:
            return .notApproved
        case .authorized:
            return .approved
        @unknown default:
            return .notApproved
        }
    }
}
