import { ImageResponse } from "next/og";

const SOURCE_ICON = "https://wynos.online/icons/merchant/merchant-approved-v10.jpg";
const ALLOWED_SIZES = new Set([16, 32, 48, 57, 64, 72, 76, 96, 114, 120, 128, 144, 152, 167, 180, 192, 256, 384, 512]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const requested = Number(searchParams.get("size") ?? "180");
  const size = ALLOWED_SIZES.has(requested) ? requested : 180;

  return new ImageResponse(
    (
      <img
        src={SOURCE_ICON}
        width={size}
        height={size}
        alt=""
        style={{ width: size, height: size, display: "block" }}
      />
    ),
    {
      width: size,
      height: size,
      headers: { "Cache-Control": "public, max-age=31536000, immutable" },
    },
  );
}
