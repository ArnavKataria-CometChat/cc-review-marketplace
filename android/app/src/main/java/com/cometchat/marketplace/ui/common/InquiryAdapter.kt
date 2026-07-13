package com.cometchat.marketplace.ui.common

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.model.Inquiry
import com.cometchat.marketplace.databinding.ItemInquiryBinding

/** Renders an inquiry (buyer↔seller thread anchor). */
class InquiryAdapter(
    private val onClick: (Inquiry) -> Unit,
) : RecyclerView.Adapter<InquiryAdapter.VH>() {

    private val items = mutableListOf<Inquiry>()
    private var titles: Map<String, String> = emptyMap()

    fun submit(inquiries: List<Inquiry>, listingTitles: Map<String, String>) {
        items.clear()
        items.addAll(inquiries)
        titles = listingTitles
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val binding = ItemInquiryBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return VH(binding)
    }

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(items[position])

    inner class VH(private val binding: ItemInquiryBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(inquiry: Inquiry) {
            binding.title.text = titles[inquiry.listingId]
                ?: "Listing ${inquiry.listingId.take(8)}"
            binding.message.text = inquiry.message.ifBlank { "(no opening message)" }

            val ctx = binding.root.context
            if (inquiry.flagged) {
                binding.badge.text = ctx.getString(R.string.badge_disputed)
                binding.badge.setTextColor(ContextCompat.getColor(ctx, R.color.status_flagged))
            } else {
                binding.badge.text = inquiry.status.uppercase()
                binding.badge.setTextColor(ContextCompat.getColor(ctx, R.color.brand_primary))
            }
            binding.subtitle.text = if (inquiry.flagged) {
                ctx.getString(R.string.inquiry_disputed_hint)
            } else {
                ctx.getString(R.string.inquiry_status_hint, inquiry.status)
            }
            binding.root.setOnClickListener { onClick(inquiry) }
        }
    }
}
