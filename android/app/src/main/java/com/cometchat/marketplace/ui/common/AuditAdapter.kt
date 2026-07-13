package com.cometchat.marketplace.ui.common

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.data.model.AuditEntry
import com.cometchat.marketplace.databinding.ItemAuditBinding

/** Read-only admin audit log rows (most recent first, as returned by the API). */
class AuditAdapter : RecyclerView.Adapter<AuditAdapter.VH>() {

    private val items = mutableListOf<AuditEntry>()

    fun submit(entries: List<AuditEntry>) {
        items.clear()
        items.addAll(entries)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val binding = ItemAuditBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return VH(binding)
    }

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(items[position])

    inner class VH(private val binding: ItemAuditBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(entry: AuditEntry) {
            binding.action.text = entry.action
            binding.details.text = entry.details.ifBlank { "—" }
            binding.actor.text = "${entry.actorRole.wire} · target ${entry.target.take(8)}"
        }
    }
}
