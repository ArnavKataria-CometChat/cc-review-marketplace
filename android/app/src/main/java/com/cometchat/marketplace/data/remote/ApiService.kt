package com.cometchat.marketplace.data.remote

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.data.model.Inquiry
import com.cometchat.marketplace.data.model.Favorite
import com.cometchat.marketplace.data.model.Report
import com.cometchat.marketplace.data.model.User

/**
 * Retrofit description of the marketplace REST API (../backend, Go/Gin).
 * The [com.cometchat.marketplace.data.remote.AuthInterceptor] attaches the
 * bearer token, so route methods don't carry an Authorization parameter.
 */
interface ApiService {

    // --- Public auth ---
    @POST("auth/login")
    suspend fun login(@Body body: LoginRequest): Response<AuthResponse>

    @POST("auth/register")
    suspend fun register(@Body body: RegisterRequest): Response<AuthResponse>

    // --- Listings (browsing public; create/patch guarded server-side) ---
    @GET("listings")
    suspend fun listings(
        @Query("search") search: String? = null,
        @Query("category") category: String? = null,
        @Query("minPrice") minPrice: Int? = null,
        @Query("maxPrice") maxPrice: Int? = null,
    ): Response<ListingsResponse>

    @GET("listings/{id}")
    suspend fun listing(@Path("id") id: String): Response<Listing>

    @POST("listings")
    suspend fun createListing(@Body body: CreateListingRequest): Response<Listing>

    @PATCH("listings/{id}")
    suspend fun patchListing(
        @Path("id") id: String,
        @Body body: PatchListingRequest,
    ): Response<Listing>

    // --- Current user ---
    @GET("users/me")
    suspend fun me(): Response<User>

    // --- CometChat bootstrap: sync chat identity + mint a per-user auth token ---
    @POST("cometchat/token")
    suspend fun cometChatToken(): Response<CometChatTokenResponse>

    // --- Inquiries ---
    @POST("inquiries")
    suspend fun createInquiry(@Body body: CreateInquiryRequest): Response<Inquiry>

    @GET("inquiries")
    suspend fun inquiries(): Response<InquiriesResponse>

    @PATCH("inquiries/{id}")
    suspend fun patchInquiry(
        @Path("id") id: String,
        @Body body: PatchInquiryRequest,
    ): Response<Inquiry>

    // --- Favorites (buyer) ---
    @POST("favorites")
    suspend fun addFavorite(@Body body: AddFavoriteRequest): Response<Favorite>

    @GET("favorites")
    suspend fun favorites(): Response<FavoritesResponse>

    @DELETE("favorites/{listingId}")
    suspend fun removeFavorite(@Path("listingId") listingId: String): Response<Unit>

    // --- Reports (create: any authed user; queue/detail: support+admin) ---
    @POST("reports")
    suspend fun createReport(@Body body: CreateReportRequest): Response<Report>

    @GET("reports")
    suspend fun reports(@Query("status") status: String? = null): Response<ReportsResponse>

    @GET("reports/{id}")
    suspend fun report(@Path("id") id: String): Response<ReportDetailResponse>

    @PATCH("reports/{id}")
    suspend fun patchReport(
        @Path("id") id: String,
        @Body body: PatchReportRequest,
    ): Response<Report>

    // --- Admin ---
    @GET("admin/users")
    suspend fun adminUsers(): Response<UsersResponse>

    @PATCH("admin/users/{id}")
    suspend fun adminPatchUser(
        @Path("id") id: String,
        @Body body: PatchUserRequest,
    ): Response<User>

    @DELETE("admin/listings/{id}")
    suspend fun adminRemoveListing(@Path("id") id: String): Response<Listing>

    @GET("admin/audit")
    suspend fun adminAudit(): Response<AuditResponse>
}
