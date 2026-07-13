package com.cometchat.marketplace.util

import android.view.View
import java.text.NumberFormat
import java.util.Locale

/** Formats an integer number of cents as USD, e.g. 24500 -> "$245.00". */
fun formatPrice(cents: Int): String {
    val fmt = NumberFormat.getCurrencyInstance(Locale.US)
    return fmt.format(cents / 100.0)
}

/** Title-cases a status/category token, e.g. "active" -> "Active". */
fun String.titleCase(): String =
    split(' ', '_', '-')
        .filter { it.isNotBlank() }
        .joinToString(" ") { it.lowercase().replaceFirstChar { c -> c.uppercase() } }

fun View.visibleIf(condition: Boolean) {
    visibility = if (condition) View.VISIBLE else View.GONE
}
