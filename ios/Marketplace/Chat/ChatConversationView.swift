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
        resolveTarget()

        // If the CometChat socket (re)connects after the message list mounted,
        // re-apply the subject so a hung/empty initial fetch is retried — the fix
        // for the "chat opens but stays on skeleton loaders" cold-start case.
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

    private func resolveTarget() {
        setChatViews(hidden: true)
        switch target {
        case .user(let uid):
            CometChat.getUser(UID: uid) { [weak self] user in
                DispatchQueue.main.async { self?.configure(user: user) }
            } onError: { [weak self] error in
                DispatchQueue.main.async { self?.showError(error) }
            }
        case .group(let guid):
            CometChat.getGroup(GUID: guid) { [weak self] group in
                DispatchQueue.main.async { self?.configure(group: group) }
            } onError: { [weak self] error in
                DispatchQueue.main.async { self?.showError(error) }
            }
        }
    }

    // Qualify with CometChatSDK — the app has its own `Marketplace.User` model,
    // which would otherwise shadow the SDK's `User` here.
    private func configure(user: CometChatSDK.User?) {
        guard let user else { showError(nil); return }
        resolvedUser = user
        resolvedGroup = nil
        header.set(user: user)
        messageList.set(user: user)
        messageList.set(controller: self)
        composer.set(user: user)
        composer.set(controller: self)
        setChatViews(hidden: false)
        scheduleRefetch()
    }

    // Qualify with CometChatSDK — this file imports SwiftUI, which also exports a
    // `Group` type, so a bare `Group` is ambiguous for type lookup.
    private func configure(group: CometChatSDK.Group?) {
        guard let group else { showError(nil); return }
        resolvedGroup = group
        resolvedUser = nil
        header.set(group: group)
        messageList.set(group: group)
        messageList.set(controller: self)
        composer.set(group: group)
        composer.set(controller: self)
        setChatViews(hidden: false)
        scheduleRefetch()
    }

    /// Re-arm the message list's history fetch. The list fires its fetch once when
    /// its subject is set; if the socket wasn't ready then, it hangs on skeleton
    /// loaders forever. Re-set the subject AND call reload() to force a fresh
    /// fetch. Called (a) shortly after first configure (belt-and-suspenders for a
    /// cold-start fetch that never fired) and (b) whenever the socket connects.
    private func refetchMessages() {
        if let user = resolvedUser {
            messageList.set(user: user)
        } else if let group = resolvedGroup {
            messageList.set(group: group)
        }
        messageList.reload()
    }

    private func scheduleRefetch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.refetchMessages()
        }
    }

    private func showError(_ error: CometChatException?) {
        loadingLabel.text = error?.errorDescription ?? "This conversation is unavailable."
        setChatViews(hidden: true)
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
