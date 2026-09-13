import { ConversationRoute } from "@/components/chat-routes";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ConversationRoute conversationId={id} />;
}
