import Foundation

internal struct PermissionResult: RawRepresentable, Equatable, Hashable, Comparable {
    var rawValue: String

    static let unspecified = PermissionResult(rawValue: "unspecified")
    static let approved = PermissionResult(rawValue: "approved")
    static let notApproved = PermissionResult(rawValue: "notApproved")

    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }

    static func < (lhs: PermissionResult, rhs: PermissionResult) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    static func == (lhs: PermissionResult, rhs: PermissionResult) -> Bool {
        return lhs.rawValue.elementsEqual(rhs.rawValue)
    }

}

internal protocol PermissionProtocol {
    var shouldRequest: Bool { get }
    func request(completion: @escaping (PermissionResult) -> Void)
}

internal enum Permission {}

extension Permission {
    static var camera: PermissionProtocol { CameraPermission() }
    static var photoLibrary: PermissionProtocol { PhotoLibraryPermission() }
}
