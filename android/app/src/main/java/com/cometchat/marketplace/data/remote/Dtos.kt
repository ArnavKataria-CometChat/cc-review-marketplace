package com.cometchat.marketplace.data.remote

import com.cometchat.marketplace.data.model.FavoriteEntry
import com.cometchat.marketplace.data.model.Inquiry
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.data.model.Report
import com.cometchat.marketplace.data.model.User
import com.cometchat.marketplace.data.model.AuditEntry
import com.cometchat.marketplace.data.model.Role

/** Request/response DTOs mirroring the backend HTTP handlers. */

data class LoginRequest(val email: String, val password: String)

data class RegisterRequest(
    val name: String,
    val email: String,
    val password: String,
    val role: String,
)

/** POST /auth/login and /auth/register both return {token, user}. */
data class AuthResponse(val token: String = "", val user: User? = null)

data class ListingsResponse(val listings: List<Listing> = emptyList())

data class CreateListingRequest(
    val title: String,
    val description: String,
    val priceCents: Int,
    val category: String,
    val photos: List<String> = emptyList(),
)

/** PATCH /listings/:id — all fields optional (null = unchanged). */
data class PatchListingRequest(
    val title: String? = null,
    val description: String? = null,
    val priceCents: Int? = null,
    val category: String? = null,
    val photos: List<String>? = null,
    val status: String? = null,
)

data class CreateInquiryRequest(val listingId: String, val message: String)

data class InquiriesResponse(val inquiries: List<Inquiry> = emptyList())

data class PatchInquiryRequest(val status: String)

data class AddFavoriteRequest(val listingId: String)

data class FavoritesResponse(val favorites: List<FavoriteEntry> = emptyList())

data class CreateReportRequest(
    val targetType: String,
    val targetId: String,
    val reason: String,
    val inquiryId: String? = null,
)

data class ReportsResponse(val reports: List<Report> = emptyList())

/** GET /reports/:id — report plus the context support needs. */
data class ReportDetailResponse(
    val report: Report? = null,
    val reporter: User? = null,
    val listing: Listing? = null,
    val inquiry: Inquiry? = null,
    val buyer: User? = null,
    val seller: User? = null,
)

data class PatchReportRequest(val status: String)

data class UsersResponse(val users: List<User> = emptyList())

data class PatchUserRequest(val banned: Boolean? = null, val role: String? = null)

data class AuditResponse(val audit: List<AuditEntry> = emptyList())
