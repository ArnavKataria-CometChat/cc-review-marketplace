# Marketplace — CometChat integration

The [baseline marketplace](../../tree/main) with **CometChat** chat + voice/video calling integrated across **web (React UIKit v6)**, **Android (Kotlin UIKit v6)**, and **iOS (UIKitSwift)** — the integration under review for CometChat's skills/docs.

## What CometChat adds
- **Chat tab** on all three platforms: Conversations list → open any conversation.
- **1:1 chat + voice + video** between buyer and seller.
- **Group chat + voice + video** for support dispute groups.
- Backend-minted **per-user auth tokens** (`POST /cometchat/token` returns appId/region/uid/authToken); the CometChat REST key never touches the client.

## Stack
| Platform | Tech |
|---|---|
| Web | React + Vite + `@cometchat/chat-uikit-react` v6 |
| Android | Kotlin + `chatuikit-kotlin` v6 |
| iOS | Swift + `CometChatUIKitSwift` |
| Backend | Go (gin) — token minting |

## Compare
- **vs baseline (`main`):** see PR **#1** for the full integration diff.

## Review outcome
**22 findings** (skills 15 · agent 6 · docs-mcp 1) · build 1/4 · completeness 82.5% · ease 2.0/5 · 0 hallucinations.
Full deliverable → **ArnavKataria-CometChat/cc-review-reports** (`marketplace/report.md`).
