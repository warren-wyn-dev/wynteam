import { WynosTabs } from "@/components/design-system/WynosTabs";

export type HomeFeedMode = "for-you" | "following" | "clubs";

export const HOME_FEED_MODES: { key: HomeFeedMode; label: string }[] = [
  { key: "for-you", label: "สำหรับคุณ" },
  { key: "following", label: "กำลังติดตาม" },
  { key: "clubs", label: "คลับของฉัน" },
];

/** Home's feed-mode toggle (WYN-159 design system, `WynosTabs` — `.tabs`/
 * `.tab` in the reference: 14px labels, 18px gap, active tab underlined). */
export function HomeTabs({
  mode,
  onSelect,
}: {
  mode: HomeFeedMode;
  onSelect: (mode: HomeFeedMode) => void;
}) {
  return <WynosTabs items={HOME_FEED_MODES} activeKey={mode} onSelect={onSelect} ariaLabel="ฟีด" />;
}
