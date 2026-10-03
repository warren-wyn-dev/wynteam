import { ImageResponse } from "next/og";

const SOURCE_ICON = "https://wynos.online/icons/food/icon-512.png";
const ALLOWED_SIZES = new Set([16, 32, 48, 57, 64, 72, 76, 96, 114, 120, 128, 144, 152, 167, 180, 192, 256, 384, 512]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const requested = Number(searchParams.get("size") ?? "192");
  const size = ALLOWED_SIZES.has(requested) ? requested : 192;

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
        <img src={SOURCE_ICON} width={size} height={size} alt="" />
      </div>
    ),
    {
      width: size,
      height: size,
      headers: { "Cache-Control": "public, max-age=31536000, immutable" },
    },
  );
}
