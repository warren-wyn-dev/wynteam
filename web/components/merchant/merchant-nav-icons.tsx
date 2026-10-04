/**
 * WYN-208: Wynos Merchant's own bottom-bar icons. Each one has two states:
 * an outline while not selected, and a solid Wynos-red shape with white
 * details when selected, so the current tab reads at a glance.
 */
export type MerchantNavIconName = "home" | "orders" | "menu" | "more";

const RED = "#e32636";

export function MerchantNavIcon({ name, active }: { name: MerchantNavIconName; active: boolean }) {
  const stroke = active ? RED : "currentColor";
  const fill = active ? RED : "none";
  const detail = active ? "#fff" : "currentColor";
  return (
    <svg className="wm-nav-svg" width="26" height="26" viewBox="0 0 26 26" fill="none" aria-hidden="true" focusable="false">
      {name === "home" ? (
        // Storefront: awning with scallops over a shop with a door.
        <>
          <path d="M5 11.5V20a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8.5" stroke={stroke} strokeWidth="1.8" strokeLinejoin="round" fill={fill} />
          {/* Selected: a thin white outline keeps the awning apart from the shop. */}
          <path d="M3.5 9.2 5.6 4.6A1.6 1.6 0 0 1 7 3.7h12a1.6 1.6 0 0 1 1.4.9l2.1 4.6a3 3 0 0 1-5.1 2.6 3 3 0 0 1-4.4 0 3 3 0 0 1-4.4 0 3 3 0 0 1-5.1-2.6Z" stroke={active ? "#fff" : stroke} strokeWidth={active ? 1.3 : 1.8} strokeLinejoin="round" fill={fill} />
          <path d="M10.4 4.6v5.6M15.6 4.6v5.6" stroke={detail} strokeWidth="1.5" strokeLinecap="round" opacity={active ? 0.9 : 0.55} />
          <path d="M10.6 22v-4.6a2.4 2.4 0 0 1 4.8 0V22" stroke={detail} strokeWidth="1.8" strokeLinecap="round" />
        </>
      ) : null}
      {name === "orders" ? (
        // Order ticket with a torn edge and two lines.
        <>
          <path d="M6 3.5h14a1 1 0 0 1 1 1V22l-2.3-1.4-2.3 1.4-2.4-1.4-2.4 1.4-2.3-1.4L7.3 22 5 20.6V4.5a1 1 0 0 1 1-1Z" stroke={stroke} strokeWidth="1.8" strokeLinejoin="round" fill={fill} />
          <path d="M9 9h8M9 13h5" stroke={detail} strokeWidth="1.8" strokeLinecap="round" />
          <circle cx="17" cy="13" r="1.1" fill={detail} />
        </>
      ) : null}
      {name === "menu" ? (
        // Rice bowl with chopsticks, matching the 3D menu icon.
        <>
          <path d="M15.5 3.2 19 9.6M18.6 2.6l2.7 6.6" stroke={active ? RED : "currentColor"} strokeWidth="1.8" strokeLinecap="round" />
          <path d="M3.5 12h19a9.5 9.5 0 0 1-19 0Z" stroke={stroke} strokeWidth="1.8" strokeLinejoin="round" fill={fill} />
          <path d="M9.5 21.5h7" stroke={stroke} strokeWidth="1.8" strokeLinecap="round" />
          <path d="M7.5 15.5a5.5 5.5 0 0 0 3 2.8" stroke={detail} strokeWidth="1.8" strokeLinecap="round" />
        </>
      ) : null}
      {name === "more" ? (
        // Three rounded tiles and a dot: "everything else".
        <>
          <rect x="3.5" y="3.5" width="8" height="8" rx="2.6" stroke={stroke} strokeWidth="1.8" fill={fill} />
          <rect x="14.5" y="3.5" width="8" height="8" rx="2.6" stroke={stroke} strokeWidth="1.8" fill={fill} />
          <rect x="3.5" y="14.5" width="8" height="8" rx="2.6" stroke={stroke} strokeWidth="1.8" fill={fill} />
          <circle cx="18.5" cy="18.5" r="4" stroke={stroke} strokeWidth="1.8" fill={fill} />
        </>
      ) : null}
    </svg>
  );
}
