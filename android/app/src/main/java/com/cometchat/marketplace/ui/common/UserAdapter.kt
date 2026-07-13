package com.cometchat.marketplace.ui.common

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.data.model.User
import com.cometchat.marketplace.databinding.ItemUserBinding

/** Admin user moderation row: shows identity/role and ban / change-role actions. */
class UserAdapter(
    private val onToggleBan: (User) -> Unit,
    private val onChangeRole: (User) -> Unit,
) : RecyclerView.Adapter<UserAdapter.VH>() {

    private val items = mutableListOf<User>()

    fun submit(users: List<User>) {
        items.clear()
        items.addAll(users)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val binding = ItemUserBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return VH(binding)
    }

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(items[position])

    inner class VH(private val binding: ItemUserBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(user: User) {
            binding.name.text = user.name
            binding.email.text = user.email
            binding.role.text = user.role.wire.uppercase()
            binding.banButton.text = if (user.banned) "Unban" else "Ban"
            binding.banButton.setOnClickListener { onToggleBan(user) }
            binding.roleButton.setOnClickListener { onChangeRole(user) }
        }
    }
}
