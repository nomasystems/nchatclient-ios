import UIKit

// Image constants regarding chat attachments
enum ImageConstants {
    static let maxAttachmentImageSize = CGSize(width: 600, height: 600)
}

extension UIImage {

    func attachmentScaled() -> UIImage {
        if size.width > ImageConstants.maxAttachmentImageSize.width || size.height > ImageConstants.maxAttachmentImageSize.height {
            return sized(scaledToSize: ImageConstants.maxAttachmentImageSize)
        }
        return self
    }

    func sized(scaledToSize newSize: CGSize) -> UIImage {
        var height = newSize.height
        var width = newSize.width
        if size.width > size.height {
            let ratio = newSize.width / size.width
            height = size.height * ratio
        } else {
            let ratio = newSize.height / size.height
            width = size.width * ratio
        }

        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)

        draw(in: CGRect(origin: CGPoint.zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!

        UIGraphicsEndImageContext()
        return newImage
    }
}
