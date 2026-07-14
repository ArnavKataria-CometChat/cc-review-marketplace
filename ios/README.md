# Marketplace — iOS Client (Phase A + CometChat)

Native **SwiftUI** app for the peer-to-peer marketplace: buyers browse and
inquire, sellers list and manage items, support triages disputes, and admins
moderate. It talks to the Go/Gin backend in [`../backend`](../backend).

> **Phase A baseline — no chat.** This app intentionally contains no chat,
> calling, or CometChat code. It implements the full domain and real
> role-based access control so a Phase B integration can map each signed-in user
> (stable server `id` + `role`) to a CometChat identity and anchor conversations
> to **inquiries**. The seams for that (the inquiry thread screen, dispute
> escalation, admin content removal) are present and marked in code with
> `Phase B seam` comments.

## Requirements

- **Xcode 16+** (developed against Xcode 26 / iOS 18+ SDK).
- iOS **17.0+** deployment target.
- No third-party dependencies, no CocoaPods, no Swift packages — just SwiftUI +
  `URLSession`.

## Architecture

```
ios/
├── Marketplace.xcodeproj          # hand-authored; uses a file-system-synchronized
│                                  # group, so new files under Marketplace/ are
│                                  # picked up automatically (no pbxproj edits)
├── Marketplace/
│   ├── App/                       # @main entry + role-based root router
│   │   ├── MarketplaceApp.swift
│   │   └── RootView.swift         # login vs. role-scoped TabView
│   ├── Session/
│   │   └── SessionStore.swift     # auth state, token persistence, current user
│   ├── Networking/
│   │   ├── APIClient.swift        # async/await client for every endpoint
│   │   ├── APIError.swift         # typed, user-facing errors
│   │   └── JSONCoding.swift       # lenient RFC3339(nano) date decoding
│   ├── Models/
│   │   └── Models.swift           # Codable entities mirroring the backend
│   ├── Support/
│   │   ├── AppConfig.swift        # env/UserDefaults/Info.plist base URL
│   │   ├── Formatters.swift       # price + date formatting
│   │   └── UIComponents.swift     # badges, loadable state, empty/error views
│   ├── Features/
│   │   ├── Auth/                  # login + self-service register
│   │   ├── Listings/              # browse, detail, create, seller manage
│   │   ├── Inquiries/             # buyer↔seller thread list + detail
│   │   ├── Favorites/             # buyer saved listings
│   │   ├── Reports/               # file report + support dispute queue/detail
│   │   ├── Admin/                 # users, listings moderation, audit log
│   │   └── Account/              # profile + sign out
│   ├── Assets.xcassets
│   └── Info.plist                 # ATS localhost exception + APIBaseURL
├── verify.sh                      # simulator build gate (no code-signing)
└── README.md
```

- **State:** a single `SessionStore` (`ObservableObject`) owns the token and the
  current `User`, injected via the environment. Each screen drives its own
  `Loadable` state machine (idle / loading / loaded / error-with-retry).
- **Networking:** one `APIClient` with an `async` method per endpoint; it injects
  the `Bearer` token, decodes into the `Codable` models, and maps non-2xx
  responses (with the server's `{"error": …}` message) into typed `APIError`s. A
  401 triggers an automatic sign-out.
- **No secrets in the app.** The backend base URL is resolved from the
  `API_BASE_URL` env var → `apiBaseURL` UserDefault → the `APIBaseURL` Info.plist
  key → `http://localhost:8080`. The Sign-In screen has a "Backend server" field
  to override it at runtime (handy for a device pointing at a LAN host).

### Role-based access control (mirrors the backend)

Auth is real: email + password → the backend issues a JWT carrying a stable
`{userId, role}`, which the app stores and sends on every request. The UI only
ever exposes the surfaces a role is allowed to reach — the client mirror of the
backend's `requireRole` guards:

| Role      | Tabs / screens                                                        |
|-----------|-----------------------------------------------------------------------|
| `buyer`   | Browse & search · Favorites · My Inquiries · (report / open dispute)  |
| `seller`  | My Listings (+ create, mark sold) · Inbox (inquiries) · Browse        |
| `support` | Dispute queue (flagged) · Report detail with full thread context      |
| `admin`   | Users (ban / role) · Listings (remove) · Disputes · Audit log         |

The backend remains the source of truth — protected calls are still authorized
server-side, so the UI gating is defense-in-depth, not the only guard.

## REST contract this client expects

Base URL from config (default `http://localhost:8080`). `Authorization: Bearer
<token>` on authenticated calls. All timestamps are RFC 3339 (the client parses
variable fractional-second precision). Prices are integer **cents**.

| Method & path | Role | Used by |
|---|---|---|
| `POST /auth/login` `{email,password}` → `{token,user}` | public | Sign in |
| `POST /auth/register` `{name,email,password,role}` → `{token,user}` | public | Register (buyer/seller) |
| `GET /users/me` → `User` | any | Session restore, Account |
| `POST /cometchat/token` → `{appId,region,uid,authToken}` | any | Bring up CometChat chat/calling |
| `GET /listings?search=&category=&minPrice=&maxPrice=` → `{listings}` | public | Browse |
| `GET /listings/:id` → `Listing` | public | Listing detail |
| `POST /listings` `{title,description,priceCents,category,photos}` → `Listing` | seller | Create listing |
| `PATCH /listings/:id` `{…, status}` → `Listing` | owner/admin | Mark sold / relist |
| `POST /inquiries` `{listingId,message}` → `Inquiry` | buyer | Contact seller |
| `GET /inquiries` → `{inquiries}` (role-scoped) | any | Inquiries / Inbox |
| `PATCH /inquiries/:id` `{status}` → `Inquiry` | participant/admin | Close / reopen |
| `POST /favorites` `{listingId}` | buyer | Save listing |
| `GET /favorites` → `{favorites:[{…,listing}]}` | buyer | Favorites |
| `DELETE /favorites/:listingId` | buyer | Unsave |
| `POST /reports` `{targetType,targetId,reason,inquiryId?}` → `Report` | any | Report / open dispute |
| `GET /reports?status=` → `{reports}` | support/admin | Dispute queue |
| `GET /reports/:id` → `{report,reporter,listing,inquiry,buyer,seller}` | support/admin | Report detail |
| `PATCH /reports/:id` `{status}` → `Report` | support/admin | Advance status |
| `GET /admin/users` → `{users}` | admin | Users |
| `PATCH /admin/users/:id` `{banned?,role?}` → `User` | admin | Ban / role |
| `DELETE /admin/listings/:id` → `Listing` | admin | Remove listing |
| `GET /admin/audit` → `{audit}` | admin | Audit log |

The `Codable` model shapes live in `Marketplace/Models/Models.swift`; unknown
enum values decode to `.unknown` so a new server-side status never crashes the
app.

## Run it

**1. Start the backend** (see `../backend/README.md`):

```bash
cd ../backend
cp .env.example .env
go run .          # → listening on :8080, seeds demo data
```

**2. Install pods** (chat + calling SDKs — `Pods/` is gitignored):

```bash
pod install
```

**3. Run the app** — open **`Marketplace.xcworkspace`** (not the `.xcodeproj` —
CocoaPods rewires the workspace) in Xcode, pick an iOS Simulator, and press
**Run** (⌘R). The iOS Simulator reaches the Mac's `localhost`, so the default
base URL works out of the box.

Sign in with a seeded demo account (all use password **`Password123!`**), or tap
one on the Sign-In screen:

- `buyer@example.com` · `seller@example.com` · `support@example.com` · `admin@example.com`

> Running on a **physical device**? The device can't see the Mac's `localhost`.
> Set the backend URL to your Mac's LAN address via the Sign-In screen's
> "Backend server" field (e.g. `http://192.168.1.20:8080`), or pass
> `API_BASE_URL` in the scheme's environment.

## Build / verify

```bash
./verify.sh
```

`verify.sh` is the CI build gate. It `pod install`s if needed, then runs a
**simulator build with code-signing disabled** against the workspace and exits
non-zero on any failure:

```bash
xcodebuild -workspace Marketplace.xcworkspace -scheme Marketplace \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO clean build
```

## Phase B — CometChat chat + calling

Integrated with the **CometChat iOS UI Kit v5** (`CometChatUIKitSwift ~> 5.1`)
and **Calls SDK 5** (`CometChatCallsSDK ~> 5.0`) via CocoaPods. Chat code lives
in `Marketplace/Chat/`.

- **No secrets in the app.** The client holds no App ID / Region / keys. On sign
  in, `ChatService` calls `POST /cometchat/token`, and the backend returns the
  App ID + Region + a short-lived per-user auth token. `ChatService` then inits
  the SDKs and logs in with `CometChatUIKit.login(authToken:)`. The REST API Key
  stays server-side.
- **1:1 chat + voice/video call** — `InquiryDetailView` pushes a conversation
  with the other party (`ChatTarget.user(uid:)`, peer = the inquiry's other
  buyer/seller; CometChat UID == app user id). Call buttons are on the chat
  header. Gated to the two participants.
- **Dispute group** — once a report is flagged, the backend provisions a
  buyer+seller+support group (GUID `dispute-<inquiryId>`). `ReportDetailView`
  pushes `ChatTarget.group(guid:)` into it for group chat + group calling;
  support mediates.
- **Calling glue** — `ChatService` inits `CometChatCalls` right after the chat
  init, enables the kit's in-app incoming-call overlay, and registers a listener
  that dismisses the ongoing-call screen + clears the active call when a 1:1 call
  ends remotely (the kit otherwise leaves a ghost call running).
- **Native quirks handled** (see `Podfile` / `CometChatStubs/`): the arm64
  simulator arch exclusion is cleared on all targets; a compile-time stub
  resolves the never-shipped `CometChatCardsSwift` module; and the real
  `CometChatStarscream` framework (an undeclared runtime dependency of
  CometChatSDK) is pulled explicitly so the app doesn't crash at launch.
