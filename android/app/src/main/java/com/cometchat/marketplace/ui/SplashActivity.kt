package com.cometchat.marketplace.ui

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.ui.auth.LoginActivity
import com.cometchat.marketplace.ui.main.MainActivity
import kotlinx.coroutines.launch

/**
 * Decides the start destination: if a session token is present it is validated
 * against the backend (GET /users/me) before entering the app, so a stale or
 * revoked token routes back to login instead of into a broken session.
 */
@SuppressLint("CustomSplashScreen")
class SplashActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!repo.isLoggedIn) {
            go(LoginActivity::class.java)
            return
        }
        lifecycleScope.launch {
            when (repo.refreshMe()) {
                is Outcome.Success -> go(MainActivity::class.java)
                is Outcome.Error -> {
                    repo.logout()
                    go(LoginActivity::class.java)
                }
            }
        }
    }

    private fun go(target: Class<*>) {
        startActivity(Intent(this, target))
        finish()
    }
}
