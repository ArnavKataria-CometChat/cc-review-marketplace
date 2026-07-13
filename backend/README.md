# Marketplace Backend (Phase A)

REST API for a peer-to-peer marketplace: buyers and sellers trade items, support
handles disputes, and admins moderate. Built with **Go + Gin**.

> **Phase A baseline — no chat.** This service intentionally contains no chat,
> calling, or CometChat code. It provides the domain, real auth, and full RBAC so
> that a Phase B integration can map each user to a CometChat identity and anchor
> conversations to inquiries. The seams for that (inquiry threads, dispute
> flagging, admin content removal) are present and documented in code.

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
| `COMETCHAT_APP_ID` / `COMETCHAT_REGION` / `COMETCHAT_API_KEY` | _(empty)_ | Phase B placeholders — unused in Phase A |

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

## Phase B seams (not implemented here)

- **Inquiry** = anchor for a 1:1 buyer↔seller chat + voice call.
- **Report → flagged inquiry** = escalation into a buyer+seller+support **group**.
- `Inquiry.Flagged` toggles on report flag/resolve to model that transition.
- Admin listing removal is the hook for purging associated conversations.
- CometChat credentials already read from env; a backend-issued token would let
  the frontend authenticate.
