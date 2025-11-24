//  Copyright © 2018 Nomasystems S.L. All rights reserved.

import NChatCore
import UIKit
import XMPPCore

public final class ConversationController: UIViewController {

    // MARK: Views

    @IBOutlet private weak var accessoryView: ChatInputAccessoryView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var accessoryViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private var tableViewHeightConstraint: NSLayoutConstraint?
    @IBOutlet private var tableTopMarginConstraint: NSLayoutConstraint?
    @IBOutlet private weak var legalTextLabel: UILabel!
    @IBOutlet private weak var noticeView: UIView!
    @IBOutlet private var noticeViewHideConstraint: NSLayoutConstraint?
    @IBOutlet private weak var currentDateLabel: LabelWithMargins!

    private lazy var showMessagesView: MessageNumbersView = {
        let view = MessageNumbersView(numberOfMessages: 0, showAction: { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.scrollToBottom()
                self.resetMessagesView()
            }
        })
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: Options drawer

    private enum OptionKind: Int {
        case camera
        case library
        case product
    }

    // MARK: Properties

    // General
    private var chat: SampleChat? { SampleChat.shared }
    private var chatCredentialsManager: ChatCredentialsManager?
    private var onFinishLoading: (() -> Void)?
    private var keyboardObservers: [NSObjectProtocol] = []
    private let placeholderView = ConnectingPlaceholderView.initForAutoLayout()
    private var isAttachmentFeatureAvailable: Bool {
        areAttachmentsLoaded || Camera.isCameraAvailable || Camera.isPhotoLibraryAvailable
    }

    // Attachments
    private var showingActionSheet = false
    private var camera: CameraProtocol?
    private var areAttachmentsLoaded: Bool {
        !ChatAttachmentsManager.shared.attachments.isEmpty
    }

    // History navigation
    private var isFirstCommunication = true
    private var isLoadingNewMessages = false
    private var hasMoreHistoryMessages = false
    private var numberOfCommunications = 0
    private var activityIndicatorCell: UIActivityIndicatorView?
    private var timer: Timer?
    private var mustShowErrorLoadingHistory = false

    // Chat info
    private var contactTopicTitle: String?
    private var outOfScheduleMsg: String?
    private var newMessagesCount: Int = 0
    private var isAgentComposing = false
    private var mustShowLegalNotice: Bool {
        !visibleMessages.contains { $0.from == .user }
    }

    // Status bar
    private var statusBarStyle: UIStatusBarStyle = .default

    /// Maximum of retries
    ///
    /// Current value is defined by app business requirements. In the future it could be explicited by MOCA config. For now it must stay hardcoded front side.
    private let maxRetries: Int = 3
    private var connectionRetries: Int = 0
    private var timeBetweenRetries: CGFloat = 8.0 // measured in seconds
    private var shouldRetryConnection: Bool {
        connectionRetries < maxRetries
    }

    /// Represents the visible messages in screen. Helpful when a reconnection is being retried, so that messages do not disappear from screen
    /// (because `chat.messages` becomes empty in such a case).
    private var visibleMessages: [Room.Message] = []

    private var messages: [Room.Message] {
        guard let chat = chat else { return [] }
        return chat.uniqueMessages
    }

    // MARK: - Initialization

    public static func instantiate(contactTopicTitle: String? = nil,
                                   onFinishLoading: (() -> Void)? = nil) -> ConversationController {
        let sb = UIStoryboard(name: "ConversationController", bundle: Bundle(for: self))
        guard let vc = sb.instantiateInitialViewController() as? ConversationController else {
            fatalError("ConversationController is misconfigured")
        }
        vc.chatCredentialsManager = ChatCredentialsManager(domain: "", userId: nil)
        vc.onFinishLoading = onFinishLoading
        vc.contactTopicTitle = contactTopicTitle
        return vc
    }

    static func instantiate(outOfScheduleMsg: String) -> ConversationController {
        let sb = UIStoryboard(name: "ConversationController", bundle: Bundle(for: self))
        guard let vc = sb.instantiateInitialViewController() as? ConversationController else {
            fatalError("ConversationController is misconfigured")
        }
        vc.outOfScheduleMsg = outOfScheduleMsg
        return vc
    }

    // MARK: - UIViewController Customizations

    public override var canBecomeFirstResponder: Bool {
        !showingActionSheet && isInputEnabled
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        statusBarStyle
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupDateBubble()
        setupNavBar()
        if outOfScheduleMsg != nil {
            setupOutOfSchedule()
        } else {
            accessoryView.chatInputAccessoryViewDelegate = self
            showConnectingView()
            addKeyboardObservers()
            startChat()
        }
        setupLegalNotice()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isInputEnabled = chat?.isInputEnabled ?? false
        onFinishLoading?()
    }

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        visibleMessages = messages
        tableView.reloadData()
        updateTableViewHeight(animated: false)
        accessoryView.textView.text = chat?.userInput // Restore the previously entered user input
        chat?.background = false
        if let delegate = chat?.bubblesDelegate {
            accessoryView.setup(placerHolderMessageFont: delegate.fontForWriteAMessagePlaceHolder(),
                                sendButtonFont: delegate.fontForSendButton())
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        accessoryView.textView.resignFirstResponder()
        accessoryView.setAttachButton(enabled: isAttachmentFeatureAvailable)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableViewHeightConstraint?.constant = tableView.contentSize.height
    }

    public override func loadView() {
        super.loadView()
        view.addSubview(showMessagesView)
        NSLayoutConstraint.activate([
            showMessagesView.bottomAnchor.constraint(equalTo: accessoryView.topAnchor),
            showMessagesView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: showMessagesView.trailingAnchor)
        ])
        if let newMessagesDelegate = chat?.newMessagesDelegate {
            showMessagesView.setupStyle(backgroundColor: newMessagesDelegate.backgroundColorForToast(),
                                        textColor: newMessagesDelegate.textColorForToastLabels(),
                                        labelsFont: newMessagesDelegate.fontForToastLabels())
        }
    }

}

// MARK: - ChatAuthenticationDelegate

extension ConversationController: ChatAuthenticationDelegate {

    public func chat(_ chat: Chat,
                     didReceiveAuthenticationMethod method: AuthenticationMethod,
                     completionHandler: @escaping (AuthenticationResponse) -> Void) {
        switch method {
        case .custom:
            completionHandler(.skip)
        case .plain:
            if let existingUid = UserDefaults.standard.object(forKey: ChatCredentialsManager.chatUserUidKey) as? String {
                completionHandler(.accept(jid: existingUid, credential: nil))
            } else {
                completionHandler(.accept(jid: nil, credential: nil))
                if let jid = chat.randomlyGeneratedJID {
                    UserDefaults.standard.set(jid, forKey: ChatCredentialsManager.chatUserUidKey)
                }
            }
        }
    }

}

// MARK: - ChatDelegate

extension ConversationController: ChatDelegate {
    public func onState(_ state: ChatState) {
        switch state {
        case .error:
            retryConnection()
            isInputEnabled = false
        case .closing:
            navigationItem.setRightBarButton(nil, animated: true)
            fallthrough
        case .queued:
            hideConnectingView()
            fallthrough
        default:
            isInputEnabled = chat?.isInputEnabled ?? false
        }
    }

    public func onStatus(online: Bool) {
        // Not used.
    }

    public func onAgentChatState(_ state: Chat.AgentState?) {
        let indexPath = IndexPath(row: 0, section: 0)
        if state?.state == .composing, !isAgentComposing {
            isAgentComposing = true
            tableView.insertRows(at: [indexPath], with: .fade)
            updateTableViewHeight(animated: true)
        } else if state?.state != .composing, isAgentComposing {
            isAgentComposing = false
            tableView.deleteRows(at: [indexPath], with: .fade)
            updateTableViewHeight(animated: true)
        }
    }
}

// MARK: - ChatMessagesDelegate

extension ConversationController: ChatMessagesDelegate {

    public func onHistoryMessages(_ message: [Room.Message], communicationId: String?) {
        hasMoreHistoryMessages = communicationId != nil
        mustShowErrorLoadingHistory = false
        isLoadingNewMessages = false
        isFirstCommunication = false
        numberOfCommunications += 1

        // Load history if...
        if (tableView.contentSize.height < UIScreen.main.bounds.height && numberOfCommunications < 5), // screen is still not filled up AND...
           (isFirstCommunication || hasMoreHistoryMessages) { // ... has or may have previous communications
            isLoadingNewMessages = true
            chat?.room?.fetchHistory()
        } else {
            visibleMessages = messages
            hideLoadingSpinner()
            tableView.reloadData()
            if visibleMessages.count == 1 { // When initiating a new chat, this allows right positioning the messages.
                tableView.reloadSections([0], with: .none)
            }
            updateTableViewHeight(animated: false)
        }
        hideNoticeView(!mustShowLegalNotice)
    }

    public func onMessageStateUpdate(_ message: Room.Message) {
        visibleMessages = messages
        guard let index = visibleMessages.firstIndex(where: { $0 == message }) else { return }
        let invertedIndex = self.messageIndex(forIndexPathRow: index)
        let indexPath = IndexPath(row: invertedIndex, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
        updateTableViewHeight(animated: true)
        hideNoticeView(!mustShowLegalNotice)
    }

    public func onNewMessage(_ message: Room.Message) {
        guard messages.count > visibleMessages.count else { return }
        let insertIndexPath = IndexPath(row: isAgentComposing ? 1 : 0, section: 0)
        visibleMessages = messages
        tableView.performBatchUpdates {
            tableView.insertRows(at: [insertIndexPath], with: .fade)
        }
        updateTableViewHeight(animated: true)
        showToast(for: message)
        hideNoticeView(!mustShowLegalNotice)
    }

    public func onUpdatedMessages() {
        visibleMessages = messages
        tableView.reloadData()
        updateTableViewHeight(animated: true)
        hideNoticeView(!mustShowLegalNotice)
    }

    public func onRemovedMessage(_ message: Room.Message) {
        visibleMessages = messages
        tableView.reloadSections([0], with: .fade)
        updateTableViewHeight(animated: true)
    }

    public func onSystemMessage(_ message: SystemMessage) {
        switch message.type {
        case .connectionError:
            showConnectingView(text: SampleChat.localization.connectionErrorString)
        case .connectionFailure:
            showConnectingView(text: SampleChat.localization.connectionFailureString)
        case .internalError(let msg):
            showConnectingView(text: msg ?? SampleChat.localization.internalErrorString)
        case .pendingStatus:
            showConnectingView(text: SampleChat.localization.pendingStatus)
        case .queuedStatus:
            showConnectingView(text: SampleChat.localization.queuedStatus)
        default:
            hideConnectingView()
        }
    }

    public func onResendMessage(_ message: Room.Message, _ sender: Any?) {
        // Not used.
    }
}

// MARK: - UITableViewDataSource

extension ConversationController: UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard outOfScheduleMsg == nil else { return 1 }
        return visibleMessages.count + (isAgentComposing ? 1 : 0)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        if let msg = outOfScheduleMsg {
            // Out of schedule message.
            let inboundCell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleTableViewCell.inboundReuseIdentifier, for: indexPath) as! ChatBubbleTableViewCell
            if let bubbleDelegate = chat?.bubblesDelegate {
                inboundCell.setFonts(messageFont: bubbleDelegate.fontForBubbleMessage(), timestampFont: bubbleDelegate.fontForBubbleTimestamp())
            }
            inboundCell.display(placeholder: msg)
            inboundCell.setup(bubbleDate: Date(),
                              font: chat?.topicDelegate?.fontForSystemTimestamp(),
                              textColor: chat?.topicDelegate?.textColourForBubble())
            cell = inboundCell
        } else if isAgentComposing && indexPath.row == 0 {
            // Bubble with a "..." indicating agent is composing a message.
            let inboundCell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleTableViewCell.inboundReuseIdentifier, for: indexPath) as! ChatBubbleTableViewCell
            if let bubbleDelegate = chat?.bubblesDelegate {
                inboundCell.setFonts(messageFont: bubbleDelegate.fontForBubbleMessage(), timestampFont: bubbleDelegate.fontForBubbleTimestamp())
            }
            inboundCell.display(placeholder: "...")
            cell = inboundCell
        } else {
            guard !visibleMessages.isEmpty else { return .init() }
            cell = messageCell(for: indexPath)
            cell.layoutIfNeeded()
        }
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        return cell
    }

    private func messageCell(for indexPath: IndexPath) -> UITableViewCell {

        func isLastWorkgroupMessage(msg: Room.Message) -> Bool {
            let lastWorkgroupMsg = visibleMessages.last { $0.from == .workgroup }
            return lastWorkgroupMsg?.same(as: msg) == true
        }

        func shouldDisplayDate(for message: Room.Message) -> Bool {
            let position = visibleMessages.firstIndex { $0 == message }
            guard let position = position, message.from == .workgroup else { return false }
            if position == 0 {
                return true
            } else {
                let previousMsg = visibleMessages[position - 1]
                return !Calendar.current.isDate(previousMsg.timestamp, inSameDayAs: message.timestamp)
            }
        }

        let msg = visibleMessages[messageIndex(forIndexPathRow: indexPath.row)]
        let cellId = [.agent, .workgroup].contains(msg.from) ? ChatBubbleTableViewCell.inboundReuseIdentifier : ChatBubbleTableViewCell.outboundReuseIdentifier
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! ChatBubbleTableViewCell
        if let bubbleDelegate = chat?.bubblesDelegate {
            cell.setFonts(messageFont: bubbleDelegate.fontForBubbleMessage(), timestampFont: bubbleDelegate.fontForBubbleTimestamp())
        }
        cell.display(message: msg)
        cell.configure(delegate: self, urlHandler: ChatURLHandler())
        
        switch msg.from {
        case .user:
            break
        case .agent:
            if indexPath.row == 0 { // Buttons are only displayed for the most recent message.
                cell.setup(buttons: msg.buttons, bubblesDelegate: chat?.bubblesDelegate)
            }
        case .workgroup:
            if let title = contactTopicTitle, isLastWorkgroupMessage(msg: msg) {
                let text = String(format: NSLocalizedString("Has solicitado ayuda con “%@”", comment: ""), title)
                cell.setup(topic: text)
            }
            if shouldDisplayDate(for: msg) {
                cell.setup(bubbleDate: msg.timestamp,
                           font: chat?.topicDelegate?.fontForSystemTimestamp(),
                           textColor: chat?.topicDelegate?.textColourForBubble())
            }
        }
        return cell
    }

}

// MARK: - UITableViewDelegate

extension ConversationController: UITableViewDelegate {

    // Two ways of detecting when user reaches the top to potentially load more messages.

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        func isFirstMessage(indexPath: IndexPath) -> Bool {
            // Check against last row since tableView is flipped
            indexPath.row == tableView.numberOfRows(inSection: 0) - 1
        }

        guard !isLoadingNewMessages,
              isFirstMessage(indexPath: indexPath),
              isFirstCommunication || hasMoreHistoryMessages
        else { return }

        startLoadingHistory()
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let topmostIndexPath = tableView.indexPathsForVisibleRows?.last { // last because tableView is inverted
            displayCurrentDateIfNeeded(indexPath: topmostIndexPath)
        }
        guard !isLoadingNewMessages,
              // start loading a bit before reaching the top
              scrollView.contentOffset.y >= tableView.contentSize.height - UIScreen.main.bounds.height,
              isFirstCommunication || hasMoreHistoryMessages
        else { return }

        startLoadingHistory()
    }
}

// MARK: - ChatInputAccessoryViewDelegate

extension ConversationController: ChatInputAccessoryViewDelegate {
    func send(chatInputAccessoryView view: ChatInputAccessoryView, message: String) -> Bool {
        let msg = message.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !msg.isEmpty {
            chat?.send(message: msg)
            return true
        }
        return false
    }

    func attach() {
        // TODO: Implement
    }

    func didBeginComposing() {
        chat?.set(peerState: .composing)
    }

    func didEndComposing() {
        chat?.set(peerState: .active)
    }

    func didChangeText(newInput: String) {
        chat?.userInput = newInput
    }
}

// MARK: - ChatBubbleTableViewCellDelegate

extension ConversationController: ChatBubbleTableViewCellDelegate {
    func didSelect(button: Button) {
        func map(button: Button) -> String? {
            let fields = [Field(type: "list-single", var: "buttons", options: [], label: button.text, value: button.value)]
            let rbodyData = Rbody(type: "submit", fields: fields)
            if let jsonData = try? JSONEncoder().encode(rbodyData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return nil
            }
        }

        let metadata = map(button: button)
        chat?.send(message: button.text, metadata: metadata, state: .delivered)
        tableView.reloadData()
    }

    func userWantsToZoom(image: UIImage) {
        zoom(on: image)
    }
}

// MARK: - Private

private extension ConversationController {

    // MARK: Initial setup

    func setupTableView() {
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 105
        // The tableView is flipped so the bottom and the top are swapped.
        // This means it's harder to reason about the ordering of the sections/cells
        // but helps a lot with scrolling and keeping the chat glued to the bottom of
        // the screen when inserting new cells there.
        // I (Marcelino) didn't find a less painful way to get the same result without
        // a performance hit or graphical glitches.
        // Inspired by this SO answer: http://stackoverflow.com/a/28435207
        tableView.transform = CGAffineTransform(scaleX: 1, y: -1)
    }

    func startChat() {
        chat?.delegate = self
        chat?.messagesDelegate = self
        chat?.authenticationDelegate = self
        if [.initialized, .error].contains(chat?.state) {
            chat?.queue()
        }
    }

    func addKeyboardObservers() {
        keyboardObservers = [
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil) { [weak self] (notification) in
                self?.scrollAlongKeyBoard(notification: notification, isHiding: false)
            },
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil) { [weak self] (notification) in
                self?.scrollAlongKeyBoard(notification: notification, isHiding: true)
            },
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: nil) { [weak self] (notification) in
                self?.scrollAlongKeyBoard(notification: notification, isHiding: false)
            }
        ]
    }

    func showConnectingView(text: String? = nil) {
        guard SampleChat.shared?.isConnecting == true else { return }
        [tableView,
         accessoryView].forEach { $0.isHidden = true }
        hideNoticeView(true)
        view.addSubview(placeholderView)
        NSLayoutConstraint.activate([
            placeholderView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            placeholderView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        if let text = text {
            placeholderView.setup(text: text)
        }
    }

    func hideConnectingView() {
        SampleChat.shared?.isConnecting = false
        [tableView,
         accessoryView].forEach { $0.isHidden = false }
        hideNoticeView(false)
        placeholderView.removeFromSuperview()
    }

    func showToast(for message: Room.Message) {
        guard tableView.contentOffset != .zero,
              message.from == .agent,
              message.state == .delivered
        else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.newMessagesCount += 1
            self.showMessageNumbers(self.newMessagesCount)
        }
    }

    // MARK: Date bubble at the top

    func displayCurrentDateIfNeeded(indexPath: IndexPath) {
        timer?.invalidate()
        timer = nil
        let index = messageIndex(forIndexPathRow: indexPath.row)
        guard visibleMessages.count > index else { return }
        currentDateLabel.text = visibleMessages[index].timestamp.bubbleFormat
        showDateBubble()
        timer = Timer.scheduledTimer(timeInterval: 0.65, target: self, selector: #selector(hideDateBubble), userInfo: nil, repeats: false)
    }

    func showDateBubble() {
        currentDateLabel.isHidden = false
        currentDateLabel.alpha = 1
    }

    @objc func hideDateBubble() {
        UIView.animate(withDuration: 0.7, animations: {
            self.currentDateLabel.alpha = 0
        }) { (finished) in
            self.currentDateLabel.isHidden = finished
        }
    }

    func setupDateBubble() {
        guard let delegate = chat?.topicDelegate else { return }
        view.bringSubviewToFront(currentDateLabel)
        currentDateLabel.setup(with: "", // initially empty
                               font: delegate.fontForSystemTimestamp(),
                               textColor: delegate.textColourForBubble())
        currentDateLabel.isHidden = true
    }

    // MARK: on scroll events

    func startLoadingHistory() {
        isLoadingNewMessages = true
        chat?.room?.fetchHistory()
        showLoadingSpinner()
    }

    /** The tableView is flipped upside-down for efficiency reasons.
     *  That causes the messages to start appearing from the bottom. In order to pull them back
     *  to the top, we use a >= constraint at the bottom of the tableView and update the height
     *  of the tableView manually */
    func updateTableViewHeight(animated: Bool) {
        if animated {
            UIView.animate(withDuration: animated ? 0.3 : 0) {
                self.tableViewHeightConstraint?.constant = self.tableView.contentSize.height
                self.view.layoutIfNeeded()
            }
        } else {
            tableViewHeightConstraint?.constant = tableView.contentSize.height
            view.layoutIfNeeded()
        }
    }

    func scrollAlongKeyBoard(notification: Notification, isHiding: Bool) {
        guard let chat = chat else { return }
        if isHiding {
            accessoryViewBottomConstraint.constant = .zero
            if [.closing, .closed, .error].contains(chat.state) {
                isInputEnabled = false
            }
        } else if let keyboardRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            accessoryViewBottomConstraint.constant = keyboardRect.height - view.safeAreaInsets.bottom + Spacer.size03
        }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UIView.AnimationOptions ?? .curveEaseIn
        UIView.animate(withDuration: duration, delay: 0, options: curve, animations: { [weak self] in
            self?.view.layoutIfNeeded()
        }) { [weak self] _ in
            self?.scrollToBottom()
        }
    }

    func scrollToBottom() {
        // The "bottom" is actually the top because the tableView is flipped (see viewDidLoad)
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.contentInset.top), animated: true)
    }

    // MARK: Helper properties and methods

    var isInputEnabled: Bool {
        get {
            accessoryView.editable
        }
        set {
            accessoryView.editable = newValue
            guard let chat = chat else { return }
            if newValue {
                // Shows text input.
                accessoryView.textView.becomeFirstResponder()
            } else if [.closing, .closed, .error].contains(chat.state) {
                // Hides text input.
                accessoryView.textView.resignFirstResponder()
            }
        }
    }

    func messageIndex(forIndexPathRow indexPathRow: Int) -> Int {
        // Note that we flip the indexPath of the selected message because the table view is inverted.
        let index = visibleMessages.count - indexPathRow - (isAgentComposing ? 0 : 1)
        return index >= 0 ? index : 0
    }

    func hasSystemMessage() -> Bool {
        guard let systemMessage = chat?.systemMessage else { return false }
        if let lmg = visibleMessages.last {
            return lmg.timestamp < systemMessage.timestamp
        } else {
            return true
        }
    }

    @objc func dismissFullScreenImage(_ sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.3) {
            self.navigationController?.isNavigationBarHidden = false
            self.tabBarController?.tabBar.isHidden = false
            sender.view?.removeFromSuperview()
        }
    }

    // MARK: Presentation

    func createShareActionSheetController() -> ShareActionSheetController {
        let sb = UIStoryboard(name: "ShareActionSheetController", bundle: Bundle(for: Self.self))
        guard let shareActionSheetController = sb.instantiateInitialViewController() as? ShareActionSheetController else {
            fatalError("ShareActionSheetController is misconfigured")
        }
        return shareActionSheetController
    }

    func hideNoticeView(_ isHidden: Bool) {
        noticeView.isHidden = isHidden
        noticeViewHideConstraint?.isActive = isHidden
    }

    // MARK: Navigation

    func setupNavBar() {
        let dismissChatButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.down"),
            style: .plain,
            target: self,
            action: #selector(onDismissChat(_:))
        )

        let closeChatButton = UIBarButtonItem(
            title: SampleChat.localization.closeCapitalized,
            style: .plain,
            target: self,
            action: #selector(onEndChat(_:))
        )

        navigationItem.hidesBackButton = true
        navigationItem.setLeftBarButton(dismissChatButton, animated: false)
        navigationItem.setRightBarButton(closeChatButton, animated: false)
        navigationController?.navigationBar.setupAppearance(on: navigationItem)
        navigationItem.title = SampleChat.localization.chatCapitalized
    }

    @objc func onDismissChat(_ sender: AnyObject) {
        chat?.background = true
        NotificationCenter.default.post(name: SampleChat.Notifications.chatDidBecomeInactive, object: self)
        dismiss(animated: true)
    }

    @objc func onEndChat(_ sender: AnyObject) {
        accessoryView.textView.resignFirstResponder()
        if outOfScheduleMsg != nil {
            closeChat()
        } else {
            chat?.viewDelegate?.presentCloseChatAlert(message: SampleChat.localization.closeChatAlert,
                                                     fromViewController: self,
                                                     closeButtonAction: closeChat)
        }
    }

    func closeChat() {
        tableView.dataSource = nil // Avoids reloading tableView in case of any event incoming while closing.
        tableView.delegate = nil
        chat?.closeChat()
        SampleChat.shared = nil
        dismiss(animated: true)
        UserDefaults.standard.removeObject(forKey: ChatCredentialsManager.chatUserUidKey)
    }

    // MARK: Legal notice

    func setupLegalNotice() {
        legalTextLabel.attributedText = chat?.noticeDelegate?.noticeMessage()
        let gesture = UITapGestureRecognizer(target: self, action: #selector(presentLegalDocs))
        noticeView.addGestureRecognizer(gesture)
    }

    @objc func presentLegalDocs() {
        chat?.noticeDelegate?.presentNoticeAction(viewController: self)
    }

    // MARK: Messages view

    func showMessageNumbers(_ numberOfMessages: Int) {
        showMessagesView.numberOfMessages = numberOfMessages
        showMessagesView.isHidden = false
    }

    func resetMessagesView() {
        newMessagesCount = 0
        showMessagesView.numberOfMessages = newMessagesCount
        showMessagesView.isHidden = true
    }

    // MARK: Edge cases - Reconnection.

    /// Returns true if connection needs to be retried; returns false otherwise.
    func retryConnection() {
        guard let config = chat?.configuration else { return }

        let reconnectingString = SampleChat.localization.reconnectingString
        if shouldRetryConnection {
            // Retries were being done with authenticated credentials -> fallback to anonymous chat.
            connectionRetries += 1
            print("[CHAT] Attempt \(connectionRetries) out of \(maxRetries).")
            chat?.closeChat()
            SampleChat.shared = SampleChat(configuration: config)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeBetweenRetries) { [weak self] in // Give some time to recover connection.
                guard let self = self else { return }
                self.startChat()
                self.showConnectingView(text: reconnectingString)
            }
        } else { // TODO: Review
            // Reached max of retries.
            // Retries were being done with authenticated credentials -> we give it another try: fallback to anonymous chat.
            let oldUserConfig = config.userData
            let newUserConfig = ChatUserData(attachments: oldUserConfig.attachments,
                                             countryCode: oldUserConfig.countryCode,
                                             email: oldUserConfig.email,
                                             name: oldUserConfig.name,
                                             location: oldUserConfig.location,
                                             productSku: oldUserConfig.productSku,
                                             orderId: oldUserConfig.orderId,
                                             topic: oldUserConfig.topic,
                                             userJid: nil, // anoymous chat
                                             wsuid: nil, // anoymous chat
                                             contactMetadata: oldUserConfig.contactMetadata,
                                             preferredAgent: oldUserConfig.preferredAgent,
                                             displayAgentAvailability: oldUserConfig.displayAgentAvailability)
            let newConfig = ChatConfiguration(url: config.url,
                                              queueJid: config.queueJid,
                                              uploadDomain: config.uploadDomain,
                                              userData: newUserConfig,
                                              fileUploadMode: config.fileUploadMode)
            connectionRetries = 0 // restart retry cycle
            timeBetweenRetries = .zero // When fallbacking to anonymous, we want to try reconnecting inmediately.
            print("[CHAT] Fallback to anonymous auth activated.")
            chat?.closeChat()
            SampleChat.shared = SampleChat(configuration: newConfig)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeBetweenRetries) { [weak self] in // Give some time to recover connection.
                guard let self = self else { return }
                self.startChat()
                self.showConnectingView(text: reconnectingString)
            }
        }
//        } else {
//            // Reached max of retries, both with authenticated and anonymous credentials. Will not retry anymore.
//            print("[CHAT] Cannot establish chat connection.")
//        }
    }

    // MARK: Loading spinner

    func showLoadingSpinner() {
        activityIndicatorCell = UIActivityIndicatorView(style: .medium)
        activityIndicatorCell?.frame = CGRect(x: 0.0,
                                              y: 0.0,
                                              width: tableView.bounds.width,
                                              height: 40)
        activityIndicatorCell?.startAnimating()
        // since table if flipped, tableFooterView is actually at the top
        tableView.tableFooterView = activityIndicatorCell
    }

    func hideLoadingSpinner() {
        activityIndicatorCell?.stopAnimating()
        activityIndicatorCell = nil
        tableView.tableFooterView = nil
    }

    // MARK: Out of schedule

    func setupOutOfSchedule() {
        isInputEnabled = false
        hideNoticeView(true)
        SampleChat.shared = nil
        tableTopMarginConstraint?.constant = Spacer.size14
        tableView.delegate = nil
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }

    // MARK: Image actions

    func zoom(on image: UIImage) {
        // TODO: Implement
    }
}
