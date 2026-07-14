package com.cometchat.marketplace

import android.app.Application
import com.cometchat.marketplace.chat.ChatManager
import com.cometchat.marketplace.data.MarketplaceRepository

/** Application entry point. Eagerly builds the repository singleton. */
class MarketplaceApp : Application() {

    val repository: MarketplaceRepository by lazy { MarketplaceRepository.get(this) }

    override fun onCreate() {
        super.onCreate()
        instance = this
        // Wire CometChat call-lifecycle handling (activity tracking + call-end
        // re-foregrounding). The SDK itself is initialized lazily post-login by
        // ChatManager.ensureReady, since App ID/Region come from the backend.
        ChatManager.install(this)
    }

    companion object {
        lateinit var instance: MarketplaceApp
            private set
    }
}
