import { ChatConversationReferenceScreen } from "@/components/chat-reference/screens";
import { ConversationRoute } from "@/components/chat-routes";
import { getReferenceConversation } from "@/lib/reference-chat";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return getReferenceConversation(id)
    ? <ChatConversationReferenceScreen conversationId={id} />
    : <ConversationRoute conversationId={id} />;
}
