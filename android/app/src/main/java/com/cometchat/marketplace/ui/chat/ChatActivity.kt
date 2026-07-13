package com.cometchat.marketplace.ui.chat

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cometchat.chat.core.CometChat
import com.cometchat.chat.exceptions.CometChatException
import com.cometchat.chat.models.Group
import com.cometchat.chat.models.User
import com.cometchat.marketplace.chat.ChatManager
import com.cometchat.marketplace.databinding.ActivityChatBinding
import com.cometchat.marketplace.ui.repo
import com.cometchat.marketplace.ui.toast
import kotlinx.coroutines.launch

/**
 * The CometChat conversation surface, hosting the message header + list +
 * composer and an app-root incoming-call overlay.
 *
 * Two modes, keyed the way the backend keys conversations:
 *  - 1:1  (EXTRA_UID)  — a buyer↔seller thread anchored to an inquiry. Only the
 *    listing's buyer and seller ever reach this (the inquiry screen gates it).
 *  - group (EXTRA_GUID) — a dispute group "dispute-<inquiryId>" (buyer + seller +
 *    support) that the backend provisions when a report is flagged.
 *
 * The header renders the voice + video call buttons (forced visible below), so
 * calling — 1:1 or group — starts from the conversation itself.
 */
class ChatActivity : AppCompatActivity() {

    private lateinit var binding: ActivityChatBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityChatBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.messageHeader.setOnBackPress { finish() }

        val uid = intent.getStringExtra(EXTRA_UID)
        val guid = intent.getStringExtra(EXTRA_GUID)
        if (uid.isNullOrBlank() && guid.isNullOrBlank()) {
            toast("Conversation unavailable")
            finish()
            return
        }

        binding.progress.visibility = View.VISIBLE
        lifecycleScope.launch {
            // Chat may not be logged in yet (deep entry, cold start) — bring it up.
            if (!ChatManager.ensureReady(this@ChatActivity, repo)) {
                toast("Chat is unavailable right now")
                finish()
                return@launch
            }
            if (!uid.isNullOrBlank()) loadUser(uid) else loadGroup(guid!!)
        }
    }

    private fun loadUser(uid: String) {
        CometChat.getUser(uid, object : CometChat.CallbackListener<User>() {
            override fun onSuccess(user: User) = bindUser(user)
            override fun onError(e: CometChatException?) {
                // Fall back to a locally-built user so the thread still renders
                // (e.g. the counterpart hasn't opened a chat build yet).
                bindUser(User().apply { setUid(uid); setName(intent.getStringExtra(EXTRA_TITLE) ?: uid) })
            }
        })
    }

    private fun bindUser(user: User) {
        if (isFinishing) return
        binding.progress.visibility = View.GONE
        binding.messageHeader.setUser(user)
        binding.messageList.setUser(user)
        binding.messageComposer.setUser(user)
        showCallButtons()
    }

    private fun loadGroup(guid: String) {
        CometChat.getGroup(guid, object : CometChat.CallbackListener<Group>() {
            override fun onSuccess(group: Group) = bindGroup(group)
            override fun onError(e: CometChatException?) {
                toast("Dispute chat is not available yet")
                finish()
            }
        })
    }

    private fun bindGroup(group: Group) {
        if (isFinishing) return
        binding.progress.visibility = View.GONE
        binding.messageHeader.setGroup(group)
        binding.messageList.setGroup(group)
        binding.messageComposer.setGroup(group)
        showCallButtons()
    }

    /**
     * The v6 message header hides the call buttons by default in this UI Kit
     * version; force them visible so users can start a voice/video call from the
     * thread. (Calling was enabled at init via setEnableCalling(true).)
     */
    private fun showCallButtons() {
        binding.messageHeader.setVoiceCallButtonVisibility(View.VISIBLE)
        binding.messageHeader.setVideoCallButtonVisibility(View.VISIBLE)
    }

    companion object {
        private const val EXTRA_UID = "uid"
        private const val EXTRA_GUID = "guid"
        private const val EXTRA_TITLE = "title"

        /** Open a 1:1 chat with [uid] (the inquiry counterpart). */
        fun startUser(context: Context, uid: String, title: String? = null) {
            context.startActivity(
                Intent(context, ChatActivity::class.java)
                    .putExtra(EXTRA_UID, uid)
                    .putExtra(EXTRA_TITLE, title)
            )
        }

        /** Open the dispute group [guid] ("dispute-<inquiryId>"). */
        fun startGroup(context: Context, guid: String, title: String? = null) {
            context.startActivity(
                Intent(context, ChatActivity::class.java)
                    .putExtra(EXTRA_GUID, guid)
                    .putExtra(EXTRA_TITLE, title)
            )
        }
    }
}
