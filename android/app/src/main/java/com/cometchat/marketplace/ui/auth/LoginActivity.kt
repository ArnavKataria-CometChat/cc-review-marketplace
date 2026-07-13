package com.cometchat.marketplace.ui.auth

import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.databinding.ActivityLoginBinding
import com.cometchat.marketplace.ui.main.MainActivity
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import com.cometchat.marketplace.util.visibleIf
import kotlinx.coroutines.launch

/**
 * Email + password auth. A single form toggles between "log in" and "create
 * account" (self-service registration is buyer/seller only, matching the
 * backend). On success the session is saved and the user enters [MainActivity],
 * which renders the role-appropriate navigation.
 */
class LoginActivity : AppCompatActivity() {

    private companion object {
        // Shared password for every seeded demo account (see backend seed).
        const val DEMO_PASSWORD = "Password123!"
    }

    private lateinit var binding: ActivityLoginBinding
    private var registerMode = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.toggleButton.setOnClickListener { setMode(!registerMode) }
        binding.primaryButton.setOnClickListener { submit() }

        // Tap-to-fill demo accounts (parity with web + iOS): each button carries
        // its email in android:tag; tapping fills the form with the shared demo
        // password so the user can sign in with one tap.
        val fillDemo = View.OnClickListener { v ->
            setMode(false)
            binding.emailInput.setText(v.tag as String)
            binding.passwordInput.setText(DEMO_PASSWORD)
        }
        listOf(binding.demoBuyer, binding.demoSeller, binding.demoSupport, binding.demoAdmin)
            .forEach { it.setOnClickListener(fillDemo) }

        setMode(false)
    }

    private fun setMode(register: Boolean) {
        registerMode = register
        binding.nameLayout.visibleIf(register)
        binding.roleRow.visibleIf(register)
        binding.primaryButton.setText(if (register) R.string.action_register else R.string.action_login)
        binding.toggleButton.setText(
            if (register) R.string.action_have_account else R.string.action_need_account
        )
    }

    private fun submit() {
        val email = binding.emailInput.text?.toString()?.trim().orEmpty()
        val password = binding.passwordInput.text?.toString().orEmpty()
        if (email.isEmpty() || password.isEmpty()) {
            toast("Email and password are required")
            return
        }
        if (registerMode) {
            val name = binding.nameInput.text?.toString()?.trim().orEmpty()
            if (name.isEmpty()) {
                toast("Name is required")
                return
            }
            if (password.length < 8) {
                toast("Password must be at least 8 characters")
                return
            }
            val role = if (binding.chipSeller.isChecked) "seller" else "buyer"
            submitAuth { repo.register(name, email, password, role) }
        } else {
            submitAuth { repo.login(email, password) }
        }
    }

    private inline fun submitAuth(crossinline action: suspend () -> Outcome<*>) {
        setLoading(true)
        lifecycleScope.launch {
            val result = action()
            setLoading(false)
            when (result) {
                is Outcome.Success -> {
                    startActivity(Intent(this@LoginActivity, MainActivity::class.java))
                    finish()
                }
                is Outcome.Error -> toast(result.message)
            }
        }
    }

    private fun setLoading(loading: Boolean) {
        binding.progress.visibleIf(loading)
        binding.primaryButton.isEnabled = !loading
        binding.toggleButton.isEnabled = !loading
    }
}
