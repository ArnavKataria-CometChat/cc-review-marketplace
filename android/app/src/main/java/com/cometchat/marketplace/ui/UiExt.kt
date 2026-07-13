package com.cometchat.marketplace.ui

import android.content.Context
import android.widget.Toast
import androidx.fragment.app.Fragment
import com.cometchat.marketplace.MarketplaceApp
import com.cometchat.marketplace.data.MarketplaceRepository

/** Convenience access to the shared repository from any Context / Fragment. */
val Context.repo: MarketplaceRepository
    get() = (applicationContext as MarketplaceApp).repository

val Fragment.repo: MarketplaceRepository
    get() = requireContext().repo

fun Context.toast(message: String) {
    Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
}

fun Fragment.toast(message: String) = requireContext().toast(message)
