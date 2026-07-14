// Domain types mirroring the Go backend's `internal/models` package. Keeping
// these in sync with the server is what makes the REST contract type-safe.

export type Role = "buyer" | "seller" | "support" | "admin";

export type ListingStatus = "active" | "sold" | "removed";
export type InquiryStatus = "open" | "closed";
export type ReportTargetType = "listing" | "user" | "message";
export type ReportStatus = "open" | "flagged" | "resolved";

export interface User {
  id: string;
  role: Role;
  name: string;
  email: string;
  banned: boolean;
  createdAt: string;
}

export interface Listing {
  id: string;
  sellerId: string;
  title: string;
  description: string;
  priceCents: number;
  category: string;
  status: ListingStatus;
  photos: string[];
  createdAt: string;
  updatedAt: string;
}

export interface Inquiry {
  id: string;
  listingId: string;
  buyerId: string;
  sellerId: string;
  status: InquiryStatus;
  message: string;
  flagged: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Favorite {
  userId: string;
  listingId: string;
  createdAt: string;
}

/** A favorite as returned by GET /favorites, with the listing inlined. */
export interface FavoriteEntry extends Favorite {
  listing?: Listing;
}

export interface Report {
  id: string;
  targetType: ReportTargetType;
  targetId: string;
  reporterId: string;
  reason: string;
  status: ReportStatus;
  inquiryId?: string;
  createdAt: string;
  updatedAt: string;
}

/** GET /reports/:id returns the report plus the context support needs. */
export interface ReportDetail {
  report: Report;
  reporter?: User;
  listing?: Listing;
  inquiry?: Inquiry;
  buyer?: User;
  seller?: User;
}

export interface AuditEntry {
  id: string;
  actorId: string;
  actorRole: Role;
  action: string;
  target: string;
  details: string;
  createdAt: string;
}

export interface AuthResponse {
  token: string;
  user: User;
}

/**
 * Bootstrap payload for CometChat, returned by POST /cometchat/token. The
 * backend provisions the caller's CometChat user and mints a fresh per-user
 * auth token; the secret REST API key never leaves the server, so the client
 * only ever sees the non-secret App ID + Region and this short-lived token.
 */
export interface CometChatSession {
  appId: string;
  region: string;
  uid: string;
  authToken: string;
}
