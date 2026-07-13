package com.cometchat.marketplace

import android.app.Application
import com.cometchat.marketplace.data.MarketplaceRepository

/** Application entry point. Eagerly builds the repository singleton. */
class MarketplaceApp : Application() {

    val repository: MarketplaceRepository by lazy { MarketplaceRepository.get(this) }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        lateinit var instance: MarketplaceApp
            private set
    }
}
