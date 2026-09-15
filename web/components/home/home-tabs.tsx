export type HomeFeedMode = "for-you" | "following" | "clubs";

export const HOME_FEED_MODES: { key: HomeFeedMode; label: string }[] = [
  { key: "for-you", label: "สำหรับคุณ" },
  { key: "following", label: "กำลังติดตาม" },
  { key: "clubs", label: "คลับของฉัน" },
];

/**
 * Home feed-mode toggle. Keeps the same three destinations but uses a softer
 * segmented treatment instead of the old long underline, matching the current
 * WYNOS minimal-premium direction.
 */
export function HomeTabs({
  mode,
  onSelect,
}: {
  mode: HomeFeedMode;
  onSelect: (mode: HomeFeedMode) => void;
}) {
  return (
    <div
      className="wyn-home-tabs"
      role="tablist"
      aria-label="ฟีด"
      style={{
        height: 44,
        padding: "3px 10px 5px",
        gap: 4,
        boxSizing: "border-box",
      }}
    >
      {HOME_FEED_MODES.map((item) => {
        const active = mode === item.key;
        return (
          <button
            type="button"
            role="tab"
            aria-selected={active}
            className={`wyn-home-tab ${active ? "is-active" : ""}`}
            onClick={() => onSelect(item.key)}
            key={item.key}
            style={{
              height: "100%",
              borderRadius: 12,
              background: active ? "var(--wyn-surface)" : "transparent",
              color: active ? "var(--wyn-text)" : "var(--wyn-text-secondary)",
              fontSize: 16,
              fontWeight: active ? 700 : 600,
              transition: "background-color 140ms ease, color 140ms ease",
            }}
          >
            <span
              className="wyn-home-tab-label"
              style={{
                flex: "1 1 auto",
                width: "100%",
                justifyContent: "center",
              }}
            >
              {item.label}
            </span>
            <span className="wyn-home-tab-indicator" style={{ display: "none" }} />
          </button>
        );
      })}
    </div>
  );
}
