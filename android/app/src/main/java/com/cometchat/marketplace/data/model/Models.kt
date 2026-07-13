package com.cometchat.marketplace.data.model

import com.google.gson.annotations.SerializedName

/**
 * Domain models mirroring the backend JSON contract (../backend/internal/models).
 * Field names match the Go `json:"..."` tags exactly so Gson maps 1:1.
 */

enum class Role {
    @SerializedName("buyer") BUYER,
    @SerializedName("seller") SELLER,
    @SerializedName("support") SUPPORT,
    @SerializedName("admin") ADMIN;

    val wire: String
        get() = name.lowercase()

    val label: String
        get() = name.lowercase().replaceFirstChar { it.uppercase() }
}

data class User(
    val id: String = "",
    val role: Role = Role.BUYER,
    val name: String = "",
    val email: String = "",
    val banned: Boolean = false,
    val createdAt: String? = null,
)

data class Listing(
    val id: String = "",
    val sellerId: String = "",
    val title: String = "",
    val description: String = "",
    val priceCents: Int = 0,
    val category: String = "",
    val status: String = "active", // active | sold | removed
    val photos: List<String> = emptyList(),
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

data class Inquiry(
    val id: String = "",
    val listingId: String = "",
    val buyerId: String = "",
    val sellerId: String = "",
    val status: String = "open", // open | closed
    val message: String = "",
    val flagged: Boolean = false,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

data class Favorite(
    val userId: String = "",
    val listingId: String = "",
    val createdAt: String? = null,
)

/** A favorite with its listing inlined, as returned by GET /favorites. */
data class FavoriteEntry(
    val userId: String = "",
    val listingId: String = "",
    val createdAt: String? = null,
    val listing: Listing? = null,
)

data class Report(
    val id: String = "",
    val targetType: String = "listing", // listing | user | message
    val targetId: String = "",
    val reporterId: String = "",
    val reason: String = "",
    val status: String = "open", // open | flagged | resolved
    val inquiryId: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
)

data class AuditEntry(
    val id: String = "",
    val actorId: String = "",
    val actorRole: Role = Role.ADMIN,
    val action: String = "",
    val target: String = "",
    val details: String = "",
    val createdAt: String? = null,
)
