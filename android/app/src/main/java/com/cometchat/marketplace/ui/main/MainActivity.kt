package com.cometchat.marketplace.ui.main

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.Fragment
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.model.Role
import com.cometchat.marketplace.databinding.ActivityMainBinding
import com.cometchat.marketplace.ui.admin.AdminUsersFragment
import com.cometchat.marketplace.ui.admin.AuditFragment
import com.cometchat.marketplace.ui.admin.ModerationFragment
import com.cometchat.marketplace.ui.auth.LoginActivity
import com.cometchat.marketplace.ui.favorites.FavoritesFragment
import com.cometchat.marketplace.ui.inquiries.InquiriesFragment
import com.cometchat.marketplace.ui.listings.BrowseFragment
import com.cometchat.marketplace.ui.listings.MyListingsFragment
import com.cometchat.marketplace.ui.profile.ProfileFragment
import com.cometchat.marketplace.ui.reports.DisputeQueueFragment
import com.cometchat.marketplace.ui.repo

/**
 * Single-activity host. The bottom-navigation menu and the set of reachable
 * fragments are chosen from the authenticated user's role — the client-side
 * half of RBAC. (The backend independently guards every route, so a tampered
 * client still can't exceed its role.)
 */
class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Guard: never render the app without a session.
        val role = repo.currentUser?.role
        if (role == null) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setSupportActionBar(binding.toolbar)

        binding.bottomNav.inflateMenu(menuForRole(role))
        binding.bottomNav.setOnItemSelectedListener { item ->
            showFragment(item.itemId)
            true
        }
        // Select the first tab on first launch.
        if (savedInstanceState == null) {
            binding.bottomNav.selectedItemId = binding.bottomNav.menu.getItem(0).itemId
        }
    }

    private fun menuForRole(role: Role): Int = when (role) {
        Role.BUYER -> R.menu.menu_buyer
        Role.SELLER -> R.menu.menu_seller
        Role.SUPPORT -> R.menu.menu_support
        Role.ADMIN -> R.menu.menu_admin
    }

    private fun showFragment(itemId: Int) {
        val (fragment, title) = fragmentFor(itemId)
        supportActionBar?.title = title
        supportFragmentManager.beginTransaction()
            .replace(R.id.container, fragment)
            .commit()
    }

    private fun fragmentFor(itemId: Int): Pair<Fragment, String> = when (itemId) {
        R.id.nav_browse -> BrowseFragment() to getString(R.string.nav_browse)
        R.id.nav_favorites -> FavoritesFragment() to getString(R.string.nav_favorites)
        R.id.nav_inquiries -> InquiriesFragment() to getString(R.string.nav_inquiries)
        R.id.nav_listings -> MyListingsFragment() to getString(R.string.nav_listings)
        R.id.nav_queue -> DisputeQueueFragment() to getString(R.string.nav_queue)
        R.id.nav_users -> AdminUsersFragment() to getString(R.string.nav_users)
        R.id.nav_moderation -> ModerationFragment() to getString(R.string.nav_moderation)
        R.id.nav_audit -> AuditFragment() to getString(R.string.nav_audit)
        R.id.nav_profile -> ProfileFragment() to getString(R.string.nav_profile)
        else -> BrowseFragment() to getString(R.string.app_name)
    }
}
