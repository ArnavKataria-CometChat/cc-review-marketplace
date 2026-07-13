package com.cometchat.marketplace.data

import android.content.Context
import com.cometchat.marketplace.data.model.AuditEntry
import com.cometchat.marketplace.data.model.FavoriteEntry
import com.cometchat.marketplace.data.model.Inquiry
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.data.model.Report
import com.cometchat.marketplace.data.model.User
import com.cometchat.marketplace.data.remote.AddFavoriteRequest
import com.cometchat.marketplace.data.remote.ApiClient
import com.cometchat.marketplace.data.remote.ApiService
import com.cometchat.marketplace.data.remote.CreateInquiryRequest
import com.cometchat.marketplace.data.remote.CreateListingRequest
import com.cometchat.marketplace.data.remote.CreateReportRequest
import com.cometchat.marketplace.data.remote.LoginRequest
import com.cometchat.marketplace.data.remote.PatchInquiryRequest
import com.cometchat.marketplace.data.remote.PatchListingRequest
import com.cometchat.marketplace.data.remote.PatchReportRequest
import com.cometchat.marketplace.data.remote.PatchUserRequest
import com.cometchat.marketplace.data.remote.RegisterRequest
import com.cometchat.marketplace.data.remote.ReportDetailResponse
import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
import retrofit2.Response
import java.io.IOException

/**
 * Single entry point to the backend. Every method returns an [Outcome] so the
 * ViewModels never touch Retrofit types or exceptions directly. Auth state is
 * kept in [SessionManager], which the interceptor reads for the bearer token.
 */
class MarketplaceRepository private constructor(
    private val api: ApiService,
    val session: SessionManager,
) {

    val currentUser: User? get() = session.user
    val isLoggedIn: Boolean get() = session.isLoggedIn

    // --- Auth ---------------------------------------------------------------

    suspend fun login(email: String, password: String): Outcome<User> =
        call { api.login(LoginRequest(email.trim(), password)) }.map { auth ->
            val user = auth.user ?: return Outcome.Error("Malformed login response")
            session.save(auth.token, user)
            user
        }

    suspend fun register(name: String, email: String, password: String, role: String): Outcome<User> =
        call { api.register(RegisterRequest(name.trim(), email.trim(), password, role)) }.map { auth ->
            val user = auth.user ?: return Outcome.Error("Malformed register response")
            session.save(auth.token, user)
            user
        }

    suspend fun refreshMe(): Outcome<User> =
        call { api.me() }.onSuccess { session.updateUser(it) }

    fun logout() = session.clear()

    // --- Listings -----------------------------------------------------------

    suspend fun listings(
        search: String? = null,
        category: String? = null,
        minPrice: Int? = null,
        maxPrice: Int? = null,
    ): Outcome<List<Listing>> =
        call {
            api.listings(
                search = search?.ifBlank { null },
                category = category?.ifBlank { null },
                minPrice = minPrice,
                maxPrice = maxPrice,
            )
        }.map { it.listings }

    suspend fun listing(id: String): Outcome<Listing> = call { api.listing(id) }

    suspend fun createListing(req: CreateListingRequest): Outcome<Listing> =
        call { api.createListing(req) }

    suspend fun patchListing(id: String, req: PatchListingRequest): Outcome<Listing> =
        call { api.patchListing(id, req) }

    suspend fun markSold(id: String): Outcome<Listing> =
        patchListing(id, PatchListingRequest(status = "sold"))

    // --- Inquiries ----------------------------------------------------------

    suspend fun createInquiry(listingId: String, message: String): Outcome<Inquiry> =
        call { api.createInquiry(CreateInquiryRequest(listingId, message)) }

    suspend fun inquiries(): Outcome<List<Inquiry>> =
        call { api.inquiries() }.map { it.inquiries }

    suspend fun setInquiryStatus(id: String, status: String): Outcome<Inquiry> =
        call { api.patchInquiry(id, PatchInquiryRequest(status)) }

    // --- Favorites ----------------------------------------------------------

    suspend fun addFavorite(listingId: String): Outcome<Unit> =
        call { api.addFavorite(AddFavoriteRequest(listingId)) }.map { }

    suspend fun favorites(): Outcome<List<FavoriteEntry>> =
        call { api.favorites() }.map { it.favorites }

    suspend fun removeFavorite(listingId: String): Outcome<Unit> =
        call { api.removeFavorite(listingId) }

    // --- Reports ------------------------------------------------------------

    suspend fun createReport(req: CreateReportRequest): Outcome<Report> =
        call { api.createReport(req) }

    suspend fun reports(status: String? = null): Outcome<List<Report>> =
        call { api.reports(status?.ifBlank { null }) }.map { it.reports }

    suspend fun report(id: String): Outcome<ReportDetailResponse> = call { api.report(id) }

    suspend fun setReportStatus(id: String, status: String): Outcome<Report> =
        call { api.patchReport(id, PatchReportRequest(status)) }

    // --- Admin --------------------------------------------------------------

    suspend fun adminUsers(): Outcome<List<User>> =
        call { api.adminUsers() }.map { it.users }

    suspend fun adminPatchUser(id: String, banned: Boolean? = null, role: String? = null): Outcome<User> =
        call { api.adminPatchUser(id, PatchUserRequest(banned, role)) }

    suspend fun adminRemoveListing(id: String): Outcome<Listing> =
        call { api.adminRemoveListing(id) }

    suspend fun adminAudit(): Outcome<List<AuditEntry>> =
        call { api.adminAudit() }.map { it.audit }

    // --- Plumbing -----------------------------------------------------------

    private inline fun <T, R> Outcome<T>.map(transform: (T) -> R): Outcome<R> = when (this) {
        is Outcome.Success -> Outcome.Success(transform(data))
        is Outcome.Error -> this
    }

    /**
     * Executes a Retrofit call, normalizing transport errors, non-2xx statuses
     * (decoding the backend's `{"error": "..."}` envelope) and null bodies into
     * an [Outcome].
     */
    private suspend fun <T> call(block: suspend () -> Response<T>): Outcome<T> = try {
        val resp = block()
        if (resp.isSuccessful) {
            // 204 No Content has a null body but is still a success (e.g. DELETE).
            @Suppress("UNCHECKED_CAST")
            val body = resp.body() ?: Unit as T
            Outcome.Success(body)
        } else {
            Outcome.Error(parseError(resp), resp.code())
        }
    } catch (e: IOException) {
        Outcome.Error("Can't reach the server. Check your connection and that the backend is running.")
    } catch (e: Exception) {
        Outcome.Error(e.message ?: "Unexpected error")
    }

    private fun parseError(resp: Response<*>): String {
        val raw = try {
            resp.errorBody()?.string()
        } catch (_: Exception) {
            null
        }
        if (!raw.isNullOrBlank()) {
            try {
                val env = Gson().fromJson(raw, ErrorEnvelope::class.java)
                if (!env?.error.isNullOrBlank()) return env!!.error!!
            } catch (_: JsonSyntaxException) {
                // fall through to generic messages
            }
        }
        return when (resp.code()) {
            401 -> "Session expired — please log in again"
            403 -> "You don't have permission to do that"
            404 -> "Not found"
            409 -> "Already exists"
            else -> "Request failed (${resp.code()})"
        }
    }

    private data class ErrorEnvelope(val error: String?)

    companion object {
        @Volatile
        private var instance: MarketplaceRepository? = null

        fun get(context: Context): MarketplaceRepository =
            instance ?: synchronized(this) {
                instance ?: run {
                    val session = SessionManager.get(context)
                    MarketplaceRepository(ApiClient.api(session), session).also { instance = it }
                }
            }
    }
}
