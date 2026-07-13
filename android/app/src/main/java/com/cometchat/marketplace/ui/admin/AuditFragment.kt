package com.cometchat.marketplace.ui.admin

import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.ui.common.AuditAdapter
import com.cometchat.marketplace.ui.common.BaseListFragment
import com.cometchat.marketplace.ui.repo

/** Read-only admin audit log of privileged actions (GET /admin/audit). */
class AuditFragment : BaseListFragment() {

    private val adapter = AuditAdapter()

    override val emptyText: String get() = "No audit entries yet."

    override fun onSetup(recycler: RecyclerView) {
        recycler.adapter = adapter
    }

    override fun load() {
        loadInto(
            fetch = { repo.adminAudit() },
            onData = { adapter.submit(it) },
        )
    }
}
