import Foundation
import UIKit

protocol ChatURLHandlerProtocol {
    func handle(_ url: URL)
}

public final class ChatURLHandler: NSObject, ChatURLHandlerProtocol {

    public func handle(_ url: URL) {
        if let scheme = url.scheme, scheme.contains("mailto") || scheme.contains("tel") {
            UIApplication.shared.open(url)
        } else {
            let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            userActivity.webpageURL = url
            _ = UIApplication.shared.delegate?.application?(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
        }
    }
}
