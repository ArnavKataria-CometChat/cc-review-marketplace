# Marketplace — iOS Client (Phase A)

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

**2. Run the app** — open `Marketplace.xcodeproj` in Xcode, pick an iOS
Simulator, and press **Run** (⌘R). The iOS Simulator reaches the Mac's
`localhost`, so the default base URL works out of the box.

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

`verify.sh` is the CI build gate. It runs a **simulator build with code-signing
disabled** and exits non-zero on any failure:

```bash
xcodebuild -project Marketplace.xcodeproj -scheme Marketplace \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO clean build
```

## Phase B seams (not implemented here)

- **Inquiry detail** (`Features/Inquiries/InquiryDetailView.swift`) is where the
  1:1 buyer↔seller CometChat chat and voice-call button attach, keyed on the
  inquiry.
- **Report detail** (`Features/Reports/ReportDetailView.swift`) is where a
  flagged, thread-linked report becomes a buyer+seller+support **group** that
  support mediates in.
- **Admin listing removal** is the hook for purging conversations tied to a
  removed listing.
- The signed-in `User.id` + `role` are the stable identity a CometChat user is
  synced from; the app already authenticates with a backend-issued token, which
  Phase B would extend to also mint a CometChat auth token.
