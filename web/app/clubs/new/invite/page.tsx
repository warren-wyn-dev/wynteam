import { redirect } from "next/navigation";

import { CreateClubInviteReferenceScreen } from "@/components/content-reference/club-screens";

// Reference fixture (mock data, no auth gate) for tests/browser/content-reference-flow.spec.ts
// under `next dev`. Production builds send real users to the real create-club flow instead.
export default function Page() {
  if (process.env.NODE_ENV === "production") redirect("/clubs/new");
  return <CreateClubInviteReferenceScreen />;
}
