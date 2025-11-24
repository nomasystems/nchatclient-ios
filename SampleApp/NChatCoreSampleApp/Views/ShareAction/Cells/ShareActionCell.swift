//  Copyright © 2017 Nomasystems S.L. All rights reserved.

import UIKit


enum ResourceImages {
    static let icoProduct = UIImage(named: "icoShareproductActionSheet", in: Bundle.main, compatibleWith: nil)
    static let icoCamera = UIImage(named: "icoCameraActionSheet", in: Bundle.main, compatibleWith: nil)
    static let icoPhotos = UIImage(named: "iCoPhotosActionSheet", in: Bundle.main, compatibleWith: nil)
}

class ShareActionCell: UITableViewCell {

    static let cellReuseIdentifier = "shareActionCell"

    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var actionLabel: UILabel!

    enum ShareKind: Int {
        case product
        case camera
        case gallery
    }

    class func nib() -> UINib {
        return UINib (nibName: "ShareActionCell", bundle: Bundle(for: self))
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func setup(kind: ShareKind) {
        switch kind {
        case .product:
            iconImageView.image = ResourceImages.icoProduct
            actionLabel.text = SampleChat.localization.shareProduct

        case .camera:
            iconImageView.image = ResourceImages.icoCamera
            actionLabel.text = SampleChat.localization.shareCamera

        case .gallery:
            iconImageView.image = ResourceImages.icoPhotos
            actionLabel.text = SampleChat.localization.shareMedia
        }
    }
}
