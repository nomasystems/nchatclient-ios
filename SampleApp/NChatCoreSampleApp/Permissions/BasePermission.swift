import Foundation

internal class BasePermission: NSObject {

    var shouldRequest: Bool {
        fatalError("Please, don't call this method because it's abstract. It must be implemented inside the child classes")
    }

    var currentResult: PermissionResult {
        fatalError("Please, don't call this method because it's abstract. It must be implemented inside the child classes")
    }

    func internalRequest(completion: @escaping (PermissionResult) -> Void) {
        fatalError("Please, don't call this method because it's abstract. It must be implemented inside the child classes")
    }
}

extension BasePermission: PermissionProtocol {

    func request(completion: @escaping (PermissionResult) -> Void) {
        guard shouldRequest else {
            completion(currentResult)
            return
        }
        internalRequest(completion: completion)
    }
}
