import { redirect } from "next/navigation";

import { ComposePostReferenceScreen } from "@/components/content-reference/screens";

export const metadata = { title: "Wynos — สร้างโพสต์" };

// Reference fixture (mock data, no auth gate) for tests/browser/content-reference-flow.spec.ts
// under `next dev`. Production builds send real users to the real composer instead.
export default function ComposePostPage() {
  if (process.env.NODE_ENV === "production") redirect("/?compose=1");
  return <ComposePostReferenceScreen />;
}
