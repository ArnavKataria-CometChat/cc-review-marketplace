package com.cometchat.marketplace.ui.inquiries

import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.ui.common.BaseListFragment
import com.cometchat.marketplace.ui.common.InquiryAdapter
import com.cometchat.marketplace.ui.repo
import kotlinx.coroutines.launch

/**
 * Inquiry threads, scoped by the backend to the caller's role:
 *  - buyer:  inquiries they opened
 *  - seller: inquiries on their listings
 *  - (support/admin reach disputes via the report queue instead)
 *
 * Listing titles are resolved from the public listings feed for nicer labels;
 * the adapter falls back to a short id when a title isn't available.
 */
class InquiriesFragment : BaseListFragment() {

    private val adapter = InquiryAdapter { inquiry ->
        InquiryDetailActivity.start(requireContext(), inquiry.id)
    }

    override val emptyText: String get() = "No inquiries yet."

    override fun onSetup(recycler: RecyclerView) {
        recycler.adapter = adapter
    }

    override fun load() {
        viewLifecycleOwner.lifecycleScope.launch {
            val titles = when (val listings = repo.listings()) {
                is Outcome.Success -> listings.data.associate { it.id to it.title }
                is Outcome.Error -> emptyMap()
            }
            loadInto(
                fetch = { repo.inquiries() },
                onData = { adapter.submit(it, titles) },
            )
        }
    }
}
