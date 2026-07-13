package com.cometchat.marketplace.ui.admin

import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.ui.common.BaseListFragment
import com.cometchat.marketplace.ui.common.ListingAdapter
import com.cometchat.marketplace.ui.listings.ListingDetailActivity
import com.cometchat.marketplace.ui.repo

/**
 * Admin listing moderation. Lists the active catalog; tapping a listing opens
 * the detail screen where an admin can take it down (DELETE /admin/listings/:id).
 */
class ModerationFragment : BaseListFragment() {

    private val adapter = ListingAdapter { listing ->
        ListingDetailActivity.start(requireContext(), listing.id)
    }

    override val emptyText: String get() = "No listings to moderate."

    override fun onSetup(recycler: RecyclerView) {
        recycler.adapter = adapter
    }

    override fun load() {
        loadInto(
            fetch = { repo.listings() },
            onData = { adapter.submit(it) },
        )
    }
}
