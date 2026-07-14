# Marketplace Backend

REST API for a peer-to-peer marketplace: buyers and sellers trade items, support
handles disputes, and admins moderate. Built with **Go + Gin**.

> **CometChat integrated.** Each app user maps to a CometChat user (RBAC role in
> `metadata.appRole`), the frontends bootstrap chat/calling with a per-user auth
> token minted here, and flagged disputes escalate to a buyer+seller+support
> CometChat group anchored to the inquiry. The fullAccess REST API Key is used
> **server-side only** — clients only ever receive App ID + Region + auth token.

## Architecture

```
backend/
├── main.go                     # entrypoint: config, store, server, graceful shutdown
├── Dockerfile                  # multi-stage build → distroless static image
├── verify.sh                   # build gate: go vet/test (if available) + docker build
├── internal/
│   ├── config/                 # env-based configuration (no hard-coded secrets)
│   ├── models/                 # domain entities + role/status enums
│   ├── auth/                   # bcrypt password hashing + JWT session tokens
│   ├── store/                  # Store interface + thread-safe in-memory impl + seed data
│   └── server/                 # gin router, auth/RBAC middleware, handlers
```

- **Auth:** email + password (bcrypt). Login returns a signed **JWT** carrying a
  stable `{userId, role}`. Every protected route validates the token and loads
  the user.
- **RBAC:** four roles — `buyer`, `seller`, `support`, `admin` — enforced by
  `requireRole` middleware and role-scoped query logic (e.g. buyers see only
  their own inquiries; support sees only flagged/disputed threads).
- **Storage:** in-memory behind a `Store` interface, so a real database can be
  dropped in without touching HTTP handlers. Demo data is seeded on startup.

## Roles

| Role      | Can do                                                                 |
|-----------|-----------------------------------------------------------------------|
| `buyer`   | Browse/search listings, save favorites, open inquiries, file reports  |
| `seller`  | Create/manage own listings, mark sold, see inquiries on their listings|
| `support` | View the dispute queue + flagged thread context, advance/resolve reports |
| `admin`   | Moderate users (ban/role), remove listings, view audit log            |

## API

Public:
- `POST /auth/login` — `{email, password}` → `{token, user}`
- `POST /auth/register` — self-service `buyer`/`seller` signup
- `GET  /listings?search=&category=&minPrice=&maxPrice=` — browse active listings (cents)
- `GET  /listings/:id`
- `GET  /health`

Authenticated (send `Authorization: Bearer <token>`):
- `GET    /users/me`
- `POST   /cometchat/token` — provision the caller's CometChat user (role in
  `metadata.appRole`) and mint a per-user auth token → `{appId, region, uid, authToken}`.
  Returns `503` when CometChat is not configured. This is the single bootstrap the
  web/Android/iOS clients call after login to bring up chat + calling.
- `POST   /listings` — **seller**
- `PATCH  /listings/:id` — owning seller (edit / mark sold) or admin
- `POST   /inquiries` — **buyer** (opens/returns the buyer↔seller thread for a listing)
- `GET    /inquiries` — role-scoped (buyer→own, seller→on their listings, support→flagged, admin→all)
- `PATCH  /inquiries/:id` — participant or admin (close/reopen)
- `POST   /favorites` · `GET /favorites` · `DELETE /favorites/:listingId` — **buyer**
- `POST   /reports` — any authenticated user

Support + admin:
- `GET   /reports?status=` — dispute queue
- `GET   /reports/:id` — report + listing + parties + inquiry context
- `PATCH /reports/:id` — advance status (`open`/`flagged`/`resolved`); flagging a
  thread-linked report escalates the inquiry to a dispute (Phase B → CometChat group)

Admin only:
- `GET    /admin/users`
- `PATCH  /admin/users/:id` — ban/unban or change role
- `DELETE /admin/listings/:id` — remove content
- `GET    /admin/audit` — audit log of privileged actions

## Configuration

Copy `.env.example` to `.env`. All config is env-based; no secrets are committed.

| Var | Default | Purpose |
|-----|---------|---------|
| `PORT` | `8080` | HTTP listen port |
| `JWT_SECRET` | `dev-only-insecure-secret-change-me` | JWT signing secret (set a strong value in prod) |
| `TOKEN_TTL` | `24h` | Session token lifetime |
| `SEED_DEMO_DATA` | `true` | Seed demo users/listings on startup |
| `COMETCHAT_APP_ID` | _(empty)_ | CometChat App ID (non-secret; sent to clients) |
| `COMETCHAT_REGION` | _(empty)_ | CometChat region: `us`/`eu`/`in` (non-secret) |
| `COMETCHAT_REST_API_KEY` | _(empty)_ | **fullAccess** REST key — server-only; provisions users, mints tokens, manages dispute groups. Never ship to a client. |
| `COMETCHAT_AUTH_KEY` | _(empty)_ | dev-only Auth Key — read for parity but **not used** (the token flow supersedes it) |

Leaving any CometChat var empty runs the API with chat **disabled**: `/cometchat/token`
returns `503` and dispute escalation is skipped — every other route is unchanged.

### Seeded demo accounts

When `SEED_DEMO_DATA=true`, one account per role is created, all with password
**`Password123!`** (demo only — documented, not a real credential):

- `buyer@example.com` · `seller@example.com` · `support@example.com` · `admin@example.com`

## Run locally

With Go (1.23+):

```bash
cp .env.example .env
go run .
# → listening on :8080
```

With Docker:

```bash
docker build -t marketplace-backend .
docker run --rm -p 8080:8080 marketplace-backend
```

Quick check:

```bash
curl localhost:8080/health
TOKEN=$(curl -s -X POST localhost:8080/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@example.com","password":"Password123!"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl localhost:8080/admin/users -H "Authorization: Bearer $TOKEN"
```

## Verify / build

```bash
./verify.sh        # go vet + tests (if go installed) then `docker build`; non-zero on failure
```

## CometChat integration

Server-side only, via the CometChat REST (Chat) API — see `internal/cometchat`.

- **User mapping.** CometChat `uid` = app user id; display name = user name; the
  app RBAC role is stored in `metadata.appRole` (the top-level `role` is left
  unset — it must map to a role predefined in the dashboard, whereas metadata is
  free-form). Provisioning is **just-in-time**: `POST /cometchat/token` creates
  (or updates) the user, then mints a fresh auth token.
- **1:1 (Inquiry).** An inquiry is the buyer↔seller anchor; both clients open the
  same 1:1 conversation/call keyed on the two UIDs. Only the listing's buyer and
  seller are participants (enforced by the existing inquiry RBAC).
- **Dispute group.** Flagging a thread-linked report (`PATCH /reports/:id`
  `status=flagged`) creates a **private** CometChat group `dispute-<inquiryId>`
  with the buyer + seller (participants) and support (admin/owner). Resolving the
  report deletes the group. Creation is idempotent (re-flagging is a no-op).
- **Admin moderation.** Removing a listing (`DELETE /admin/listings/:id`) purges
  the dispute groups of that listing's flagged inquiries.
- **Failure isolation.** All CometChat side effects except the token endpoint are
  best-effort: if CometChat is unreachable the report/listing workflow still
  succeeds and the error is logged.

The credentials flow: the backend holds the fullAccess REST key; clients receive
only App ID + Region + a per-user auth token from `POST /cometchat/token`.
