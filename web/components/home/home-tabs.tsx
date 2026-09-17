export type HomeFeedMode = "for-you" | "following" | "clubs";

export const HOME_FEED_MODES: { key: HomeFeedMode; label: string }[] = [
  { key: "for-you", label: "สำหรับคุณ" },
  { key: "following", label: "กำลังติดตาม" },
  { key: "clubs", label: "คลับของฉัน" },
];

/**
 * Home feed-mode toggle. Keeps the same three destinations and swipe/tap
 * behavior while presenting them as a quiet Threads-like tab strip: no
 * segmented pill, only typography plus a slim active underline.
 */
export function HomeTabs({
  mode,
  onSelect,
}: {
  mode: HomeFeedMode;
  onSelect: (mode: HomeFeedMode) => void;
}) {
  return (
    <div className="wyn-home-tabs" role="tablist" aria-label="ฟีด">
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
          >
            <span className="wyn-home-tab-label">{item.label}</span>
            <span className="wyn-home-tab-indicator" aria-hidden="true" />
          </button>
        );
      })}
    </div>
  );
}
