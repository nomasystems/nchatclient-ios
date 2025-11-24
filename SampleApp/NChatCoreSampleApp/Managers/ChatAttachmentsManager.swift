import UIKit
import NChatCore

public class ChatAttachmentsManager {

    /**
     Attachments are set to display the popup once the chat is active. Reset on user action.
     */
    var attachments: [SampleChatAttachment] = []
    public static let shared = ChatAttachmentsManager()

    public func clearAttachments() {
        attachments.removeAll()
    }

    public func attach(image: UIImage, title: String? = nil, color: String? = nil, desc: String? = nil, url: URL? = nil) {
        guard let attachment = SampleChatAttachment(image: image.attachmentScaled(),
                                                     title: title,
                                                     color: color,
                                                     desc: desc,
                                                     url: url) else { return }
        attachments.append(attachment)
    }

    // MARK: Helper method for attachment building when retrieving history messages
    // For legacy reasons, attachments (like images) can be sent in the body part of the message
    // This method helps parse those attachments from base64 encoded data
    func getAttachment(_ attachmentBase64: String?, body: String) -> RawAttachment? {
        func attachmentInfo(from string: String) -> (title: String, url: URL, message: String?)? {
            // Product info from backend is sent in a single string, with no spaces, and with the following format:
            // <title><url><message>. Example:
            // Product Titlehttps://example.com/product.htmlDescription
            // If URL exists, title is always informed. But message is optional.
            guard let index = string.range(of: "http") else { return nil } // No URL -> just an image
            let title = String(string[..<index.lowerBound])
            var urlString = String(string[index.lowerBound...])
            var message: String?
            if !urlString.hasSuffix(".html"), let range = urlString.range(of: ".html") {
                // Extract message
                message = String(urlString[range.upperBound...])
                urlString = String(urlString[..<range.upperBound])
            }
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                return (title: title, url: url, message: message)
            } else {
                return nil
            }
        }

        guard var imageCoded = attachmentBase64, !imageCoded.isEmpty else { return nil }

        let imageHeader = "data:image/png;base64,"
        if imageCoded.starts(with: imageHeader) {
            imageCoded = String(imageCoded.dropFirst(imageHeader.count))
        }

        guard let data = Data(base64Encoded: imageCoded) else { return nil }

        // means that the message contains either a product or an image
        // images do not contain an URL, but products do.
        // That's our way to distinguish one another.
        if let (title, url, message) = attachmentInfo(from: body) {
            return (attachment: ChatAttachment(data: data, title: title, url: url), message: message)
        } else {
            return (attachment: ChatAttachment(data: data), body)
        }
    }

}
