package com.cometchat.marketplace.ui.reports

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.data.remote.ReportDetailResponse
import com.cometchat.marketplace.databinding.ActivityReportDetailBinding
import com.cometchat.marketplace.ui.listings.ListingDetailActivity
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import com.cometchat.marketplace.util.formatPrice
import com.cometchat.marketplace.util.titleCase
import com.google.android.material.button.MaterialButton
import kotlinx.coroutines.launch

/**
 * Report detail for support/admin: shows the report, reporter, the disputed
 * listing, and — when the report is linked to an inquiry — the buyer/seller
 * parties and thread context (GET /reports/:id returns all of this).
 *
 * Advancing to "flagged" escalates the linked inquiry into a dispute; "resolved"
 * clears the flag and closes the thread (PATCH /reports/:id).
 */
class ReportDetailActivity : AppCompatActivity() {

    private lateinit var binding: ActivityReportDetailBinding
    private lateinit var reportId: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityReportDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)
        reportId = intent.getStringExtra(EXTRA_ID).orEmpty()
        binding.toolbar.setNavigationOnClickListener { finish() }
        load()
    }

    private fun load() {
        binding.progress.visibility = View.VISIBLE
        binding.content.visibility = View.GONE
        lifecycleScope.launch {
            when (val result = repo.report(reportId)) {
                is Outcome.Success -> render(result.data)
                is Outcome.Error -> {
                    toast(result.message)
                    finish()
                }
            }
        }
    }

    private fun render(data: ReportDetailResponse) {
        val report = data.report ?: run { finish(); return }
        binding.progress.visibility = View.GONE
        binding.content.visibility = View.VISIBLE

        binding.reportTitle.text = "${report.targetType.titleCase()} report"
        binding.reason.text = report.reason
        binding.statusBadge.text = report.status.uppercase()
        binding.statusBadge.setTextColor(
            ContextCompat.getColor(
                this,
                when (report.status) {
                    "flagged" -> R.color.status_flagged
                    "resolved" -> R.color.status_active
                    else -> R.color.brand_primary
                },
            )
        )
        binding.reporter.text = data.reporter?.let {
            "Reported by ${it.name} (${it.role.wire})"
        } ?: "Reporter ${report.reporterId.take(8)}"

        // Listing context.
        val listing = data.listing
        if (listing != null) {
            binding.listingCard.visibility = View.VISIBLE
            binding.listingTitle.text = "${listing.title} · ${formatPrice(listing.priceCents)}"
            binding.viewListing.setOnClickListener {
                ListingDetailActivity.start(this, listing.id)
            }
        } else {
            binding.listingCard.visibility = View.GONE
        }

        // Thread / parties context (present only for inquiry-linked reports).
        if (data.inquiry != null) {
            binding.threadHeader.visibility = View.VISIBLE
            binding.parties.visibility = View.VISIBLE
            binding.groupSeam.visibility = View.VISIBLE
            val buyer = data.buyer?.name ?: data.inquiry.buyerId.take(8)
            val seller = data.seller?.name ?: data.inquiry.sellerId.take(8)
            val flag = if (data.inquiry.flagged) " · ⚠ disputed" else ""
            binding.parties.text = "Buyer: $buyer\nSeller: $seller\nThread status: ${data.inquiry.status}$flag"
        } else {
            binding.threadHeader.visibility = View.GONE
            binding.parties.visibility = View.GONE
            binding.groupSeam.visibility = View.GONE
        }

        buildActions(report.status)
    }

    private fun buildActions(status: String) {
        val container = binding.actions
        container.removeAllViews()
        when (status) {
            "open" -> {
                addFilled(container, "Flag as dispute") { setStatus("flagged") }
                addOutlined(container, "Resolve") { setStatus("resolved") }
            }
            "flagged" -> {
                addFilled(container, "Resolve dispute") { setStatus("resolved") }
                addOutlined(container, "Move back to open") { setStatus("open") }
            }
            "resolved" -> addNote(container, "This report has been resolved.")
        }
    }

    private fun setStatus(status: String) {
        lifecycleScope.launch {
            when (val r = repo.setReportStatus(reportId, status)) {
                is Outcome.Success -> {
                    toast("Report ${r.data.status}")
                    load()
                }
                is Outcome.Error -> toast(r.message)
            }
        }
    }

    private fun addFilled(container: LinearLayout, text: String, onClick: () -> Unit): MaterialButton {
        val button = layoutInflater.inflate(R.layout.btn_filled, container, false) as MaterialButton
        button.text = text
        button.setOnClickListener { onClick() }
        container.addView(button)
        return button
    }

    private fun addOutlined(container: LinearLayout, text: String, onClick: () -> Unit): MaterialButton {
        val button = layoutInflater.inflate(R.layout.btn_outlined, container, false) as MaterialButton
        button.text = text
        button.setOnClickListener { onClick() }
        container.addView(button)
        return button
    }

    private fun addNote(container: LinearLayout, text: String) {
        val tv = android.widget.TextView(this).apply {
            this.text = text
            setTextColor(ContextCompat.getColor(this@ReportDetailActivity, R.color.text_secondary))
            textSize = 14f
        }
        container.addView(tv)
    }

    companion object {
        private const val EXTRA_ID = "reportId"

        fun start(context: Context, reportId: String) {
            context.startActivity(
                Intent(context, ReportDetailActivity::class.java).putExtra(EXTRA_ID, reportId)
            )
        }
    }
}
