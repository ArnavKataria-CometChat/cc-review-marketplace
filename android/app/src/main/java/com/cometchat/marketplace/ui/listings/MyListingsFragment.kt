package com.cometchat.marketplace.ui.listings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.databinding.FragmentMyListingsBinding
import com.cometchat.marketplace.ui.common.ListingAdapter
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import kotlinx.coroutines.launch

/**
 * Seller's own listings. The public catalog endpoint is filtered client-side to
 * the current seller's id; the FAB opens the create-listing form. Tapping a card
 * opens the detail screen where the owner can edit or mark it sold.
 */
class MyListingsFragment : Fragment() {

    private var _binding: FragmentMyListingsBinding? = null
    private val binding get() = _binding!!

    private val adapter = ListingAdapter { listing ->
        ListingDetailActivity.start(requireContext(), listing.id)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        _binding = FragmentMyListingsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.listContent.recycler.layoutManager = LinearLayoutManager(requireContext())
        binding.listContent.recycler.adapter = adapter
        binding.listContent.empty.text = "You haven't posted any listings yet.\nTap + to create one."
        binding.listContent.root.setOnRefreshListener { load() }
        binding.fab.setOnClickListener {
            CreateListingActivity.start(requireContext())
        }
    }

    override fun onResume() {
        super.onResume()
        // Refresh when returning from create/detail so new/updated items appear.
        load()
    }

    private fun load() {
        val myId = repo.currentUser?.id ?: return
        binding.listContent.root.isRefreshing = true
        viewLifecycleOwner.lifecycleScope.launch {
            when (val result = repo.listings()) {
                is Outcome.Success -> {
                    val mine = result.data.filter { it.sellerId == myId }
                    adapter.submit(mine)
                    binding.listContent.empty.visibility =
                        if (mine.isEmpty()) View.VISIBLE else View.GONE
                }
                is Outcome.Error -> {
                    binding.listContent.empty.visibility = View.VISIBLE
                    toast(result.message)
                }
            }
            binding.listContent.root.isRefreshing = false
            binding.listContent.progress.visibility = View.GONE
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
