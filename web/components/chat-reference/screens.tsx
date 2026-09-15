"use client";

import { useRouter } from "next/navigation";
import type { ReactNode } from "react";

import { Avatar, BottomNav, WynosIcon } from "@/components/ui";
import { getReferenceConversation, referenceConversations } from "@/lib/reference-chat";

function ReferencePhone({ children }: { children: ReactNode }) {
  return <main className="content-ref-viewport"><div className="phone" id="phone">{children}</div></main>;
}

export function ChatListReferenceScreen() {
  const router = useRouter();
  return (
    <ReferencePhone>
      <div className="topbar"><span className="t">แชท</span><span /></div>
      <div className="chat-list-scroll">
        {referenceConversations.map((conversation) => (
          <button
            className={`chat-list-row${conversation.unread ? " unread" : ""}`}
            data-conversation-id={conversation.id}
            key={conversation.id}
            onClick={() => router.push(`/chat/${conversation.id}`)}
            type="button"
          >
            <Avatar as="div" alt={`รูปโปรไฟล์ของ ${conversation.name}`} className="avatar" size={46} />
            <div className="chat-list-copy">
              <div className="chat-list-meta"><span>{conversation.name}</span><time>{conversation.listTime}</time></div>
              <p>{conversation.preview}</p>
            </div>
          </button>
        ))}
      </div>
      <BottomNav active="chat" className="bottomnav" homeHref="/home" clubsHref="/clubs" postHref="/compose-post" chatHref="/chat" profileHref="/profile/me" />
    </ReferencePhone>
  );
}

export function ChatConversationReferenceScreen({ conversationId }: { conversationId: string }) {
  const router = useRouter();
  const conversation = getReferenceConversation(conversationId);
  if (!conversation) return null;
  const statusLabel = conversation.status === "read" ? "อ่านแล้ว" : "ส่งแล้ว";

  return (
    <ReferencePhone>
      <div className="topbar chat-conversation-topbar">
        <button className="ic-btn" onClick={() => router.push("/chat")} aria-label="ย้อนกลับ" type="button"><WynosIcon name="back" size={18} /></button>
        <Avatar as="div" alt={`รูปโปรไฟล์ของ ${conversation.name}`} className="avatar" size={30} />
        <span className="t">{conversation.name}</span>
      </div>
      <div className="chat-conversation-scroll" data-conversation-id={conversation.id}>
        <div className="chat-bubble-wrap incoming"><div className="chat-bubble incoming">{conversation.incomingText}</div></div>
        <div className="chat-bubble-wrap outgoing">
          <div className="chat-bubble outgoing">{conversation.outgoingText}</div>
          <div className={`chat-message-status ${conversation.status}`} data-message-status={conversation.status}>{conversation.messageTime} · {statusLabel}</div>
        </div>
      </div>
      <div className="chat-composer"><div>พิมพ์ข้อความ...</div></div>
    </ReferencePhone>
  );
}
