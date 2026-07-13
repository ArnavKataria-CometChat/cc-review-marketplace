package com.cometchat.marketplace.ui.common

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import coil.load
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.model.Listing
import com.cometchat.marketplace.databinding.ItemListingBinding
import com.cometchat.marketplace.util.formatPrice
import com.cometchat.marketplace.util.titleCase

/** Renders a listing card. Used by Browse, My Listings, Favorites and Moderation. */
class ListingAdapter(
    private val onClick: (Listing) -> Unit,
) : RecyclerView.Adapter<ListingAdapter.VH>() {

    private val items = mutableListOf<Listing>()

    fun submit(listings: List<Listing>) {
        items.clear()
        items.addAll(listings)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val binding = ItemListingBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return VH(binding)
    }

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(items[position])

    inner class VH(private val binding: ItemListingBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(listing: Listing) {
            binding.photo.load(listing.photos.firstOrNull()) {
                crossfade(true)
                placeholder(R.drawable.bg_photo_placeholder)
                error(R.drawable.bg_photo_placeholder)
            }
            binding.title.text = listing.title
            binding.price.text = formatPrice(listing.priceCents)
            binding.category.text = listing.category.titleCase()
            binding.status.text = listing.status.uppercase()
            val colorRes = when (listing.status) {
                "sold" -> R.color.status_sold
                "removed" -> R.color.status_removed
                else -> R.color.status_active
            }
            binding.status.setTextColor(ContextCompat.getColor(binding.root.context, colorRes))
            binding.root.setOnClickListener { onClick(listing) }
        }
    }
}
