package com.cometchat.marketplace.ui.common

import android.os.Bundle
import android.view.View
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.databinding.ViewListBinding
import com.cometchat.marketplace.ui.toast
import kotlinx.coroutines.launch

/**
 * Shared plumbing for the simple "pull-to-refresh list" screens: wires the
 * RecyclerView, swipe-refresh, progress spinner and empty state, and provides a
 * [loadInto] helper that renders an [Outcome] uniformly.
 */
abstract class BaseListFragment : Fragment(R.layout.view_list) {

    protected lateinit var binding: ViewListBinding
        private set

    /** Text shown when the list loads successfully but is empty. */
    protected open val emptyText: String get() = getString(R.string.empty_generic)

    /** Configure the RecyclerView adapter here. */
    protected abstract fun onSetup(recycler: RecyclerView)

    /** Trigger a (re)load of data. Called on create and on pull-to-refresh. */
    protected abstract fun load()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding = ViewListBinding.bind(view)
        binding.recycler.layoutManager = LinearLayoutManager(requireContext())
        binding.empty.text = emptyText
        binding.root.setOnRefreshListener { load() }
        onSetup(binding.recycler)
        load()
    }

    /**
     * Runs [fetch], then renders: spinner while loading, the mapped list on
     * success (with empty-state toggling), or a toast + empty state on error.
     */
    protected fun <T> loadInto(
        fetch: suspend () -> Outcome<List<T>>,
        onData: (List<T>) -> Unit,
    ) {
        setLoading(true)
        viewLifecycleOwner.lifecycleScope.launch {
            when (val result = fetch()) {
                is Outcome.Success -> {
                    onData(result.data)
                    setLoading(false)
                    binding.empty.visibility = if (result.data.isEmpty()) View.VISIBLE else View.GONE
                }
                is Outcome.Error -> {
                    setLoading(false)
                    binding.empty.visibility = View.VISIBLE
                    toast(result.message)
                }
            }
        }
    }

    private fun setLoading(loading: Boolean) {
        binding.root.isRefreshing = loading
        // Only show the centered spinner on the very first load (empty list).
        binding.progress.visibility =
            if (loading && binding.recycler.adapter?.itemCount == 0) View.VISIBLE else View.GONE
    }
}
