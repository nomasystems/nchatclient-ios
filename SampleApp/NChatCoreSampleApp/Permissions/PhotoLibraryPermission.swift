import Photos

internal class PhotoLibraryPermission: BasePermission {

    override var shouldRequest: Bool {
        currentResult == .unspecified
    }

    override var currentResult: PermissionResult {
        if #available(iOS 14, *) {
            return PHPhotoLibrary.authorizationStatus(for: .readWrite).permission
        } else {
            return PHPhotoLibrary.authorizationStatus().permission
        }
    }

    override func internalRequest(completion: @escaping (PermissionResult) -> Void) {
        DispatchQueue.main.async {
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    completion(status.permission)
                }
            } else {
                PHPhotoLibrary.requestAuthorization { status in
                    completion(status.permission)
                }
            }
        }
    }
}

extension PermissionResult {
    static let limited = PermissionResult(rawValue: "limited")
}

private extension PHAuthorizationStatus {

    var permission: PermissionResult {
        switch self {
        case .notDetermined:
            return .unspecified
        case .restricted, .denied:
            return .notApproved
        case .authorized:
            return .approved
        case .limited:
            return .limited
        @unknown default:
            return .notApproved
        }
    }
}
