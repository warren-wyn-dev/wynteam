import { redirect } from "next/navigation";

import { HomeReferenceScreen } from "@/components/content-reference/screens";

export const metadata = { title: "Wynos — หน้าหลัก" };

// This route renders the static content-reference fixture (mock data, no
// auth gate) that tests/browser/content-reference-flow.spec.ts depends on
// under `next dev`. Real users must never land on it: any production build
// (staging preview or the wynos.online cutover) sends them to the real,
// auth-gated Home at "/" instead.
export default function HomeReferencePage() {
  if (process.env.NODE_ENV === "production") redirect("/");
  return <HomeReferenceScreen />;
}
