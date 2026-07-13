// Typed wrappers for every backend route the web client uses. One function per
// endpoint keeps the REST contract in a single, reviewable place.

import { request } from "./client";
import type {
  AuditEntry,
  AuthResponse,
  FavoriteEntry,
  Inquiry,
  InquiryStatus,
  Listing,
  ListingStatus,
  Report,
  ReportDetail,
  ReportStatus,
  ReportTargetType,
  Role,
  User,
} from "./types";

// ---- Auth ----
export const login = (email: string, password: string) =>
  request<AuthResponse>("/auth/login", { method: "POST", auth: false, body: { email, password } });

export const register = (name: string, email: string, password: string, role: Role) =>
  request<AuthResponse>("/auth/register", { method: "POST", auth: false, body: { name, email, password, role } });

export const getMe = () => request<User>("/users/me");

// ---- Listings ----
export interface ListingQuery {
  search?: string;
  category?: string;
  minPrice?: number;
  maxPrice?: number;
}

export const listListings = (q: ListingQuery = {}) =>
  request<{ listings: Listing[] }>("/listings", {
    auth: false,
    query: { search: q.search, category: q.category, minPrice: q.minPrice, maxPrice: q.maxPrice },
  }).then((r) => r.listings);

export const getListing = (id: string) => request<Listing>(`/listings/${id}`, { auth: false });

export interface CreateListingInput {
  title: string;
  description: string;
  priceCents: number;
  category: string;
  photos: string[];
}

export const createListing = (input: CreateListingInput) =>
  request<Listing>("/listings", { method: "POST", body: input });

export interface PatchListingInput {
  title?: string;
  description?: string;
  priceCents?: number;
  category?: string;
  photos?: string[];
  status?: ListingStatus;
}

export const patchListing = (id: string, input: PatchListingInput) =>
  request<Listing>(`/listings/${id}`, { method: "PATCH", body: input });

// ---- Inquiries ----
export const createInquiry = (listingId: string, message: string) =>
  request<Inquiry>("/inquiries", { method: "POST", body: { listingId, message } });

export const listInquiries = () =>
  request<{ inquiries: Inquiry[] }>("/inquiries").then((r) => r.inquiries);

export const patchInquiry = (id: string, status: InquiryStatus) =>
  request<Inquiry>(`/inquiries/${id}`, { method: "PATCH", body: { status } });

// ---- Favorites ----
export const addFavorite = (listingId: string) =>
  request<unknown>("/favorites", { method: "POST", body: { listingId } });

export const listFavorites = () =>
  request<{ favorites: FavoriteEntry[] }>("/favorites").then((r) => r.favorites);

export const removeFavorite = (listingId: string) =>
  request<void>(`/favorites/${listingId}`, { method: "DELETE" });

// ---- Reports ----
export interface CreateReportInput {
  targetType: ReportTargetType;
  targetId: string;
  reason: string;
  inquiryId?: string;
}

export const createReport = (input: CreateReportInput) =>
  request<Report>("/reports", { method: "POST", body: input });

export const listReports = (status?: ReportStatus) =>
  request<{ reports: Report[] }>("/reports", { query: { status } }).then((r) => r.reports);

export const getReport = (id: string) => request<ReportDetail>(`/reports/${id}`);

export const patchReport = (id: string, status: ReportStatus) =>
  request<Report>(`/reports/${id}`, { method: "PATCH", body: { status } });

// ---- Admin ----
export const adminListUsers = () =>
  request<{ users: User[] }>("/admin/users").then((r) => r.users);

export const adminPatchUser = (id: string, patch: { banned?: boolean; role?: Role }) =>
  request<User>(`/admin/users/${id}`, { method: "PATCH", body: patch });

export const adminRemoveListing = (id: string) =>
  request<Listing>(`/admin/listings/${id}`, { method: "DELETE" });

export const adminAudit = () =>
  request<{ audit: AuditEntry[] }>("/admin/audit").then((r) => r.audit);
