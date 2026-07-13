package com.cometchat.marketplace.ui.listings

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import coil.load
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.data.model.Role
import com.cometchat.marketplace.databinding.ActivityListingDetailBinding
import com.cometchat.marketplace.ui.inquiries.InquiryDetailActivity
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import com.cometchat.marketplace.util.formatPrice
import com.cometchat.marketplace.util.titleCase
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

/**
 * Listing detail with a role-aware action area:
 *  - buyer (non-owner): contact seller (opens an inquiry), save/unsave, report
 *  - seller (owner):    edit, mark sold
 *  - admin:             remove listing
 *  - support:           read-only
 *
 * These are the same guards the backend enforces; the UI simply hides what the
 * caller isn't allowed to do.
 */
class ListingDetailActivity : AppCompatActivity() {

    private lateinit var binding: ActivityListingDetailBinding
    private lateinit var listingId: String
    private var listing: Listing? = null
    private var isFavorite = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityListingDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)
        listingId = intent.getStringExtra(EXTRA_ID).orEmpty()
        binding.toolbar.setNavigationOnClickListener { finish() }
    }

    override fun onResume() {
        super.onResume()
        load()
    }

    private fun load() {
        binding.progress.visibility = View.VISIBLE
        binding.content.visibility = View.GONE
        lifecycleScope.launch {
            when (val result = repo.listing(listingId)) {
                is Outcome.Success -> {
                    listing = result.data
                    render(result.data)
                }
                is Outcome.Error -> {
                    toast(result.message)
                    finish()
                }
            }
        }
    }

    private fun render(l: Listing) {
        binding.progress.visibility = View.GONE
        binding.content.visibility = View.VISIBLE
        binding.photo.load(l.photos.firstOrNull()) {
            crossfade(true)
            placeholder(R.drawable.bg_photo_placeholder)
            error(R.drawable.bg_photo_placeholder)
        }
        binding.title.text = l.title
        binding.price.text = formatPrice(l.priceCents)
        binding.category.text = l.category.titleCase()
        binding.status.text = l.status.uppercase()
        binding.status.setTextColor(
            ContextCompat.getColor(
                this,
                when (l.status) {
                    "sold" -> R.color.status_sold
                    "removed" -> R.color.status_removed
                    else -> R.color.status_active
                },
            )
        )
        binding.description.text = l.description.ifBlank { "No description provided." }

        buildActions(l)
    }

    private fun buildActions(l: Listing) {
        val container = binding.actions
        container.removeAllViews()
        val user = repo.currentUser ?: return
        val isOwner = user.id == l.sellerId

        when (user.role) {
            Role.BUYER -> if (!isOwner) buildBuyerActions(container, l)
            Role.SELLER -> if (isOwner) buildOwnerActions(container, l) else buildBuyerViewNote(container)
            Role.ADMIN -> buildAdminActions(container, l)
            Role.SUPPORT -> addNote(container, "Support view — read only.")
        }
    }

    // --- Buyer -------------------------------------------------------------

    private fun buildBuyerActions(container: LinearLayout, l: Listing) {
        if (l.status != "active") {
            addNote(container, "This item is ${l.status} and can no longer be inquired on.")
        } else {
            addFilled(container, "Contact seller") { promptInquiry(l) }
        }
        refreshFavoriteState(container, l)
        addOutlined(container, "Report listing") { promptReport(l) }
    }

    private fun buildBuyerViewNote(container: LinearLayout) {
        addNote(container, "You can't inquire on another seller's listing from a seller account.")
    }

    private fun refreshFavoriteState(container: LinearLayout, l: Listing) {
        val favButton = addOutlined(container, "Save to favorites") { }
        lifecycleScope.launch {
            isFavorite = when (val favs = repo.favorites()) {
                is Outcome.Success -> favs.data.any { it.listingId == l.id }
                is Outcome.Error -> false
            }
            favButton.text = if (isFavorite) "Saved ✓ — tap to remove" else "Save to favorites"
            favButton.setOnClickListener { toggleFavorite(l, favButton) }
        }
    }

    private fun toggleFavorite(l: Listing, button: MaterialButton) {
        button.isEnabled = false
        lifecycleScope.launch {
            val result = if (isFavorite) repo.removeFavorite(l.id) else repo.addFavorite(l.id)
            button.isEnabled = true
            when (result) {
                is Outcome.Success -> {
                    isFavorite = !isFavorite
                    button.text = if (isFavorite) "Saved ✓ — tap to remove" else "Save to favorites"
                    toast(if (isFavorite) "Saved" else "Removed from favorites")
                }
                is Outcome.Error -> toast(result.message)
            }
        }
    }

    private fun promptInquiry(l: Listing) {
        val input = TextInputEditText(this).apply {
            hint = "e.g. Is this still available?"
            setPadding(48, 32, 48, 32)
        }
        AlertDialog.Builder(this)
            .setTitle("Contact seller")
            .setMessage("Start an inquiry thread about \"${l.title}\".")
            .setView(input)
            .setPositiveButton("Send") { _, _ ->
                val message = input.text?.toString()?.trim().orEmpty()
                lifecycleScope.launch {
                    when (val r = repo.createInquiry(l.id, message)) {
                        is Outcome.Success -> {
                            toast("Inquiry opened")
                            InquiryDetailActivity.start(this@ListingDetailActivity, r.data.id)
                        }
                        is Outcome.Error -> toast(r.message)
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun promptReport(l: Listing) {
        val input = TextInputEditText(this).apply {
            hint = "Why are you reporting this?"
            setPadding(48, 32, 48, 32)
        }
        AlertDialog.Builder(this)
            .setTitle("Report listing")
            .setView(input)
            .setPositiveButton("Submit") { _, _ ->
                val reason = input.text?.toString()?.trim().orEmpty()
                if (reason.isEmpty()) {
                    toast("Please provide a reason")
                    return@setPositiveButton
                }
                lifecycleScope.launch {
                    val req = com.cometchat.marketplace.data.remote.CreateReportRequest(
                        targetType = "listing",
                        targetId = l.id,
                        reason = reason,
                    )
                    when (val r = repo.createReport(req)) {
                        is Outcome.Success -> toast("Report submitted to support")
                        is Outcome.Error -> toast(r.message)
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    // --- Seller (owner) ----------------------------------------------------

    private fun buildOwnerActions(container: LinearLayout, l: Listing) {
        addFilled(container, "Edit listing") { CreateListingActivity.startForEdit(this, l.id) }
        if (l.status == "active") {
            addOutlined(container, "Mark as sold") { markSold(l) }
        } else {
            addNote(container, "This listing is ${l.status}.")
        }
    }

    private fun markSold(l: Listing) {
        lifecycleScope.launch {
            when (val r = repo.markSold(l.id)) {
                is Outcome.Success -> {
                    toast("Marked as sold")
                    load()
                }
                is Outcome.Error -> toast(r.message)
            }
        }
    }

    // --- Admin -------------------------------------------------------------

    private fun buildAdminActions(container: LinearLayout, l: Listing) {
        if (l.status == "removed") {
            addNote(container, "This listing has already been removed.")
            return
        }
        addOutlined(container, "Remove listing") {
            AlertDialog.Builder(this)
                .setTitle("Remove listing?")
                .setMessage("This takes \"${l.title}\" down for everyone.")
                .setPositiveButton("Remove") { _, _ -> removeListing(l) }
                .setNegativeButton("Cancel", null)
                .show()
        }
    }

    private fun removeListing(l: Listing) {
        lifecycleScope.launch {
            when (val r = repo.adminRemoveListing(l.id)) {
                is Outcome.Success -> {
                    toast("Listing removed")
                    load()
                }
                is Outcome.Error -> toast(r.message)
            }
        }
    }

    // --- View helpers ------------------------------------------------------

    private fun addFilled(container: LinearLayout, text: String, onClick: () -> Unit): MaterialButton {
        val button = layoutInflater.inflate(R.layout.btn_filled, container, false) as MaterialButton
        button.text = text
        button.setOnClickListener { onClick() }
        container.addView(button)
        return button
    }

    private fun addOutlined(container: LinearLayout, text: String, onClick: () -> Unit): MaterialButton {
        val button = layoutInflater.inflate(R.layout.btn_outlined, container, false) as MaterialButton
        button.text = text
        button.setOnClickListener { onClick() }
        container.addView(button)
        return button
    }

    private fun addNote(container: LinearLayout, text: String) {
        val tv = android.widget.TextView(this).apply {
            this.text = text
            setTextColor(ContextCompat.getColor(this@ListingDetailActivity, R.color.text_secondary))
            textSize = 14f
        }
        container.addView(tv)
    }

    companion object {
        private const val EXTRA_ID = "listingId"

        fun start(context: Context, listingId: String) {
            context.startActivity(
                Intent(context, ListingDetailActivity::class.java).putExtra(EXTRA_ID, listingId)
            )
        }
    }
}
