package com.cometchat.marketplace.ui.common

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.model.Report
import com.cometchat.marketplace.databinding.ItemReportBinding
import com.cometchat.marketplace.util.titleCase

/** Renders a moderation/dispute report in the support/admin queue. */
class ReportAdapter(
    private val onClick: (Report) -> Unit,
) : RecyclerView.Adapter<ReportAdapter.VH>() {

    private val items = mutableListOf<Report>()

    fun submit(reports: List<Report>) {
        items.clear()
        items.addAll(reports)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val binding = ItemReportBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return VH(binding)
    }

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: VH, position: Int) = holder.bind(items[position])

    inner class VH(private val binding: ItemReportBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(report: Report) {
            val ctx = binding.root.context
            binding.target.text = ctx.getString(
                R.string.report_target_fmt, report.targetType.titleCase()
            )
            binding.reason.text = report.reason
            binding.status.text = report.status.uppercase()
            val colorRes = when (report.status) {
                "flagged" -> R.color.status_flagged
                "resolved" -> R.color.status_active
                else -> R.color.brand_primary
            }
            binding.status.setTextColor(ContextCompat.getColor(ctx, colorRes))
            binding.meta.text = if (!report.inquiryId.isNullOrEmpty()) {
                ctx.getString(R.string.report_linked_thread)
            } else {
                ctx.getString(R.string.report_no_thread)
            }
            binding.root.setOnClickListener { onClick(report) }
        }
    }
}
