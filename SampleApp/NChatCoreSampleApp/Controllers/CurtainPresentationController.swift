import UIKit

class CurtainPresentationController: UIPresentationController {

    static let curtainTag = 333

    var curtainView: UIView
    var tapCurtainRecognizer: UITapGestureRecognizer?

    init(presentedViewController: UIViewController, presenting: UIViewController?, tapCurtainRecognizer: UITapGestureRecognizer?) {
        self.curtainView = UIView(frame: CGRect.zero)
        self.curtainView.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        self.curtainView.alpha = 0.0
        self.curtainView.tag = CurtainPresentationController.curtainTag
        self.tapCurtainRecognizer = tapCurtainRecognizer
        super.init(presentedViewController: presentedViewController, presenting: presenting)
    }

    override func presentationTransitionWillBegin() {
        curtainView.frame = containerView!.bounds
        curtainView.alpha = 0.0
        containerView!.insertSubview(curtainView, at: 0)
        presentedViewController.transitionCoordinator?.animate(
            alongsideTransition: { context in
                self.curtainView.alpha = 1.0
        },
            completion: nil
        )
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        if let recognizer = tapCurtainRecognizer {
            curtainView.addGestureRecognizer(recognizer)
        }
    }
}
