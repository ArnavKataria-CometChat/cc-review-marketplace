package com.cometchat.marketplace.ui.reports

import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.ui.common.BaseListFragment
import com.cometchat.marketplace.ui.common.ReportAdapter
import com.cometchat.marketplace.ui.repo

/**
 * The moderation/dispute queue (GET /reports), available to support and admin.
 * Tapping a report opens its full context (listing + parties + thread anchor).
 */
class DisputeQueueFragment : BaseListFragment() {

    private val adapter = ReportAdapter { report ->
        ReportDetailActivity.start(requireContext(), report.id)
    }

    override val emptyText: String get() = "The dispute queue is empty."

    override fun onSetup(recycler: RecyclerView) {
        recycler.adapter = adapter
    }

    override fun load() {
        loadInto(
            fetch = { repo.reports() },
            onData = { adapter.submit(it) },
        )
    }
}
