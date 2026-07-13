package com.cometchat.marketplace.ui.listings

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.data.remote.CreateListingRequest
import com.cometchat.marketplace.data.remote.PatchListingRequest
import com.cometchat.marketplace.databinding.ActivityCreateListingBinding
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import com.cometchat.marketplace.util.formatPrice
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * Seller form to create a new listing, or edit an existing one (when started
 * with an id). Prices are entered in dollars and converted to the integer cents
 * the backend expects.
 */
class CreateListingActivity : AppCompatActivity() {

    private lateinit var binding: ActivityCreateListingBinding
    private var editId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityCreateListingBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.toolbar.setNavigationOnClickListener { finish() }

        editId = intent.getStringExtra(EXTRA_EDIT_ID)
        if (editId != null) {
            binding.toolbar.title = "Edit listing"
            binding.saveButton.text = "Save changes"
            prefill(editId!!)
        }
        binding.saveButton.setOnClickListener { submit() }
    }

    private fun prefill(id: String) {
        setLoading(true)
        lifecycleScope.launch {
            when (val r = repo.listing(id)) {
                is Outcome.Success -> bind(r.data)
                is Outcome.Error -> {
                    toast(r.message)
                    finish()
                }
            }
            setLoading(false)
        }
    }

    private fun bind(l: Listing) {
        binding.titleInput.setText(l.title)
        binding.descriptionInput.setText(l.description)
        // Show dollars with two decimals derived from cents.
        binding.priceInput.setText(formatPrice(l.priceCents).removePrefix("$").replace(",", ""))
        binding.categoryInput.setText(l.category)
        binding.photosInput.setText(l.photos.joinToString(", "))
    }

    private fun submit() {
        val title = binding.titleInput.text?.toString()?.trim().orEmpty()
        val description = binding.descriptionInput.text?.toString()?.trim().orEmpty()
        val category = binding.categoryInput.text?.toString()?.trim().orEmpty()
        val priceText = binding.priceInput.text?.toString()?.trim().orEmpty()
        val photos = binding.photosInput.text?.toString()
            ?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()

        if (title.isEmpty() || category.isEmpty()) {
            toast("Title and category are required")
            return
        }
        val dollars = priceText.toDoubleOrNull()
        if (dollars == null || dollars <= 0) {
            toast("Enter a valid price")
            return
        }
        val cents = (dollars * 100).roundToInt()

        setLoading(true)
        lifecycleScope.launch {
            val result: Outcome<Listing> = if (editId == null) {
                repo.createListing(
                    CreateListingRequest(title, description, cents, category, photos)
                )
            } else {
                repo.patchListing(
                    editId!!,
                    PatchListingRequest(
                        title = title,
                        description = description,
                        priceCents = cents,
                        category = category,
                        photos = photos,
                    ),
                )
            }
            setLoading(false)
            when (result) {
                is Outcome.Success -> {
                    toast(if (editId == null) "Listing published" else "Changes saved")
                    finish()
                }
                is Outcome.Error -> toast(result.message)
            }
        }
    }

    private fun setLoading(loading: Boolean) {
        binding.progress.visibility = if (loading) View.VISIBLE else View.GONE
        binding.saveButton.isEnabled = !loading
    }

    companion object {
        private const val EXTRA_EDIT_ID = "editId"

        fun start(context: Context) {
            context.startActivity(Intent(context, CreateListingActivity::class.java))
        }

        fun startForEdit(context: Context, listingId: String) {
            context.startActivity(
                Intent(context, CreateListingActivity::class.java)
                    .putExtra(EXTRA_EDIT_ID, listingId)
            )
        }
    }
}
