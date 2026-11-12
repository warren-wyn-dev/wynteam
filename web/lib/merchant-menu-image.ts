/** Only resize public menu photos from this project's existing image allowlist. */
export function merchantMenuThumbnailUrl(imageUrl: string | null, supabaseUrl?: string): string | null {
  if (!imageUrl || !supabaseUrl) return imageUrl;
  try {
    const image = new URL(imageUrl);
    const project = new URL(supabaseUrl);
    if ((project.protocol !== "https:" && project.protocol !== "http:")
      || image.origin !== project.origin || image.username || image.password
      || image.search || image.hash
      || !image.pathname.startsWith("/storage/v1/object/public/food-public/")
      || !/\.(?:jpe?g|png|webp|avif)$/i.test(image.pathname)) return imageUrl;
    // 64 CSS pixels at 2x density. Private/signed URLs never enter the public optimizer.
    return `/_next/image?url=${encodeURIComponent(imageUrl)}&w=128&q=75`;
  } catch {
    return imageUrl;
  }
}
