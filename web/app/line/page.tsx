import { redirect } from "next/navigation";

// LINE notifications and LIFF entry were removed from ZOKY (Founder 2026-11-12).
// Old LINE message buttons and bookmarks land on ZOKY instead of a dead page.
export default function LinePage() {
  redirect("/food");
}
