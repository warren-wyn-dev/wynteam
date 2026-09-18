import { redirect } from "next/navigation";

import { EditProfileReferenceScreen } from "@/components/content-reference/profile-screens";

export const metadata = { title: "Wynos — แก้ไขโปรไฟล์" };

// Reference fixture (mock data, no auth gate) for tests/browser/content-reference-flow.spec.ts
// under `next dev`. Production builds send real users to their real profile instead
// (editing is a real, in-place state of /profile/[id]).
export default function Page() {
  if (process.env.NODE_ENV === "production") redirect("/profile/me");
  return <EditProfileReferenceScreen />;
}
