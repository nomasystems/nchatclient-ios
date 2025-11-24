import UIKit
import NChatCore

final class SampleChatAttachment: ChatAttachment {

    // Product-related attributes.
    let image: UIImage
    let color: String?
    let desc: String?
    var isProduct: Bool { title != nil || color != nil || desc != nil }

    init?(image: UIImage,
          title: String? = nil,
          color: String? = nil,
          desc: String? = nil,
          url: URL? = nil) {
        guard let data = image.pngData() else { return nil }
        self.image = image
        self.color = color
        self.desc = desc
        super.init(data: data, title: title, url: url, pathExtension: ".png")
    }
}
