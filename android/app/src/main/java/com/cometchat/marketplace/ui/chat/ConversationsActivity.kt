package com.cometchat.marketplace.ui.chat

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cometchat.chat.models.Group
import com.cometchat.chat.models.User
import com.cometchat.marketplace.chat.ChatManager
import com.cometchat.marketplace.databinding.ActivityConversationsBinding
import com.cometchat.marketplace.ui.repo
import kotlinx.coroutines.launch

/**
 * The Chat surface: the CometChat conversation list. Tapping a conversation opens
 * the full thread ([ChatActivity]) — a 1:1 buyer↔seller thread or the dispute
 * GROUP (buyer+seller+support). Every role reaches the same list: buyers/sellers
 * see their 1:1 threads; support sees the dispute groups it mediates. Calling
 * (voice + video, 1:1 or group) starts from the conversation header.
 *
 * This is a dedicated Activity (not a MainActivity fragment) so it inflates under
 * `Theme.Marketplace.CometChat` — the CometChat Kotlin Views reference cometchat
 * and Material3 attributes that only that theme (applied as a MANIFEST theme, not
 * a runtime overlay) resolves. Same reason ChatActivity is its own themed activity.
 */
class ConversationsActivity : AppCompatActivity() {

    private lateinit var binding: ActivityConversationsBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityConversationsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Ensure chat is up before the list loads (deep entry / cold start).
        lifecycleScope.launch { ChatManager.ensureReady(this@ConversationsActivity, repo) }

        binding.conversations.setOnItemClick { conversation ->
            when (val counterpart = conversation.conversationWith) {
                is User -> ChatActivity.startUser(this, counterpart.uid, counterpart.name)
                is Group -> ChatActivity.startGroup(this, counterpart.guid, counterpart.name)
                else -> Unit
            }
        }
    }
}
