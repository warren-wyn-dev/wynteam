import { notFound } from "next/navigation";

import { ChatThreadsFixture } from "@/components/dev/chat-threads-fixture";

// WYN-159 is Beta2 (developer-only): this preview exists only for next dev
// and Playwright, never as a production route.
export default function ChatThreadsFixturePage() {
  if (process.env.NODE_ENV !== "development") notFound();
  return <ChatThreadsFixture />;
}
