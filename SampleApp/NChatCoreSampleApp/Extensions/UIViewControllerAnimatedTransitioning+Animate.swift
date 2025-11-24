import UIKit

enum AnimatedViewControllerPosition {
    case middleScreen
    case bottomScreen
}

extension UIViewControllerAnimatedTransitioning {

    func animatePresentationTransition(with transitionContext: UIViewControllerContextTransitioning, duration: Double, vcPosition: AnimatedViewControllerPosition) {

        guard let fromController = transitionContext.viewController(forKey: .from),
              let toController = transitionContext.viewController(forKey: .to) else {
            return
        }

        transitionContext.containerView.addSubview(toController.view)
        let preferredSize = toController.preferredContentSize

        let yOffset: CGFloat = vcPosition == .middleScreen ? 0.5 : 1

        let toFrameOrigin = CGPoint(
            x: (fromController.view.bounds.size.width - preferredSize.width) * 0.5,
            y: (fromController.view.bounds.size.height - preferredSize.height) * yOffset
        )

        let fromFrameOrigin = CGPoint(
            x: (fromController.view.bounds.size.width - preferredSize.width) * 0.5,
            y: fromController.view.bounds.size.height
        )

        let onscreenFrame = CGRect(origin: toFrameOrigin, size: preferredSize)
        let offscreenFrame = CGRect(origin: fromFrameOrigin, size: preferredSize)

        toController.view.frame = offscreenFrame

        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.8,
                       options: [],
                       animations: { toController.view.frame = onscreenFrame }) { _ in
            transitionContext.completeTransition(true)
        }
    }

    func animateDismissalTransition(with transitionContext: UIViewControllerContextTransitioning, duration: Double) {

        guard let fromController = transitionContext.viewController(forKey: .from),
              let toController = transitionContext.viewController(forKey: .to) else {
            return
        }

        let preferredSize = fromController.preferredContentSize

        let toFrameOrigin = CGPoint(
            x: (toController.view.bounds.size.width - preferredSize.width) * 0.5,
            y: toController.view.bounds.size.height
        )

        let toFrame = CGRect(origin: toFrameOrigin, size: preferredSize)

        let curtainView = transitionContext.containerView.viewWithTag(CurtainPresentationController.curtainTag)

        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.8,
                       options: [],
                       animations: {
            fromController.view.frame = toFrame
            curtainView?.alpha = 0.0
        }) { _ in
            transitionContext.completeTransition(true)
        }
    }
}
