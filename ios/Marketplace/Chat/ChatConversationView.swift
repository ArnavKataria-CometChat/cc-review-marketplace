import SwiftUI
import UIKit
import CometChatUIKitSwift
import CometChatSDK

/// What a chat screen is anchored to.
enum ChatTarget: Equatable, Hashable, Identifiable {
    /// A 1:1 conversation with another app user (CometChat UID == app user id).
    case user(uid: String)
    /// A dispute group conversation (GUID `dispute-<inquiryId>`).
    case group(guid: String)

    /// Stable id so a tapped conversation can drive `navigationDestination(item:)`.
    var id: String {
        switch self {
        case .user(let uid): return "user:\(uid)"
        case .group(let guid): return "group:\(guid)"
        }
    }
}

/// SwiftUI wrapper that hosts a full CometChat conversation (header + message
/// list + composer) for a `ChatTarget`. Voice & video call buttons live on the
/// header; the UI Kit drives the outgoing/ongoing call UI from there.
///
/// This is presented by **pushing it on a `NavigationStack`** — never as a
/// `.sheet` / `.fullScreenCover`. A modal would occupy the key window's only
/// presentation slot, so the kit's incoming-call overlay would be silently
/// dropped and inbound calls would show as missed (gotcha I3).
struct ChatConversationView: UIViewControllerRepresentable {
    let target: ChatTarget

    func makeUIViewController(context: Context) -> MessagesViewController {
        MessagesViewController(target: target)
    }

    func updateUIViewController(_ vc: MessagesViewController, context: Context) {}
}

/// Composes the three CometChat message-surface views into one screen. Resolves
/// the `ChatTarget` to a concrete `User`/`Group`, then wires header + list +
/// composer to it.
final class MessagesViewController: UIViewController {

    private let target: ChatTarget

    private let header = CometChatMessageHeader()
    private let messageList = CometChatMessageList()
    private let composer = CometChatMessageComposer()
    private let loadingLabel = UILabel()

    // Resolved conversation subject, kept so a (re)connection can re-trigger the
    // history fetch. The message list fires its fetch ONCE when set; if the socket
    // wasn't fully connected yet (cold start / a reconnect mid-fetch) it can hang
    // on skeleton loaders forever. We re-apply the subject on connect to recover.
    private var resolvedUser: CometChatSDK.User?
    private var resolvedGroup: CometChatSDK.Group?
    private let connectionListenerID = "marketplace.messages.connection"

    init(target: ChatTarget) {
        self.target = target
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { CometChat.removeConnectionListener(connectionListenerID) }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // SwiftUI's NavigationStack supplies the back button; hide the kit's own.
        header.hideBackButton = true
        // The message header hides call buttons unless told otherwise on some kit
        // versions — make voice + video explicit so users can START a call.
        header.hideVoiceCallButton = false
        header.hideVideoCallButton = false

        loadingLabel.text = "Loading conversation…"
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center

        layout()

        // CRITICAL: set the message list's SUBJECT SYNCHRONOUSLY here, from the id
        // we already have — do NOT wait for an async getUser/getGroup. The kit's
        // message list fires its history fetch when it enters the window IF a
        // subject is set; if we only set it later (in the getUser callback) the
        // list already entered the window with no subject, never fetched, and
        // stayed on skeleton loaders forever ("chat not loading" even though the
        // socket is connected). A subject built from just the id is enough to
        // fetch + send; getUser/getGroup then only ENRICHES the header (name,
        // avatar). This mirrors the working telehealth setup.
        applyTargetSubject()
        enrichHeader()

        // Bonus recovery: if the socket (re)connects later, re-arm the fetch.
        CometChat.addConnectionListener(connectionListenerID, self)
    }

    // MARK: - Layout

    private func layout() {
        for subview in [header, messageList, composer, loadingLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            messageList.topAnchor.constraint(equalTo: header.bottomAnchor),
            messageList.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageList.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageList.bottomAnchor.constraint(equalTo: composer.topAnchor),

            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.bottomAnchor.constraint(equalTo: guide.bottomAnchor),

            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setChatViews(hidden: Bool) {
        header.isHidden = hidden
        messageList.isHidden = hidden
        composer.isHidden = hidden
        loadingLabel.isHidden = !hidden
    }

    // MARK: - Target resolution

    // Qualify with CometChatSDK — SwiftUI/the app export their own `User`/`Group`,
    // which would otherwise shadow the SDK types here.

    /// Set the message list/header/composer subject from the id we ALREADY have,
    /// synchronously, so the list has a subject before it enters the window and
    /// fires its fetch. A subject built from the id alone is enough to fetch+send.
    private func applyTargetSubject() {
        switch target {
        case .user(let uid):
            let user = CometChatSDK.User(uid: uid, name: uid)
            resolvedUser = user
            resolvedGroup = nil
            header.set(user: user)
            messageList.set(user: user)
            composer.set(user: user)
        case .group(let guid):
            // Minimal group from the guid; the real name/type arrive via
            // enrichHeader's getGroup. Enough for the list to fetch by guid.
            let group = CometChatSDK.Group(guid: guid, name: guid, groupType: .private, password: nil)
            resolvedGroup = group
            resolvedUser = nil
            header.set(group: group)
            messageList.set(group: group)
            composer.set(group: group)
        }
        messageList.set(controller: self)
        composer.set(controller: self)
        setChatViews(hidden: false)
    }

    /// Fetch the full User/Group to enrich the HEADER (real name, avatar, presence).
    /// The message list already fetched from the id-only subject, so this is
    /// display-only and its failure does not block the conversation.
    private func enrichHeader() {
        switch target {
        case .user(let uid):
            CometChat.getUser(UID: uid) { [weak self] user in
                guard let user else { return }
                DispatchQueue.main.async { self?.header.set(user: user) }
            } onError: { _ in }
        case .group(let guid):
            CometChat.getGroup(GUID: guid) { [weak self] group in
                DispatchQueue.main.async { self?.header.set(group: group) }
            } onError: { _ in }
        }
    }

    /// Re-arm the message list's fetch when the socket (re)connects — recovery for
    /// a fetch that raced an unready connection.
    private func refetchMessages() {
        if let user = resolvedUser {
            messageList.set(user: user)
        } else if let group = resolvedGroup {
            messageList.set(group: group)
        }
        messageList.reload()
    }
}

// Re-fetch history when the CometChat socket (re)connects — recovers a message
// list that mounted before the connection was live and stuck on skeletons.
// The protocol methods are @objc optional, so only `connected()` is needed.
extension MessagesViewController: CometChatConnectionDelegate {
    func connected() {
        DispatchQueue.main.async { [weak self] in self?.refetchMessages() }
    }
}
