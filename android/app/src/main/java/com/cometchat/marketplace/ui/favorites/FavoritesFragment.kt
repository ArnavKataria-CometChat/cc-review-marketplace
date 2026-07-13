package com.cometchat.marketplace.ui.favorites

import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.ui.common.BaseListFragment
import com.cometchat.marketplace.ui.common.ListingAdapter
import com.cometchat.marketplace.ui.listings.ListingDetailActivity
import com.cometchat.marketplace.ui.repo

/** Buyer's saved listings (GET /favorites, which inlines each listing). */
class FavoritesFragment : BaseListFragment() {

    private val adapter = ListingAdapter { listing ->
        ListingDetailActivity.start(requireContext(), listing.id)
    }

    override val emptyText: String get() = "No saved listings yet.\nTap the heart on a listing to save it."

    override fun onSetup(recycler: RecyclerView) {
        recycler.adapter = adapter
    }

    override fun load() {
        loadInto(
            fetch = { repo.favorites() },
            onData = { entries ->
                val listings = entries.mapNotNull { it.listing ?: it.listingId.asStubListing() }
                adapter.submit(listings)
            },
        )
    }

    // A favorite whose listing was removed still returns an id; show a stub so
    // the buyer can see (and un-save) it rather than it silently vanishing.
    private fun String.asStubListing(): Listing =
        Listing(id = this, title = "Listing $this", status = "removed")
}
