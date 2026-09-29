import Link from "next/link";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { FIRST_POST_PROMPTS, dailyPostingPrompt } from "@/lib/posting-prompts";

/**
 * Home's quiet posting entry point. New users get a clear first-post path;
 * everyone else gets one rotating daily prompt. Every action opens the same
 * Beta4 composer, so drafts/polls/images/publication safety stay centralized.
 */
export function HomeQuickCompose({
  avatarUrl,
  username,
  hasPublishedPost,
}: {
  avatarUrl?: string | null;
  username?: string | null;
  hasPublishedPost: boolean;
}) {
  if (!hasPublishedPost) {
    return (
      <section className="wyn-home-first-post" aria-label="เริ่มโพสต์แรกของคุณ">
        <div className="wyn-home-first-post-head">
          <span className="wyn-home-first-post-avatar" aria-hidden="true">
            <Avatar src={avatarUrl} label={username || "คุณ"} size={42} />
          </span>
          <span className="wyn-home-first-post-copy">
            <strong>เริ่มโพสต์แรกของคุณ ✨</strong>
            <small>ไม่ต้องคิดเยอะ เลือกหัวข้อหนึ่งแล้วเริ่มเขียนได้เลย</small>
          </span>
        </div>
        <div className="wyn-home-first-post-prompts" role="list">
          {FIRST_POST_PROMPTS.map((prompt) => (
            <Link
              key={prompt.key}
              role="listitem"
              className="wyn-home-first-post-chip"
              href={`/?compose=1&prompt=${encodeURIComponent(prompt.key)}`}
            >
              {prompt.text}
            </Link>
          ))}
        </div>
        <Link className="wyn-home-first-post-button" href="/?compose=1&prompt=first-intro">
          สร้างโพสต์แรก
        </Link>
      </section>
    );
  }

  const prompt = dailyPostingPrompt();
  return (
    <Link
      className="wyn-home-quick-compose"
      href={`/?compose=1&prompt=${encodeURIComponent(prompt.key)}`}
      aria-label={`สร้างโพสต์ ${prompt.text}`}
    >
      <span className="wyn-home-quick-compose-avatar" aria-hidden="true">
        <Avatar src={avatarUrl} label={username || "คุณ"} size={38} />
      </span>
      <span className="wyn-home-quick-compose-copy">
        <small>หัวข้อวันนี้</small>
        <span className="wyn-home-quick-compose-prompt">{prompt.text}</span>
      </span>
      <WynosIcon name="compose" className="wyn-home-quick-compose-image" size={21} strokeWidth={1.8} />
    </Link>
  );
}
