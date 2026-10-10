import Link from "next/link";

import { ChatWorkspace } from "@/components/ai/chat-workspace";
import { fetchConversationMessages, fetchSecretaryStatus, listConversations, secretaryEnvironment } from "@/lib/ai/store";
import { cn } from "@/lib/utils";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function AiChatPage({ searchParams }: { searchParams: Promise<{ c?: string }> }) {
  const env = secretaryEnvironment();
  const [status, conversations] = await Promise.all([fetchSecretaryStatus(), listConversations(20)]);
  const requested = (await searchParams).c;
  const conversationId = requested && UUID.test(requested) ? requested : null;
  const history = conversationId ? await fetchConversationMessages(conversationId, 50).catch(() => []) : [];

  const blocker = !env.enabledByEnv
    ? "AI Secretary ยังไม่เปิดใน environment นี้ (ตั้ง AI_SECRETARY_ENABLED=true บน server)"
    : !env.hasProviderKey
      ? "ยังไม่ได้ตั้งค่า AI provider key บน server (ANTHROPIC_API_KEY)"
      : !status.enabled
        ? "AI Secretary ถูกปิดด้วย kill switch — เปิดได้ที่แท็บตั้งค่าและความปลอดภัย"
        : null;

  return (
    <div className="grid gap-4 lg:grid-cols-[220px_1fr]">
      <aside className="flex flex-col gap-2">
        <Link href="/ai" className="min-h-11 rounded-lg border bg-background px-3 py-2.5 text-sm font-medium hover:bg-accent">
          + บทสนทนาใหม่
        </Link>
        <p className="px-1 pt-2 text-xs font-semibold text-muted-foreground">ล่าสุด</p>
        {conversations.length === 0 ? (
          <p className="px-1 text-xs text-muted-foreground">ยังไม่มีบทสนทนา</p>
        ) : (
          <ul className="flex flex-col gap-1">
            {conversations.map((c) => (
              <li key={c.id}>
                <Link
                  href={`/ai?c=${c.id}`}
                  className={cn(
                    "block truncate rounded-md px-3 py-2 text-sm hover:bg-accent",
                    c.id === conversationId && "bg-muted font-medium",
                  )}
                >
                  {c.title}
                </Link>
              </li>
            ))}
          </ul>
        )}
        <p className="px-1 pt-2 text-[11px] text-muted-foreground">บทสนทนาเก็บ 90 วันแล้วลบอัตโนมัติ</p>
      </aside>

      <section className="flex min-w-0 flex-col gap-3">
        <p className="text-xs text-muted-foreground">
          โควตาวันนี้: {status.tokensUsedToday.toLocaleString()} / {status.dailyTokenLimit.toLocaleString()} tokens
        </p>
        {blocker ? (
          <p role="status" className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
            {blocker}
          </p>
        ) : (
          <ChatWorkspace
            key={conversationId ?? "new"}
            initialConversationId={conversationId}
            initialTurns={history.map((m) => ({ role: m.role, text: m.content }))}
          />
        )}
      </section>
    </div>
  );
}
