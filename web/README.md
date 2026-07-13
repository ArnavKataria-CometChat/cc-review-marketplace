# Marketplace — Web Client (Phase A)

React + TypeScript storefront for the peer-to-peer marketplace. This is the
**web** component of a multi-client product (web · Android · iOS) that shares one
Go/Gin backend (`../backend`).

**Phase A** is a clean, production-shaped baseline with **full RBAC** and no chat.
The chat/calling touchpoints (1:1 chat + voice call on an inquiry, and the
buyer+seller+support dispute group) are intentionally left as seams for Phase B's
CometChat integration — nothing chat-related is installed or referenced here.

## Stack

- **React 18 + TypeScript**, bundled with **Vite**
- **React Router 6** for routing, with role-guarded routes
- Plain `fetch` API client (no data-fetching library) against the backend REST API
- Session token (JWT) issued by the backend, stored in `localStorage`
- Served in production as static assets behind **nginx** (see `Dockerfile`)

## Roles & screens (RBAC)

Every route is guarded on the client (`<ProtectedRoute>`) **and** independently by
the backend. The four roles map to these screens:

| Role      | Screens                                                                    |
| --------- | -------------------------------------------------------------------------- |
| _(public)_ | Browse & search listings, listing detail, login/register                  |
| **buyer** | Browse → detail → **Contact seller** (opens an inquiry), My Inquiries, Favorites |
| **seller**| Create/Edit listing, My Listings, **Inquiries Inbox**, Mark sold           |
| **support**| Dispute queue, Report detail (listing + parties + thread context)         |
| **admin** | User moderation (ban/role), Listing moderation (remove), Audit log         |

The primary buyer flow — **browse → listing detail → contact seller → my
inquiries** — is fully implemented, so wiring a chat thread onto an inquiry in
Phase B is a small, well-defined addition.

## Project layout

```
web/
├── Dockerfile            # multi-stage: node build -> nginx static serve
├── nginx.conf            # SPA fallback routing
├── verify.sh             # build gate: npm build (if present) + docker build
├── .env.example          # documented, build-time config (no secrets)
└── src/
    ├── api/              # REST client + typed endpoints + domain types
    ├── auth/             # AuthContext (login/register/logout, session restore)
    ├── components/       # NavBar, ProtectedRoute, cards, dialogs, UI atoms
    └── pages/            # one folder per role (buyer/seller/support/admin)
```

## Backend REST contract (expected)

The client talks to `../backend` (Go/Gin). Base URL is configured via
`VITE_API_BASE_URL` (see **Configuration**). Auth is a `Bearer <token>` header;
errors come back as `{ "error": "message" }`.

| Method & path                        | Role            | Used by                        |
| ------------------------------------ | --------------- | ------------------------------ |
| `POST /auth/login`                   | public          | Login                          |
| `POST /auth/register`                | public (buyer/seller) | Register                 |
| `GET /users/me`                      | authed          | Session restore                |
| `GET /listings?search&category&minPrice&maxPrice` | public | Browse (active listings) |
| `GET /listings/:id`                  | public          | Listing detail                 |
| `POST /listings`                     | seller          | Create listing                 |
| `PATCH /listings/:id`                | owner / admin   | Edit, mark sold                |
| `POST /inquiries`                    | buyer           | Contact seller                 |
| `GET /inquiries`                     | authed (role-scoped) | My inquiries / inbox / disputes |
| `PATCH /inquiries/:id`               | participant / admin | Close/reopen thread        |
| `POST /favorites`                    | buyer           | Save listing                   |
| `GET /favorites`                     | buyer           | Favorites page                 |
| `DELETE /favorites/:listingId`       | buyer           | Unsave listing                 |
| `POST /reports`                      | authed          | Report / open dispute          |
| `GET /reports?status`                | support / admin | Dispute queue                  |
| `GET /reports/:id`                   | support / admin | Report detail (with context)   |
| `PATCH /reports/:id`                 | support / admin | Flag / resolve                 |
| `GET /admin/users`                   | admin           | User moderation                |
| `PATCH /admin/users/:id`             | admin           | Ban / change role              |
| `DELETE /admin/listings/:id`         | admin           | Remove listing                 |
| `GET /admin/audit`                   | admin           | Audit log                      |

> **Baseline note:** the public `GET /listings` returns **active** listings only
> and has no seller filter, so the seller "My Listings" and admin "Listing
> moderation" views scope the active feed client-side. Sold/removed listings drop
> off that feed but remain reachable by direct link (`/listings/:id`).

## Configuration

All config is build-time and comes from env vars — no secrets are hard-coded.
Copy `.env.example` to `.env` and adjust:

| Variable            | Default (dev)                    | Purpose                              |
| ------------------- | -------------------------------- | ------------------------------------ |
| `VITE_API_BASE_URL` | unset → `/api` (dev proxy)       | Base URL of the backend REST API     |

- **Dev:** leave `VITE_API_BASE_URL` unset. `vite.config.ts` proxies `/api` →
  `http://localhost:8080`, so no CORS setup is needed.
- **Docker/prod:** the app calls `VITE_API_BASE_URL` directly. Pass it at build
  time (see below). CometChat credentials are **not** part of this component — in
  Phase B the frontend will authenticate with a backend-issued token.

## Run locally

Prerequisites: Node 20+, and the backend running on `:8080` (see `../backend`).

```bash
# 1. Start the backend (separate terminal), from ../backend:
#    go run .        # seeds demo data, listens on :8080

# 2. Start the web dev server:
npm install
npm run dev          # http://localhost:5173  (proxies /api -> :8080)
```

### Demo accounts

The backend seeds one account per role (when `SEED_DEMO_DATA=true`, the default).
Password for all: **`Password123!`**

| Role    | Email                 |
| ------- | --------------------- |
| buyer   | `buyer@example.com`   |
| seller  | `seller@example.com`  |
| support | `support@example.com` |
| admin   | `admin@example.com`   |

The login screen has one-click "Use" buttons to fill these in.

## Build & verify

```bash
# Type-check + production build
npm run build            # runs `tsc --noEmit && vite build` -> dist/

# Full component gate (type-check/build if npm present, then docker build)
./verify.sh
```

### Docker

```bash
# Build the image (bakes in the API base URL)
docker build -t marketplace-web \
  --build-arg VITE_API_BASE_URL=http://localhost:8080 .

# Serve the static bundle on http://localhost:8081
docker run --rm -p 8081:8080 marketplace-web
```

The image is a two-stage build: `node:20-alpine` compiles the app (a type error
fails the build), then `nginx:1.27-alpine` serves the static output with SPA
fallback routing.
