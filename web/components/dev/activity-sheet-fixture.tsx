"use client";

import { useState } from "react";

/**
 * WYNOS Web Beta1, item 8: reproduces ActivitySheet's (post-detail-route.tsx)
 * 5-tab structure — Views/Saves are count-only (drop_views/saves are both
 * RLS-scoped so no name list exists to show, even to the post's own
 * author), Likes/Comments/Reposts show a person list — without a
 * Supabase-backed page. Test-only, not linked from anywhere in the app.
 */
type Tab = "views" | "likes" | "comments" | "redrops" | "saves";
const TABS: { id: Tab; label: string; count: number }[] = [
  { id: "views", label: "ยอดดู", count: 42 },
  { id: "likes", label: "ถูกใจ", count: 2 },
  { id: "comments", label: "ความคิดเห็น", count: 1 },
  { id: "redrops", label: "รีโพสต์", count: 0 },
  { id: "saves", label: "บันทึก", count: 5 },
];
const PEOPLE: Record<"likes" | "comments" | "redrops", { id: string; username: string }[]> = {
  likes: [{ id: "u1", username: "alice" }, { id: "u2", username: "bob" }],
  comments: [{ id: "u3", username: "carol" }],
  redrops: [],
};

export function ActivitySheetFixture() {
  const [tab, setTab] = useState<Tab>("views");
  const isListTab = tab === "likes" || tab === "comments" || tab === "redrops";
  const activeCount = TABS.find((item) => item.id === tab)?.count ?? 0;
  return (
    <div>
      <div role="tablist">
        {TABS.map((item) => (
          <button id={`tab-${item.id}`} key={item.id} type="button" role="tab" aria-selected={tab === item.id} onClick={() => setTab(item.id)}>
            {item.label} ({item.count})
          </button>
        ))}
      </div>
      <div id="activity-content">
        {!isListTab ? (
          <div id="count-only">
            <strong>{activeCount}</strong>
            <span>{tab === "views" ? "คนดูโพสต์นี้ (นับแบบไม่ซ้ำคน)" : "คนบันทึกโพสต์นี้"}</span>
          </div>
        ) : PEOPLE[tab].length ? (
          <div id="person-list">
            {PEOPLE[tab].map((person) => <a href={`/profile/${person.id}`} key={person.id}>@{person.username}</a>)}
          </div>
        ) : (
          <p id="empty-state">ยังไม่มีข้อมูล</p>
        )}
      </div>
    </div>
  );
}
