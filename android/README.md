# Marketplace — Android client (Phase B: CometChat)

Native **Kotlin + Android Views** (not Compose) client for the peer-to-peer
marketplace. Buyers browse listings and open inquiries with sellers, sellers
manage listings and inboxes, support works a dispute queue, and admins moderate
users/listings with an audit trail. Full role-based access control (RBAC) with a
real backend-issued session.

> **Phase A baseline — no chat.** This app intentionally contains no chat,
> calling, or CometChat code. The seams a Phase B CometChat integration will use
> are present and labelled in the UI (the inquiry thread carries disabled
> *Message*/*Call* buttons; a flagged dispute is described as becoming a
> buyer+seller+support group). See **Phase B seams** below.

## Stack

- **Language:** Kotlin, **UI:** Android Views + Material 3 + ViewBinding (no Compose)
- **Networking:** Retrofit + Gson + OkHttp (logging interceptor)
- **Async:** Kotlin coroutines (`lifecycleScope`)
- **Auth:** backend-issued JWT held in `SessionManager` (app-private prefs), replayed by an `AuthInterceptor`
- **Toolchain:** Android Gradle Plugin 8.11.1, Kotlin 2.2.0, Gradle 8.14.3, JDK 17
- **SDK:** `compileSdk`/`targetSdk` 36, `minSdk` 24

## Architecture

```
android/
├── app/
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/cometchat/marketplace/
│       │   ├── MarketplaceApp.kt          # Application; owns the repository singleton
│       │   ├── data/
│       │   │   ├── model/Models.kt         # domain entities mirroring backend JSON
│       │   │   ├── remote/
│       │   │   │   ├── ApiService.kt       # Retrofit description of every route
│       │   │   │   ├── Dtos.kt             # request/response DTOs
│       │   │   │   └── ApiClient.kt        # OkHttp/Retrofit builder + AuthInterceptor
│       │   │   ├── SessionManager.kt       # token + user persistence, role accessor
│       │   │   ├── MarketplaceRepository.kt# one suspend method per use case → Outcome<T>
│       │   │   └── Outcome.kt              # success/error wrapper (no exceptions in UI)
│       │   ├── util/Format.kt              # price/format helpers
│       │   └── ui/
│       │       ├── SplashActivity.kt       # routes to Login or Main (validates token)
│       │       ├── auth/LoginActivity.kt   # login + self-service register (buyer/seller)
│       │       ├── main/MainActivity.kt    # role-based bottom nav + fragment host
│       │       ├── listings/               # Browse, MyListings, Detail, Create/Edit
│       │       ├── favorites/              # buyer saved listings
│       │       ├── inquiries/              # role-scoped inbox + thread detail
│       │       ├── reports/                # support/admin dispute queue + detail
│       │       ├── admin/                  # users, moderation, audit
│       │       ├── profile/                # current user + logout
│       │       └── common/                 # RecyclerView adapters + BaseListFragment
│       └── res/                            # layouts, per-role menus, drawables, theme
├── build.gradle.kts / settings.gradle.kts / gradle.properties
├── verify.sh                               # build gate: ./gradlew :app:assembleDebug
└── README.md
```

**Data flow:** `Activity/Fragment → MarketplaceRepository → Retrofit ApiService →
backend`. The repository returns `Outcome.Success/Error`, so the UI renders a
friendly message on failure and never touches Retrofit types. `SessionManager`
holds the JWT; `AuthInterceptor` attaches it to every request.

## RBAC (client side)

RBAC is enforced **server-side** on every route (a tampered client cannot exceed
its role). The client mirrors it for UX: `MainActivity` chooses the bottom-nav
menu and reachable fragments from the authenticated role, and detail screens
show only the actions that role is allowed to perform.

| Role      | Tabs                                   | Key actions |
|-----------|----------------------------------------|-------------|
| `buyer`   | Browse · Saved · Inquiries · Profile   | search, save favorites, contact seller (open inquiry), report, dispute |
| `seller`  | Listings · Inquiries · Profile         | create/edit listing, mark sold, view inquiries on own listings |
| `support` | Disputes · Profile                     | work the report queue, view flagged-thread context, flag/resolve |
| `admin`   | Users · Moderation · Disputes · Audit · Profile | ban/role users, remove listings, resolve reports, read audit log |

## Backend REST contract (expected)

Base URL is configurable (below); the client targets **`../backend`** (Go/Gin,
listens on `:8080`). Routes consumed:

| Method & path | Used by | Notes |
|---------------|---------|-------|
| `POST /auth/login` | Login | `{email,password}` → `{token,user}` |
| `POST /auth/register` | Register | buyer/seller only → `{token,user}` |
| `GET /users/me` | Splash | validates the stored token |
| `POST /cometchat/token` | Chat bootstrap | authed; JIT-provisions the caller's CometChat user and returns `{appId, region, uid, authToken}` — the client logs into the CometChat SDK with this. The REST key stays server-side. |
| `GET /listings?search=&category=&minPrice=&maxPrice=` | Browse, MyListings, Moderation | active listings |
| `GET /listings/:id` | Detail, Create(edit) | |
| `POST /listings` | Create | seller |
| `PATCH /listings/:id` | Edit / Mark sold | owning seller or admin |
| `POST /inquiries` | Contact seller | buyer; `{listingId,message}` |
| `GET /inquiries` | Inquiries, InquiryDetail | role-scoped by the backend |
| `PATCH /inquiries/:id` | InquiryDetail | close/reopen |
| `POST /favorites` · `GET /favorites` · `DELETE /favorites/:listingId` | Favorites, Detail | buyer |
| `POST /reports` | Report / Dispute | any authed user; optional `inquiryId` links a thread |
| `GET /reports?status=` · `GET /reports/:id` · `PATCH /reports/:id` | Dispute queue/detail | support + admin |
| `GET /admin/users` · `PATCH /admin/users/:id` | Admin users | ban/unban, change role |
| `DELETE /admin/listings/:id` | Moderation | remove listing |
| `GET /admin/audit` | Audit | privileged-action log |

Errors are read from the backend's `{"error":"..."}` envelope and surfaced as
toasts.

## Configuration

No secrets are committed. `local.properties` (git-ignored) only holds the SDK
path. The API base URL is a `BuildConfig` field with a sensible default and two
overrides:

| Setting | Default | Override |
|---------|---------|----------|
| `API_BASE_URL` | `http://10.0.2.2:8080/` (emulator → host loopback) | Gradle prop `-PmarketplaceApiBaseUrl=…` **or** env `MARKETPLACE_API_BASE_URL` |

- `10.0.2.2` is the Android **emulator**'s alias for the host machine. On a
  physical device, override with your machine's LAN IP, e.g.
  `-PmarketplaceApiBaseUrl=http://192.168.1.20:8080/`.
- Cleartext HTTP is enabled (`usesCleartextTraffic`) for local development only.

## Build & run

Prerequisites: `ANDROID_HOME` set (SDK platform 36, build-tools), JDK 17.

```bash
# 1) Start the backend (separate terminal, from ../backend)
cd ../backend && cp -n .env.example .env && go run .      # → :8080

# 2) Build the Android debug APK (the verify gate)
./verify.sh
#   or directly:
./gradlew :app:assembleDebug        # → app/build/outputs/apk/debug/app-debug.apk

# 3) Run on an emulator (host loopback default) or a device
./gradlew installDebug              # requires a running emulator/device
```

### Demo accounts

The backend seeds one account per role (password **`Password123!`**):
`buyer@example.com`, `seller@example.com`, `support@example.com`,
`admin@example.com`. Log in with any of them to see the role-specific UI, or use
*Create account* to register a new buyer/seller.

### Verify

```bash
./verify.sh        # runs ./gradlew :app:assembleDebug; exits non-zero on failure
```

## CometChat integration (Phase B)

Chat + voice/video calling via the **CometChat Android UI Kit v6** (Kotlin Views,
`chatuikit-kotlin-android:6.x` + `calls-sdk-android:5.x`).

- **Credential-free client.** No CometChat keys live in the app. After login the
  client calls `POST /cometchat/token`; `ChatManager` inits the SDK with the
  returned App ID + Region and logs in with the per-user auth token
  (`loginWithAuthToken`). The CometChat REST key never leaves the backend.
- **RBAC / conversation scoping.** The CometChat UID equals the app `userId`;
  the backend stores the app role on the CometChat user. `InquiryDetailActivity`
  only lets a thread's **buyer and seller** open the 1:1 conversation, and only
  with each other (the counterpart UID is derived from the inquiry).
- **1:1 (inquiry).** *Message*/*Call* open `ChatActivity` for the counterpart;
  the message header hosts the voice + video call buttons.
- **Dispute group.** When a report is flagged the backend provisions a
  `dispute-<inquiryId>` group (buyer + seller + support). `ReportDetailActivity`
  lets support open it (group chat + group call).
- **Calling lifecycle.** The Calls SDK is initialized explicitly after chat init;
  an incoming-call overlay is hosted on the chat surface, and `ChatManager`
  re-foregrounds the app / tears down the kit's own-task ongoing-call activity on
  local and remote call-end.

The three `com.cometchat.calls.*` Java files under `app/src/main/java` are
intentional no-op **stubs** for legacy classes the Chat SDK's `CallManager`
references but `calls-sdk-android:5.x` dropped — see their header comment.

Local dev over plain HTTP is permitted only for the emulator/localhost hosts via
`res/xml/network_security_config.xml` (the merged CometChat SDK config otherwise
disables cleartext to our own backend).
```
