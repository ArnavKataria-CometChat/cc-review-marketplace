package com.cometchat.marketplace.data

/**
 * A lightweight success/failure wrapper for repository calls, so UI layers can
 * branch without try/catch and render a friendly message on failure.
 */
sealed class Outcome<out T> {
    data class Success<T>(val data: T) : Outcome<T>()
    data class Error(val message: String, val code: Int? = null) : Outcome<Nothing>()

    inline fun onSuccess(block: (T) -> Unit): Outcome<T> {
        if (this is Success) block(data)
        return this
    }

    inline fun onError(block: (String) -> Unit): Outcome<T> {
        if (this is Error) block(message)
        return this
    }
}
