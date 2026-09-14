export type HomeFeedMode = "for-you" | "following" | "clubs";

export const HOME_FEED_MODES: { key: HomeFeedMode; label: string }[] = [
  { key: "for-you", label: "สำหรับคุณ" },
  { key: "following", label: "กำลังติดตาม" },
  { key: "clubs", label: "คลับของฉัน" },
];

/** Home's feed-mode toggle — WynosSocialTabs (height 52, 14px labels,
 * 700/500 weight, 36x2 ink indicator under the active label). */
export function HomeTabs({
  mode,
  onSelect,
}: {
  mode: HomeFeedMode;
  onSelect: (mode: HomeFeedMode) => void;
}) {
  return (
    <div className="wyn-home-tabs" role="tablist" aria-label="ฟีด">
      {HOME_FEED_MODES.map((item) => (
        <button
          type="button"
          role="tab"
          aria-selected={mode === item.key}
          className={`wyn-home-tab ${mode === item.key ? "is-active" : ""}`}
          onClick={() => onSelect(item.key)}
          key={item.key}
        >
          <span className="wyn-home-tab-label">{item.label}</span>
          <span className="wyn-home-tab-indicator" />
        </button>
      ))}
    </div>
  );
}
