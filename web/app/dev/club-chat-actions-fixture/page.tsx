import { notFound } from "next/navigation";
import { ClubChatActionsFixture } from "@/components/dev/club-chat-actions-fixture";

// Local browser QA only. Never expose in a hosted preview or production.
export default function ClubChatActionsFixturePage() {
  if (process.env.NODE_ENV !== "development") notFound();
  return <ClubChatActionsFixture />;
}
