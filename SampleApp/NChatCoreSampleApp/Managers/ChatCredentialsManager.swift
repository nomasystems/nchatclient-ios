import Foundation

// MARK: - Types

public typealias Credentials = (username: String, password: String)

/// Generates a pair of username and password for chat authentication.
/// This is a simplified version for the sample app.
final class ChatCredentialsManager {

    // MARK: - Public

    public static let chatUserUidKey = "com.nchat.sample.uid"

    public private(set) var username: String?
    public private(set) var password: String?

    public init(domain: String, userId: String?) {
        generateCredentials(domain: domain, userId: userId)
    }

    // MARK: - Private

    private func generateCredentials(domain: String, userId: String?) {
        // Generate or retrieve user JID
        if let userId = userId {
            username = "\(userId)@\(domain)/ios"
            // Store for later retrieval
            UserDefaults.standard.set(username, forKey: Self.chatUserUidKey)
        } else {
            // Try to retrieve previously stored username
            username = UserDefaults.standard.string(forKey: Self.chatUserUidKey)
        }

        // For the sample app, we use a simple password approach
        // In production, this would involve proper authentication tokens
        password = generateSamplePassword(userId: userId)
    }

    private func generateSamplePassword(userId: String?) -> String? {
        guard let userId = userId, let username = username else { return nil }

        // Simple authentication body for sample purposes
        let authBody = "\(username)\0\(userId)\0samplepassword"
        return authBody.data(using: .utf8)?.base64EncodedString()
    }
}
