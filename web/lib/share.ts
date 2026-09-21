/**
 * WYN-185 item 5: shared navigator.share()-with-clipboard-fallback used by
 * every "แชร์" button (post, club, club post, profile). Previously each
 * call site reimplemented this inline and most of them (everywhere except
 * profile-route.tsx) swallowed every outcome silently — a clipboard-only
 * device got no "คัดลอกลิงก์แล้ว" confirmation, and a real failure (e.g.
 * clipboard permission denied) looked identical to nothing happening at
 * all when the button was tapped.
 */
export async function shareOrCopyLink(
  data: { title: string; text: string; url: string },
  showToast: (message: string) => void,
): Promise<void> {
  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(data.url);
      showToast("คัดลอกลิงก์แล้ว");
    } catch {
      showToast("แชร์ไม่สำเร็จ");
    }
  };
  if (!navigator.share) {
    await copyLink();
    return;
  }
  try {
    await navigator.share(data);
  } catch (e) {
    // AbortError fires both on a deliberate cancel and when the OS reports
    // no compatible share target -- the API gives no way to tell those
    // apart, so fall back to a clipboard copy either way rather than
    // leaving the no-target case looking like the button did nothing.
    if (e instanceof DOMException && e.name === "AbortError") {
      await copyLink();
      return;
    }
    showToast("แชร์ไม่สำเร็จ");
  }
}
