//  Copyright © 2017 Nomasystems S.L. All rights reserved.

import UIKit

class ShareActionSheetController: UIViewController, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {

    @IBOutlet private weak var actionsView: UIView!
    @IBOutlet private weak var cancelView: UIView!
    @IBOutlet private weak var actionsTableView: UITableView!
    @IBOutlet private weak var cancelLabel: UILabel!
    @IBOutlet private var tableViewHeightConstraint: NSLayoutConstraint!

    private let transitionDuration = 0.5
    private let baseContentHeight: CGFloat = 73
    private let rowHeight: CGFloat = 57
    private let cornerRadius: CGFloat = 12
    private var shareActionRows: [ShareActionCell.ShareKind] = []

    private var presenting = false
    fileprivate var productHandler: (() -> Void)? {
        didSet {
            handleShareKindRow(shouldAppear: productHandler != nil, kind: .product)
        }
    }
    fileprivate var cameraHandler: (() -> Void)? {
        didSet {
            handleShareKindRow(shouldAppear: cameraHandler != nil, kind: .camera)
        }
    }
    fileprivate var galleryHandler: (() -> Void)? {
        didSet {
            handleShareKindRow(shouldAppear: galleryHandler != nil, kind: .gallery)
        }
    }

    // MARK: - View and class methods

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        view.clipsToBounds = true
        view.backgroundColor = .clear
        actionsView.layer.cornerRadius = cornerRadius
        cancelView.layer.cornerRadius = cornerRadius
        cancelLabel.text = SampleChat.localization.cancel

        actionsTableView.estimatedRowHeight = rowHeight
        actionsTableView.rowHeight = UITableView.automaticDimension
        actionsTableView.separatorStyle = .none
        actionsTableView.isScrollEnabled = false
        actionsTableView.dataSource = self
        actionsTableView.delegate = self
        actionsTableView.register(ShareActionCell.nib(), forCellReuseIdentifier: ShareActionCell.cellReuseIdentifier)

        modalPresentationStyle = .custom
        transitioningDelegate = self

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func appMovedToBackground() {
        dismiss(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()

        shareActionRows.sort(by: { $0.rawValue < $1.rawValue })
        tableViewHeightConstraint.constant = CGFloat(shareActionRows.count) * rowHeight
        updatePreferredContentSize()
    }

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSize()
    }

    /**
     * Not setting the product handler will not display the product action
     */
    func setProductHandler(handler: (() -> Void)? = nil) {
        self.productHandler = handler
    }

    /**
     * Not setting the camera handler will not display the camera action
     */
    func setCameraHandler(handler: (() -> Void)? = nil) {
        self.cameraHandler = handler
    }

    /**
     * Not setting the gallery handler will not display the gallery action
     */
    func setGalleryHandler(handler: (() -> Void)? = nil) {
        self.galleryHandler = handler
    }

    @objc func handleTap(sender: UITapGestureRecognizer? = nil) {
        self.dismiss(animated: true)
    }

    // MARK:- IBActions

    @IBAction func cancelTouchUpInside(_ sender: Any) {
        self.dismiss(animated: true)
    }

    // MARK:- Animation-related

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return transitionDuration
    }

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.presenting = true
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.presenting = false
        return self
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if (self.presenting) {
            animatePresentationTransition(with: transitionContext, duration: transitionDuration, vcPosition: .bottomScreen)
        } else {
            animateDismissalTransition(with: transitionContext, duration: transitionDuration)
        }
    }

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(ShareActionSheetController.handleTap))
        return CurtainPresentationController(presentedViewController: presented, presenting: presenting, tapCurtainRecognizer: recognizer)
    }

    private func updatePreferredContentSize() {
        var safeAreaBottomInset: CGFloat = 0
        if #available(iOS 11.0, *) {
            safeAreaBottomInset = view.safeAreaInsets.bottom
        }
        let contentHeight = baseContentHeight + CGFloat(shareActionRows.count) * rowHeight
        preferredContentSize = CGSize(width: UIScreen.main.bounds.size.width, height: (contentHeight) + safeAreaBottomInset)
    }

    private func handleShareKindRow(shouldAppear: Bool, kind: ShareActionCell.ShareKind) {
        if shouldAppear, !shareActionRows.contains(kind) {
            shareActionRows.append(kind)
        } else if !shouldAppear {
            shareActionRows = shareActionRows.filter({ $0 != kind })
        }
    }
}

// MARK: - UITableViewDataSource and UITableViewDelegate

extension ShareActionSheetController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shareActionRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ShareActionCell = tableView.dequeueReusableCell(withIdentifier: ShareActionCell.cellReuseIdentifier) as! ShareActionCell
        if indexPath.row < shareActionRows.count {
            let kind = shareActionRows[indexPath.row]
            cell.setup(kind: kind)
            cell.isUserInteractionEnabled = existsHandlerFor(kind: kind)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.row < shareActionRows.count {
            let kind = shareActionRows[indexPath.row]
            switch kind {
            case .product:
                if let handler = productHandler {
                    self.dismiss(animated: true, completion: handler)
                }
            case .camera:
                if let handler = cameraHandler {
                    self.dismiss(animated: true, completion: handler)
                }
            case .gallery:
                if let handler = galleryHandler {
                    self.dismiss(animated: true, completion: handler)
                }
            }
        }
    }

    private func existsHandlerFor(kind: ShareActionCell.ShareKind) -> Bool {
        switch kind {
        case .product:
            return productHandler != nil
        case .camera:
            return cameraHandler != nil
        case .gallery:
            return galleryHandler != nil
        }
    }
}


