package com.cometchat.marketplace.ui.inquiries

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.cometchat.marketplace.R
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.data.model.Inquiry
import com.cometchat.marketplace.data.remote.CreateReportRequest
import com.cometchat.marketplace.databinding.ActivityInquiryDetailBinding
import com.cometchat.marketplace.ui.chat.ChatActivity
import com.cometchat.marketplace.ui.listings.ListingDetailActivity
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import com.cometchat.marketplace.util.formatPrice
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import kotlinx.coroutines.launch

/**
 * Inquiry thread detail: the buyer↔seller anchor a Phase B CometChat 1:1 chat
 * and voice call will attach to. A participant can close/reopen the thread and
 * file a dispute report (which links this inquiry so support gets full context
 * and can escalate it to a buyer+seller+support group).
 *
 * The backend exposes no GET /inquiries/:id, so the inquiry is resolved from the
 * role-scoped GET /inquiries list.
 */
class InquiryDetailActivity : AppCompatActivity() {

    private lateinit var binding: ActivityInquiryDetailBinding
    private lateinit var inquiryId: String
    private var inquiry: Inquiry? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityInquiryDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)
        inquiryId = intent.getStringExtra(EXTRA_ID).orEmpty()
        binding.toolbar.setNavigationOnClickListener { finish() }
        load()
    }

    private fun load() {
        binding.progress.visibility = View.VISIBLE
        binding.content.visibility = View.GONE
        lifecycleScope.launch {
            when (val result = repo.inquiries()) {
                is Outcome.Success -> {
                    val found = result.data.firstOrNull { it.id == inquiryId }
                    if (found == null) {
                        toast("Inquiry not found")
                        finish()
                    } else {
                        inquiry = found
                        render(found)
                    }
                }
                is Outcome.Error -> {
                    toast(result.message)
                    finish()
                }
            }
        }
    }

    private fun render(inq: Inquiry) {
        binding.progress.visibility = View.GONE
        binding.content.visibility = View.VISIBLE

        binding.message.text = inq.message.ifBlank { "(no opening message)" }
        binding.toolbar.title = if (inq.flagged) "Inquiry · Disputed" else "Inquiry"

        val me = repo.currentUser?.id
        val youAre = when (me) {
            inq.buyerId -> "You are the buyer"
            inq.sellerId -> "You are the seller"
            else -> "Viewing as ${repo.currentUser?.role?.wire}"
        }
        val statusLine = if (inq.flagged) {
            "$youAre · status: ${inq.status} · ⚠ escalated to a dispute"
        } else {
            "$youAre · status: ${inq.status}"
        }
        binding.parties.text = statusLine

        binding.viewListing.setOnClickListener {
            ListingDetailActivity.start(this, inq.listingId)
        }
        // Resolve the listing for a friendlier header (best-effort).
        binding.listingTitle.text = "Listing ${inq.listingId.take(8)}"
        lifecycleScope.launch {
            (repo.listing(inq.listingId) as? Outcome.Success)?.data?.let { l ->
                binding.listingTitle.text = l.title
                binding.listingPrice.text = formatPrice(l.priceCents)
            }
        }

        wireChat(inq)
        buildActions(inq)
    }

    /**
     * The CometChat 1:1 seam: only this listing's buyer and seller may chat/call,
     * and only with each other. Message and Call both open the inquiry's
     * conversation, whose header hosts the voice + video call buttons.
     */
    private fun wireChat(inq: Inquiry) {
        val me = repo.currentUser?.id
        val counterpartId = when (me) {
            inq.buyerId -> inq.sellerId
            inq.sellerId -> inq.buyerId
            else -> null
        }
        val enabled = !counterpartId.isNullOrBlank()
        binding.chatButton.isEnabled = enabled
        binding.callButton.isEnabled = enabled
        if (enabled) {
            val open = { ChatActivity.startUser(this, counterpartId!!) }
            binding.chatButton.setOnClickListener { open() }
            binding.callButton.setOnClickListener { open() }
        }
    }

    private fun buildActions(inq: Inquiry) {
        val container = binding.actions
        container.removeAllViews()
        val me = repo.currentUser?.id
        val isParticipant = me == inq.buyerId || me == inq.sellerId

        if (!isParticipant) {
            addNote(container, "You are not a participant of this thread.")
            return
        }

        if (inq.status == "open") {
            addOutlined(container, "Close inquiry") { setStatus("closed") }
        } else {
            addOutlined(container, "Reopen inquiry") { setStatus("open") }
        }
        addOutlined(container, "Report a problem") { promptDispute(inq) }
    }

    private fun setStatus(status: String) {
        lifecycleScope.launch {
            when (val r = repo.setInquiryStatus(inquiryId, status)) {
                is Outcome.Success -> {
                    inquiry = r.data
                    toast("Inquiry ${r.data.status}")
                    render(r.data)
                }
                is Outcome.Error -> toast(r.message)
            }
        }
    }

    private fun promptDispute(inq: Inquiry) {
        val input = TextInputEditText(this).apply {
            hint = "Describe the problem"
            setPadding(48, 32, 48, 32)
        }
        AlertDialog.Builder(this)
            .setTitle("Report a problem")
            .setMessage("This files a dispute linked to this inquiry. Support can then review the thread and escalate it if needed.")
            .setView(input)
            .setPositiveButton("Submit") { _, _ ->
                val reason = input.text?.toString()?.trim().orEmpty()
                if (reason.isEmpty()) {
                    toast("Please describe the problem")
                    return@setPositiveButton
                }
                lifecycleScope.launch {
                    val req = CreateReportRequest(
                        targetType = "listing",
                        targetId = inq.listingId,
                        reason = reason,
                        inquiryId = inq.id,
                    )
                    when (val r = repo.createReport(req)) {
                        is Outcome.Success -> toast("Dispute filed with support")
                        is Outcome.Error -> toast(r.message)
                    }
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
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
            setTextColor(ContextCompat.getColor(this@InquiryDetailActivity, R.color.text_secondary))
            textSize = 14f
        }
        container.addView(tv)
    }

    companion object {
        private const val EXTRA_ID = "inquiryId"

        fun start(context: Context, inquiryId: String) {
            context.startActivity(
                Intent(context, InquiryDetailActivity::class.java).putExtra(EXTRA_ID, inquiryId)
            )
        }
    }
}
