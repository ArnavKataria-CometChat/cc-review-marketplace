// The Chat tab: a CometChat conversation list on the left, the selected
// conversation's message surface (header + list + composer) on the right.
//
// The SAME surface serves every feature: a 1:1 conversation (buyer↔seller) or a
// group conversation (the buyer+seller+support dispute group). The message header
// renders the voice + video call buttons, so calling — 1:1 or group — starts from
// the conversation itself. Support sees the dispute groups here automatically
// (they're a member); buyer/seller see their 1:1 threads.

import { useState } from "react";

import { CometChat } from "@cometchat/chat-sdk-javascript";
import {
  CometChatConversations,
  CometChatMessageComposer,
  CometChatMessageHeader,
  CometChatMessageList,
} from "@cometchat/chat-uikit-react";

import { useCometChat } from "../cometchat/CometChatProvider";

export function MessagesPage() {
  const { ready, error } = useCometChat();
  const [selectedUser, setSelectedUser] = useState<CometChat.User | undefined>();
  const [selectedGroup, setSelectedGroup] = useState<CometChat.Group | undefined>();

  const onItemClick = (conversation: CometChat.Conversation) => {
    const withEntity = conversation.getConversationWith();
    if (withEntity instanceof CometChat.User) {
      setSelectedUser(withEntity);
      setSelectedGroup(undefined);
    } else if (withEntity instanceof CometChat.Group) {
      setSelectedGroup(withEntity);
      setSelectedUser(undefined);
    }
  };

  if (error) {
    return (
      <div className="cc-messages-page">
        <p className="error">Chat is unavailable: {error}</p>
      </div>
    );
  }
  if (!ready) {
    return (
      <div className="cc-messages-page">
        <p>Connecting to chat…</p>
      </div>
    );
  }

  const hasSelection = Boolean(selectedUser || selectedGroup);

  return (
    <div className="cc-messages-page">
      <aside className="cc-conversations">
        <CometChatConversations onItemClick={onItemClick} />
      </aside>
      <section className="cc-thread">
        {hasSelection ? (
          <>
            <CometChatMessageHeader user={selectedUser} group={selectedGroup} />
            <CometChatMessageList user={selectedUser} group={selectedGroup} />
            <CometChatMessageComposer user={selectedUser} group={selectedGroup} />
          </>
        ) : (
          <div className="cc-thread-empty">Select a conversation to start chatting.</div>
        )}
      </section>
    </div>
  );
}
