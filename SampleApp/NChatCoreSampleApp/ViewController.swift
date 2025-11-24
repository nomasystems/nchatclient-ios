//Copyright 2025

import UIKit
import NChatCore

class ViewController: UIViewController {

    // Configuration properties
    private var serverURL: String = "https://your-server.com/http-bind"
    private var queueJID: String = "support@your-server.com"
    private var domain: String = "your-server.com"
    private var userName: String = "Test User"
    private var userEmail: String = "user@your-server.com"
    private var userID: String = "user"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "NChatCore Sample"

        // Add start button
        let startButton = UIButton(type: .system)
        startButton.setTitle("Start Chat", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        startButton.backgroundColor = .systemBlue
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 8
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startChatTapped), for: .touchUpInside)

        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func startChatTapped() {
        guard let url = URL(string: serverURL) else {
            showAlert(title: "Invalid URL", message: "Please check server URL configuration")
            return
        }

        // Build the chat
        let chat = SampleChat.build(
            queueJid: queueJID,
            domain: domain,
            serverUrl: url,
            userEmail: userEmail.isEmpty ? nil : userEmail,
            userName: userName.isEmpty ? nil : userName,
            userId: userID.isEmpty ? nil : userID
        )

        SampleChat.shared = chat

        // Present ConversationController
        let conversationVC = ConversationController.instantiate()
        let navController = UINavigationController(rootViewController: conversationVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
