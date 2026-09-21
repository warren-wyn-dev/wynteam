"use client";

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

/**
 * WYNOS Web Beta1, item 7: exercises search-route.tsx's URL-state +
 * debounce mechanics (query/tab live in ?q=/&type=, debounced as-you-type,
 * "ทั้งหมด" default) without a Supabase-backed page — the real
 * SearchInner's tab content needs a live session, but the URL plumbing
 * around it doesn't touch Supabase at all, so this fixture reimplements
 * just that plumbing against a stub content area that echoes the active
 * tab/query for the test to assert on. Test-only, not linked from
 * anywhere in the app.
 */
type SearchTab = "all" | "users" | "posts" | "clubs";
const SEARCH_TABS: readonly SearchTab[] = ["all", "users", "posts", "clubs"];
const SEARCH_DEBOUNCE_MS = 400;

function SearchUrlFixtureInner() {
  const router = useRouter();
  const params = useSearchParams();
  const urlQuery = params.get("q")?.trim() ?? "";
  const urlTabParam = params.get("type");
  const tab: SearchTab = SEARCH_TABS.includes(urlTabParam as SearchTab) ? (urlTabParam as SearchTab) : "all";
  const [draft, setDraft] = useState(urlQuery);

  /* eslint-disable react-hooks/set-state-in-effect -- mirrors the
     identical, lint-clean pattern in search-route.tsx's real SearchInner
     (the React Compiler plugin bails out of this check there because of
     the file's overall complexity; this tiny fixture hits it at full
     strictness for the same, otherwise-ordinary "sync input from the URL,
     an external source" effect). */
  useEffect(() => { setDraft(urlQuery); }, [urlQuery]);
  /* eslint-enable react-hooks/set-state-in-effect */

  const updateUrl = useCallback((nextQuery: string, nextTab: SearchTab) => {
    const qs = new URLSearchParams();
    if (nextQuery) qs.set("q", nextQuery);
    if (nextTab !== "all") qs.set("type", nextTab);
    const suffix = qs.toString();
    router.replace(suffix ? `/dev/search-url-fixture?${suffix}` : "/dev/search-url-fixture");
  }, [router]);

  useEffect(() => {
    const trimmed = draft.trim();
    if (trimmed === urlQuery) return;
    if (trimmed.length > 0 && trimmed.length < 2) return;
    const timer = window.setTimeout(() => updateUrl(trimmed, tab), SEARCH_DEBOUNCE_MS);
    return () => window.clearTimeout(timer);
  }, [draft, urlQuery, tab, updateUrl]);

  const selectTab = (next: SearchTab) => updateUrl(urlQuery, next);
  const submitted = urlQuery.length >= 2;
  const tabs = useMemo(() => [
    { id: "all" as const, label: "ทั้งหมด" },
    { id: "users" as const, label: "User" },
    { id: "posts" as const, label: "โพสต์" },
    { id: "clubs" as const, label: "Club" },
  ], []);

  return (
    <div>
      <input id="search-input" value={draft} onChange={(event) => setDraft(event.target.value)} />
      {submitted ? (
        <div>
          <div role="tablist">
            {tabs.map((item) => (
              <button id={`tab-${item.id}`} key={item.id} type="button" role="tab" aria-selected={tab === item.id} onClick={() => selectTab(item.id)}>
                {item.label}
              </button>
            ))}
          </div>
          <p id="active-state">{tab}:{urlQuery}</p>
        </div>
      ) : (
        <p id="active-state">discovery</p>
      )}
    </div>
  );
}

export function SearchUrlFixture() {
  return (
    <Suspense fallback={null}>
      <SearchUrlFixtureInner />
    </Suspense>
  );
}
