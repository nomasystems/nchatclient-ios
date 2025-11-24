import UIKit

class MessageNumbersView: UIView {

    typealias Action = () -> Void

    // MARK: Views

    private let messagesNumberLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    private lazy var showLabel: UILabel = {
        let label = UILabel()
        label.text = "VIEW"
        return label
    }()

    lazy var mainStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            messagesNumberLabel,
            UIView(),
            showLabel
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 12
        return stackView
    }()

    // MARK: Properties

    var numberOfMessages: Int {
        didSet {
            let newMessagesText = numberOfMessages == 1
            ? "%d new message"
            : "%d new messages"

            messagesNumberLabel.text = String(format: newMessagesText, numberOfMessages)
        }
    }

    private var action: Action

    // MARK: Init

    init(numberOfMessages: Int, showAction: @escaping Action) {
        self.numberOfMessages = numberOfMessages
        self.action = showAction
        super.init(frame: .zero)
        loadView()
    }

    required init?(coder: NSCoder) {
        numberOfMessages = 0
        action = {}
        super.init(coder: coder)
        loadView()
    }

    // MARK: Load View

    private func loadView() {
        addSubview(mainStackView)
        NSLayoutConstraint.activate([
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor, constant: 16),
            bottomAnchor.constraint(equalTo: mainStackView.bottomAnchor, constant: 12)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showAction))
        addGestureRecognizer(tapGesture)
    }

    func setupStyle(backgroundColor bgColor: UIColor, textColor: UIColor, labelsFont: UIFont) {
        backgroundColor = bgColor
        messagesNumberLabel.textColor = textColor
        showLabel.textColor = textColor
        messagesNumberLabel.font = labelsFont
        showLabel.font = labelsFont
        layer.cornerRadius = 8
    }

    @objc func showAction() {
        action()
    }

}
