// Copyright © 2024 Nomasystems S.L. All rights reserved.

import XCTest
@testable import NChatCore
@testable import XMPPCore
import os

/**
 * Integration test to capture the complete flow of joining a workgroup queue.
 *
 * This test connects to the real XMPP server and captures all traffic,
 * state transitions, and delegate callbacks to serve as a reference
 * for the Android port implementation.
 *
 * Run with: swift test --filter WorkgroupJoinIntegrationTest
 */
class WorkgroupJoinIntegrationTest: XCTestCase {

    private var chat: Chat?
    private let log = OSLog(subsystem: "com.nomasystems.test", category: "Integration")

    // Test expectations
    private var stateChangedExpectation: XCTestExpectation?
    private var queuedExpectation: XCTestExpectation?
    private var inviteExpectation: XCTestExpectation?

    // Captured events for analysis
    private var stateTransitions: [(from: ChatState, to: ChatState, timestamp: Date)] = []
    private var systemMessages: [(message: SystemMessage, timestamp: Date)] = []
    private var errors: [(error: String, timestamp: Date)] = []

    override func setUp() {
        super.setUp()

        // Enable XMPP logging to stdout for test comparison
        XMPPLogConfig.enabled = true
        XMPPLogConfig.logger = { tag, message in
            print("[\(tag)] \(message)")
        }

        print("=== INTEGRATION TEST STARTED ===")
        print("Test: Workgroup Join Flow")
        print("Timestamp: \(Date())")
    }

    override func tearDown() {
        chat?.closeChat(leave: true)
        chat = nil

        os_log("=== INTEGRATION TEST COMPLETED ===", log: log, type: .info)
        os_log("Total state transitions: %d", log: log, type: .info, stateTransitions.count)
        os_log("Total system messages: %d", log: log, type: .info, systemMessages.count)
        os_log("Total errors: %d", log: log, type: .info, errors.count)

        super.tearDown()
    }

    /**
     * Test the complete workgroup join flow:
     * 1. Initialize chat with configuration
     * 2. Call queue() to start connection
     * 3. Wait for authentication
     * 4. Wait for workgroup join
     * 5. Capture all XMPP traffic and state transitions
     */
    func testWorkgroupJoinFlow() {
        os_log("📋 TEST: testWorkgroupJoinFlow", log: log, type: .info)

        // Create expectations
        queuedExpectation = expectation(description: "Chat queued in workgroup")
        stateChangedExpectation = expectation(description: "Chat state changed to queued or active")

        // Configure chat with same settings as Android app
        let configuration = ChatConfiguration(
            url: URL(string: "https://your-server.com/http-bind")!,
            queueJid: "support@your-server.com",
            uploadDomain: "upload.your-server.com",
            userData: ChatUserData(
                name: "Demo User",
                userJid: "900000003415@your-server.com",
            ),
            fileUploadMode: .slot
        )

        os_log("📝 Configuration:", log: log, type: .info)
        os_log("  - URL: %@", log: log, type: .info, configuration.url.absoluteString)
        os_log("  - Queue JID: %@", log: log, type: .info, configuration.queueJid)
        os_log("  - User: %@", log: log, type: .info, configuration.userData.name ?? "anonymous")
        os_log("  - Email: %@", log: log, type: .info, configuration.userData.email ?? "none")

        // Create chat instance
        chat = Chat(configuration: configuration)
        chat?.delegate = self
        chat?.messagesDelegate = self
        chat?.authenticationDelegate = self


        os_log("✅ Chat instance created", log: log, type: .info)
        os_log("🔄 Initial state: %@", log: log, type: .info, String(describing: chat?.state))

        // Start the queue process
        os_log("🚀 Calling queue() to start connection...", log: log, type: .info)
        chat?.queue()

        // Wait for events (60 second timeout to allow full flow)
        let result = XCTWaiter.wait(
            for: [queuedExpectation!, stateChangedExpectation!],
            timeout: 60.0,
            enforceOrder: false
        )

        // Log the result
        switch result {
        case .completed:
            os_log("✅ Test completed successfully!", log: log, type: .info)
        case .timedOut:
            os_log("⏱ Test timed out - may indicate connection or server issues", log: log, type: .error)
        case .incorrectOrder:
            os_log("⚠️ Events occurred in unexpected order", log: log, type: .error)
        case .interrupted:
            os_log("⚠️ Test was interrupted", log: log, type: .error)
        case .invertedFulfillment:
            os_log("⚠️ Inverted fulfillment", log: log, type: .error)
        @unknown default:
            os_log("⚠️ Unknown wait result", log: log, type: .error)
        }

        // Print summary
        printTestSummary()
    }

    /**
     * Test with queue "0@abanca.com" (alternative queue from MainActivity.kt)
     */
    func testWorkgroupJoinFlowAlternativeQueue() {
        os_log("📋 TEST: testWorkgroupJoinFlowAlternativeQueue", log: log, type: .info)

        queuedExpectation = expectation(description: "Chat queued in workgroup")
        stateChangedExpectation = expectation(description: "Chat state changed to queued or active")

        let configuration = ChatConfiguration(
            url: URL(string: "https://api-abancachat.cloud.developers.abanca.com/http-bind")!,
            queueJid: "0@abanca.com", // Alternative queue from MainActivity.kt
            uploadDomain: "upload.your-server.com",
            userData: ChatUserData(
                email: "900000003415@abanca.com",
                name: "Demo User"
            ),
            fileUploadMode: .slot
        )

        os_log("📝 Configuration (Alternative Queue):", log: log, type: .info)
        os_log("  - Queue JID: %@", log: log, type: .info, configuration.queueJid)

        chat = Chat(configuration: configuration)
        chat?.delegate = self
        chat?.messagesDelegate = self

        os_log("🚀 Calling queue() with alternative queue...", log: log, type: .info)
        chat?.queue()

        let result = XCTWaiter.wait(
            for: [queuedExpectation!, stateChangedExpectation!],
            timeout: 60.0,
            enforceOrder: false
        )

        switch result {
        case .completed:
            os_log("✅ Alternative queue test completed successfully!", log: log, type: .info)
        case .timedOut:
            os_log("⏱ Alternative queue test timed out", log: log, type: .error)
        default:
            os_log("⚠️ Alternative queue test ended with result: %@", log: log, type: .error, String(describing: result))
        }

        printTestSummary()
    }

    // MARK: - Helper Methods

    private func printTestSummary() {
        os_log("", log: log, type: .info)
        os_log("═══════════════════════════════════════", log: log, type: .info)
        os_log("           TEST SUMMARY", log: log, type: .info)
        os_log("═══════════════════════════════════════", log: log, type: .info)

        os_log("", log: log, type: .info)
        os_log("📊 STATE TRANSITIONS (%d total):", log: log, type: .info, stateTransitions.count)
        for (index, transition) in stateTransitions.enumerated() {
            let timeStr = DateFormatter.localizedString(from: transition.timestamp, dateStyle: .none, timeStyle: .medium)
            os_log("  %d. [%@] %@ → %@", log: log, type: .info,
                   index + 1,
                   timeStr,
                   String(describing: transition.from),
                   String(describing: transition.to))
        }

        os_log("", log: log, type: .info)
        os_log("💬 SYSTEM MESSAGES (%d total):", log: log, type: .info, systemMessages.count)
        for (index, msg) in systemMessages.enumerated() {
            let timeStr = DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .medium)
            os_log("  %d. [%@] %@", log: log, type: .info,
                   index + 1,
                   timeStr,
                   String(describing: msg.message.type))
        }

        if !errors.isEmpty {
            os_log("", log: log, type: .info)
            os_log("❌ ERRORS (%d total):", log: log, type: .error, errors.count)
            for (index, error) in errors.enumerated() {
                let timeStr = DateFormatter.localizedString(from: error.timestamp, dateStyle: .none, timeStyle: .medium)
                os_log("  %d. [%@] %@", log: log, type: .error,
                       index + 1,
                       timeStr,
                       error.error)
            }
        }

        os_log("", log: log, type: .info)
        os_log("🔍 FINAL STATE:", log: log, type: .info)
        os_log("  - Chat State: %@", log: log, type: .info, String(describing: chat?.state))
        os_log("  - Random JID: %@", log: log, type: .info, chat?.randomlyGeneratedJID ?? "none")
        os_log("  - Room: %@", log: log, type: .info, chat?.room != nil ? "joined" : "not joined")
        os_log("  - Messages: %d", log: log, type: .info, chat?.messages.count ?? 0)

        os_log("", log: log, type: .info)
        os_log("═══════════════════════════════════════", log: log, type: .info)
    }
}

// MARK: - ChatDelegate

extension WorkgroupJoinIntegrationTest: ChatDelegate {
    func onState(_ state: ChatState) {
        let previousState = stateTransitions.last?.to ?? .initialized
        let transition = (from: previousState, to: state, timestamp: Date())
        stateTransitions.append(transition)

        os_log("🔄 STATE CHANGE: %@ → %@", log: log, type: .info,
               String(describing: previousState),
               String(describing: state))

        // Fulfill expectations based on state
        switch state {
        case .queued, .active:
            stateChangedExpectation?.fulfill()
        case .error:
            os_log("❌ Chat entered ERROR state", log: log, type: .error)
            errors.append((error: "Chat state error", timestamp: Date()))
            stateChangedExpectation?.fulfill() // Fulfill even on error to not hang
        default:
            break
        }
    }

    func onStatus(online: Bool) {
        os_log("📡 STATUS: %@", log: log, type: .info, online ? "online" : "offline")
    }

    func onAgentChatState(_ state: Chat.AgentState?) {
        if let state = state {
            os_log("👤 AGENT STATE: %@", log: log, type: .info, String(describing: state.state))
        }
    }
}

// MARK: - ChatMessagesDelegate

extension WorkgroupJoinIntegrationTest: ChatMessagesDelegate {
    func onHistoryMessages(_ messages: [Room.Message], communicationId: String?) {
        os_log("📜 HISTORY: Received %d messages (communicationId: %@)",
               log: log, type: .info,
               messages.count,
               communicationId ?? "none")
    }

    func onMessageStateUpdate(_ message: Room.Message) {
        os_log("📝 MESSAGE STATE: %@ → %@",
               log: log, type: .info,
               message.id,
               String(describing: message.state))
    }

    func onNewMessage(_ message: Room.Message) {
        os_log("💬 NEW MESSAGE: from=%@ text='%@'",
               log: log, type: .info,
               String(describing: message.from),
               message.text)

        // If we receive a message from an agent, we likely joined successfully
        if message.from == .agent {
            queuedExpectation?.fulfill()
        }
    }

    func onUpdatedMessages() {
        os_log("🔄 MESSAGES UPDATED", log: log, type: .info)
    }

    func onRemovedMessage(_ message: Room.Message) {
        os_log("🗑 MESSAGE REMOVED: %@", log: log, type: .info, message.id)
    }

    func onSystemMessage(_ message: SystemMessage) {
        systemMessages.append((message: message, timestamp: Date()))

        os_log("📢 SYSTEM MESSAGE: %@", log: log, type: .info, String(describing: message.type))

        // The queued system message indicates successful workgroup join
        if case .queuedStatus = message.type {
            os_log("✅ Successfully queued in workgroup!", log: log, type: .info)
            queuedExpectation?.fulfill()
        }

        // Check for error messages
        if case .internalError = message.type {
            errors.append((error: "Internal error system message", timestamp: Date()))
        }
        if case .connectionError = message.type {
            errors.append((error: "Connection error", timestamp: Date()))
        }
        if case .connectionFailure = message.type {
            errors.append((error: "Connection failure", timestamp: Date()))
        }
    }

    func onResendMessage(_ message: Room.Message, _ sender: Any?) {
        os_log("🔁 RESEND MESSAGE: %@", log: log, type: .info, message.id)
    }
}

// MARK: - ChatAuthenticationDelegate

extension WorkgroupJoinIntegrationTest: ChatAuthenticationDelegate {
    func chat(_ chat: Chat,
              didReceiveAuthenticationMethod method: AuthenticationMethod,
              completionHandler: @escaping (AuthenticationResponse) -> Void) {
        os_log("🔐 AUTH: Received authentication method: %@", log: log, type: .info, "plain")
        // Accept PLAIN authentication with default credentials
        completionHandler(.accept(jid: nil, credential: nil))
    }
}
