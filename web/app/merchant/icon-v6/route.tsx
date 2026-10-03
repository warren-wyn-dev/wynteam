import { ImageResponse } from "next/og";

const SOURCE_ICON = "https://wynos.online/icons/merchant/apple-touch-icon-v5-180.png";
const ALLOWED_SIZES = new Set([180, 192, 512]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const requested = Number(searchParams.get("size") ?? "180");
  const size = ALLOWED_SIZES.has(requested) ? requested : 180;

  // The approved Merchant artwork has a small white safety margin baked into
  // the PNG. iOS then adds its own icon mask, which makes that margin look like
  // a white border. Render the same approved artwork ~15% larger and crop it
  // to the requested square so the red tile reaches the system mask.
  const artworkSize = Math.round(size * (180 / 156));

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
          background: "#e32636",
        }}
      >
        <img
          src={SOURCE_ICON}
          width={artworkSize}
          height={artworkSize}
          alt=""
          style={{
            width: artworkSize,
            height: artworkSize,
            flex: "none",
          }}
        />
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
