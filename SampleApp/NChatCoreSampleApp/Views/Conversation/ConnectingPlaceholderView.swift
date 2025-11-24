import Foundation
import UIKit

class ConnectingPlaceholderView: UIView {

    // MARK: Properties

    private lazy var threeDotsIconView: UILabel = {
        // Simple three dots as text since we don't have assets
        let label = UILabel.initForAutoLayout()
        label.text = "..."
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .Content.high
        label.textAlignment = .center
        return label
    }()

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel.initForAutoLayout()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .Content.mid
        label.numberOfLines = 0
        label.text = "Connecting..."
        return label
    }()

    private lazy var mainStackView: UIStackView = {
        let stackView = UIStackView.initForAutoLayout()
        stackView.axis = .vertical
        stackView.spacing = Spacer.size01
        stackView.addArrangedSubviews([threeDotsIconView, placeholderLabel])
        stackView.alignment = .center
        return stackView
    }()

    // MARK: Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: Setup

    func setup(text: String) {
        placeholderLabel.text = text
    }

    private func setupView() {
        addSubview(mainStackView)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),
            topAnchor.constraint(equalTo: mainStackView.topAnchor),
            trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor),
            bottomAnchor.constraint(equalTo: mainStackView.bottomAnchor)
        ])
    }

}
