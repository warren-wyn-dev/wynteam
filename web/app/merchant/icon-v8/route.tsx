import { ImageResponse } from "next/og";

const ALLOWED_SIZES = new Set([16, 32, 48, 57, 64, 72, 76, 96, 114, 120, 128, 144, 152, 167, 180, 192, 256, 384, 512]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const requested = Number(searchParams.get("size") ?? "180");
  const size = ALLOWED_SIZES.has(requested) ? requested : 180;
  const maskable = searchParams.get("maskable") === "1";
  const scale = maskable ? 0.72 : 0.82;
  const markSize = Math.round(size * scale);

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          overflow: "hidden",
          background: "linear-gradient(145deg, #ff3542 0%, #f20b1f 45%, #d80010 100%)",
          position: "relative",
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: Math.round(size * 0.018),
            borderRadius: Math.round(size * 0.22),
            border: `${Math.max(1, Math.round(size * 0.008))}px solid rgba(255,255,255,0.35)`,
            boxShadow: `inset 0 ${Math.round(size * 0.025)}px ${Math.round(size * 0.06)}px rgba(255,255,255,.22), inset 0 -${Math.round(size * 0.035)}px ${Math.round(size * 0.08)}px rgba(120,0,0,.20)`,
          }}
        />
        <svg
          width={markSize}
          height={markSize}
          viewBox="0 0 512 512"
          style={{ display: "block" }}
        >
          <defs>
            <linearGradient id="white3d" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#ffffff" />
              <stop offset="72%" stopColor="#fff7f7" />
              <stop offset="100%" stopColor="#f0dede" />
            </linearGradient>
            <filter id="shadow" x="-30%" y="-30%" width="160%" height="180%">
              <feDropShadow dx="0" dy="10" stdDeviation="7" floodColor="#8d0010" floodOpacity="0.65" />
            </filter>
          </defs>

          <g filter="url(#shadow)">
            <path
              d="M68 168 L147 86 L255 216 L365 86 L444 168"
              fill="none"
              stroke="#b10012"
              strokeWidth="58"
              strokeLinecap="round"
              strokeLinejoin="round"
              transform="translate(0 8)"
            />
            <path
              d="M68 168 L147 86 L255 216 L365 86 L444 168"
              fill="none"
              stroke="url(#white3d)"
              strokeWidth="48"
              strokeLinecap="round"
              strokeLinejoin="round"
            />

            <path
              d="M168 302 L256 208 L344 302 L344 382 L168 382 Z"
              fill="none"
              stroke="#b10012"
              strokeWidth="54"
              strokeLinecap="round"
              strokeLinejoin="round"
              transform="translate(0 8)"
            />
            <path
              d="M168 302 L256 208 L344 302 L344 382 L168 382 Z"
              fill="none"
              stroke="url(#white3d)"
              strokeWidth="44"
              strokeLinecap="round"
              strokeLinejoin="round"
            />

            <rect x="190" y="292" width="132" height="58" rx="22" fill="#fff7f7" stroke="#f2d6d8" strokeWidth="3" />
            <rect x="190" y="292" width="26.4" height="58" rx="13" fill="#ffffff" />
            <rect x="216.4" y="292" width="26.4" height="58" rx="13" fill="#f1192c" />
            <rect x="242.8" y="292" width="26.4" height="58" rx="13" fill="#ffffff" />
            <rect x="269.2" y="292" width="26.4" height="58" rx="13" fill="#f1192c" />
            <rect x="295.6" y="292" width="26.4" height="58" rx="13" fill="#ffffff" />

            <rect x="204" y="340" width="104" height="73" rx="13" fill="url(#white3d)" />
            <rect x="242" y="360" width="28" height="53" rx="7" fill="#df071b" />
          </g>
        </svg>
      </div>
    ),
    {
      width: size,
      height: size,
      headers: {
        "Cache-Control": "public, max-age=31536000, immutable",
      },
    },
  );
}
