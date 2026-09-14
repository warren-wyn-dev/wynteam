/* eslint-disable @next/next/no-img-element */
import { Menu, MessageSquare } from "lucide-react";

/**
 * Home's header — WynosSocialHeader overridden to height 52 with no
 * bottom divider (home_feed_screen.dart's `_buildHeader`). The chat
 * icon is Lucide's MessageSquare (a single rounded-rect bubble with a
 * tail), matching Flutter's Icons.chat_bubble_outline shape — the
 * previous implementation used Lucide's MessagesSquare (two overlapping
 * bubbles), a visibly different glyph that needed a CSS mask patch to
 * paint over; fixed at the source instead.
 */
export function HomeHeader({
  chatBadgeCount,
  onOpenMenu,
  onOpenChat,
}: {
  chatBadgeCount: number;
  onOpenMenu: () => void;
  onOpenChat: () => void;
}) {
  return (
    <header className="wyn-home-header">
      <button className="wyn-home-header-action" type="button" aria-label="เมนู" onClick={onOpenMenu}>
        <Menu />
      </button>
      <div className="wyn-home-wordmark">
        <img className="wyn-home-logo" src="/wynos_logo_mark.png" alt="" />
        <strong className="wyn-home-title">WYNOS</strong>
      </div>
      <button
        className="wyn-home-header-action wyn-home-chat-action"
        type="button"
        aria-label="แชท"
        onClick={onOpenChat}
      >
        <MessageSquare />
        {chatBadgeCount > 0 ? (
          <span className="wyn-home-chat-badge">{chatBadgeCount > 9 ? "9+" : chatBadgeCount}</span>
        ) : null}
      </button>
    </header>
  );
}
