package com.cometchat.marketplace.ui.admin

import androidx.appcompat.app.AlertDialog
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.data.model.Role
import com.cometchat.marketplace.data.model.User
import com.cometchat.marketplace.ui.common.BaseListFragment
import com.cometchat.marketplace.ui.common.UserAdapter
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import kotlinx.coroutines.launch

/** Admin moderation of users: ban/unban and role changes (GET/PATCH /admin/users). */
class AdminUsersFragment : BaseListFragment() {

    private val adapter = UserAdapter(
        onToggleBan = { user -> toggleBan(user) },
        onChangeRole = { user -> promptRole(user) },
    )

    override val emptyText: String get() = "No users."

    override fun onSetup(recycler: RecyclerView) {
        recycler.adapter = adapter
    }

    override fun load() {
        loadInto(
            fetch = { repo.adminUsers() },
            onData = { adapter.submit(it) },
        )
    }

    private fun toggleBan(user: User) {
        viewLifecycleOwner.lifecycleScope.launch {
            when (val r = repo.adminPatchUser(user.id, banned = !user.banned)) {
                is Outcome.Success -> {
                    toast(if (r.data.banned) "User banned" else "User unbanned")
                    load()
                }
                is Outcome.Error -> toast(r.message)
            }
        }
    }

    private fun promptRole(user: User) {
        val roles = Role.values()
        val labels = roles.map { it.label }.toTypedArray()
        AlertDialog.Builder(requireContext())
            .setTitle("Set role for ${user.name}")
            .setItems(labels) { _, which ->
                val newRole = roles[which]
                viewLifecycleOwner.lifecycleScope.launch {
                    when (val r = repo.adminPatchUser(user.id, role = newRole.wire)) {
                        is Outcome.Success -> {
                            toast("Role updated to ${r.data.role.label}")
                            load()
                        }
                        is Outcome.Error -> toast(r.message)
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}
