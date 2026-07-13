package com.cometchat.marketplace.data

import android.content.Context
import androidx.core.content.edit
import com.cometchat.marketplace.data.model.Role
import com.cometchat.marketplace.data.model.User
import com.google.gson.Gson

/**
 * Persists the session token and the authenticated user's identity/role across
 * app launches. The token is a backend-issued JWT carrying {userId, role};
 * every guarded request replays it via [com.cometchat.marketplace.data.remote.AuthInterceptor].
 *
 * Note: Phase A stores the token in app-private SharedPreferences, which is
 * adequate for a demo. A production build would move it to the Android Keystore
 * / EncryptedSharedPreferences.
 */
class SessionManager private constructor(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences("marketplace_session", Context.MODE_PRIVATE)
    private val gson = Gson()

    var token: String?
        get() = prefs.getString(KEY_TOKEN, null)
        private set(value) = prefs.edit { putString(KEY_TOKEN, value) }

    var user: User?
        get() = prefs.getString(KEY_USER, null)?.let { gson.fromJson(it, User::class.java) }
        private set(value) = prefs.edit {
            if (value == null) remove(KEY_USER) else putString(KEY_USER, gson.toJson(value))
        }

    val isLoggedIn: Boolean get() = !token.isNullOrEmpty() && user != null

    val role: Role? get() = user?.role

    fun save(token: String, user: User) {
        this.token = token
        this.user = user
    }

    /** Refresh the cached user (e.g. after GET /users/me) without touching the token. */
    fun updateUser(user: User) {
        this.user = user
    }

    fun clear() {
        prefs.edit { clear() }
    }

    companion object {
        private const val KEY_TOKEN = "token"
        private const val KEY_USER = "user"

        @Volatile
        private var instance: SessionManager? = null

        fun get(context: Context): SessionManager =
            instance ?: synchronized(this) {
                instance ?: SessionManager(context).also { instance = it }
            }
    }
}
