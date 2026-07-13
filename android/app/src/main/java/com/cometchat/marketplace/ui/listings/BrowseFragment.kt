package com.cometchat.marketplace.ui.listings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import androidx.core.widget.addTextChangedListener
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.databinding.FragmentBrowseBinding
import com.cometchat.marketplace.ui.common.ListingAdapter
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import com.cometchat.marketplace.util.titleCase
import com.google.android.material.chip.Chip
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Public catalog browsing (GET /listings?search=&category=). This is the buyer's
 * primary entry point: debounced text search plus a category filter, tapping a
 * card into the listing detail where an inquiry can be opened.
 */
class BrowseFragment : Fragment() {

    private var _binding: FragmentBrowseBinding? = null
    private val binding get() = _binding!!

    private val adapter = ListingAdapter { listing ->
        ListingDetailActivity.start(requireContext(), listing.id)
    }

    private var category: String? = null
    private var searchJob: Job? = null
    private var knownCategories = listOf<String>()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        _binding = FragmentBrowseBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.listContent.recycler.layoutManager = LinearLayoutManager(requireContext())
        binding.listContent.recycler.adapter = adapter
        binding.listContent.empty.text = "No listings match your search."
        binding.listContent.root.setOnRefreshListener { load() }

        binding.searchInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEARCH) {
                load()
                true
            } else {
                false
            }
        }
        // Debounced search-as-you-type.
        binding.searchInput.addTextChangedListener { scheduleSearch() }

        setupCategoryChips()
        load()
    }

    private fun setupCategoryChips() {
        binding.categoryGroup.setOnCheckedStateChangeListener { group, ids ->
            val id = ids.firstOrNull() ?: return@setOnCheckedStateChangeListener
            val chip = group.findViewById<Chip>(id)
            category = (chip?.tag as? String)?.ifBlank { null }
            load()
        }
        rebuildChips()
    }

    private fun rebuildChips() {
        binding.categoryGroup.removeAllViews()
        val all = listOf("" to "All") + knownCategories.map { it to it.titleCase() }
        all.forEachIndexed { index, (value, label) ->
            val chip = Chip(requireContext()).apply {
                text = label
                tag = value
                isCheckable = true
                isChecked = index == 0 && category == null
            }
            binding.categoryGroup.addView(chip)
        }
    }

    private fun scheduleSearch() {
        searchJob?.cancel()
        searchJob = viewLifecycleOwner.lifecycleScope.launch {
            delay(350)
            load()
        }
    }

    private fun load() {
        val query = binding.searchInput.text?.toString()?.trim().orEmpty()
        binding.listContent.root.isRefreshing = true
        viewLifecycleOwner.lifecycleScope.launch {
            when (val result = repo.listings(search = query, category = category)) {
                is Outcome.Success -> {
                    adapter.submit(result.data)
                    binding.listContent.empty.visibility =
                        if (result.data.isEmpty()) View.VISIBLE else View.GONE
                    maybeUpdateCategories(result.data.map { it.category })
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

    // Seed the category filter from whatever categories appear in an unfiltered
    // result, so the chips reflect the live catalog without a dedicated endpoint.
    private fun maybeUpdateCategories(categories: List<String>) {
        if (category != null) return
        val distinct = categories.filter { it.isNotBlank() }.distinct().sorted()
        if (distinct.isNotEmpty() && distinct != knownCategories) {
            knownCategories = distinct
            rebuildChips()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
