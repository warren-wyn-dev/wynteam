/** Only resize public menu photos from this project's existing image allowlist. */
/** Widths the Next.js image optimizer accepts by default (deviceSizes/imageSizes); anything else keeps the original. */
const OPTIMIZED_WIDTHS = [128, 256, 384, 750] as const;

export function merchantMenuThumbnailUrl(imageUrl: string | null, supabaseUrl?: string, width: number = 128): string | null {
  if (!imageUrl || !supabaseUrl) return imageUrl;
  if (!(OPTIMIZED_WIDTHS as readonly number[]).includes(width)) return imageUrl;
  try {
    const image = new URL(imageUrl);
    const project = new URL(supabaseUrl);
    if ((project.protocol !== "https:" && project.protocol !== "http:")
      || image.origin !== project.origin || image.username || image.password
      || image.search || image.hash
      || !image.pathname.startsWith("/storage/v1/object/public/food-public/")
      || !/\.(?:jpe?g|png|webp|avif)$/i.test(image.pathname)) return imageUrl;
    // Default 128 = 64 CSS pixels at 2x density (Merchant); ZOKY passes 128/256/384/750. Private/signed URLs never enter the public optimizer.
    return `/_next/image?url=${encodeURIComponent(imageUrl)}&w=${width}&q=75`;
  } catch {
    return imageUrl;
  }
}
