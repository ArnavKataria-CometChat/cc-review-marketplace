# Marketplace — baseline app

A local buy‑&‑sell **marketplace** (listings, inquiries, favorites, disputes, admin moderation), built as a **baseline** for the CometChat skills/docs review. This `main` branch is the app **before** any CometChat integration — the comparison base for `feature/cometchat-integration`.

## Roles
`buyer` · `seller` · `support` · `admin` — each role sees only its own surfaces (UI RBAC mirrors backend route guards). Seeded with demo users, listings, inquiries, and flagged disputes.

## Stack
| Platform | Tech |
|---|---|
| Web | React + Vite + React Router |
| Android | Kotlin |
| iOS | Swift / SwiftUI |
| Backend | Go (gin) |

## Branches
- **`main`** — baseline (this branch): marketplace only, no chat/calling.
- **`feature/cometchat-integration`** — adds CometChat chat + voice/video calling (1:1 buyer↔seller, group support disputes).

## About this review
This repo is part of an automated **CometChat skills review**: an agent integrates CometChat into the baseline using CometChat's published skills/docs, and the review records every skill/docs/SDK gap that surfaced.
Findings deliverable → **ArnavKataria-CometChat/cc-review-reports** (`marketplace/`).
