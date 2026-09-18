import { redirect } from "next/navigation";

import { SinglePostReferenceScreen } from "@/components/content-reference/screens";

export const metadata = { title: "Wynos — โพสต์" };

// Reference fixture (mock data, no auth gate) for tests/browser/content-reference-flow.spec.ts
// under `next dev`. Production builds send real users to the real post detail route instead
// (/drop/[id] carries the same id and is auth-gated).
export default async function SinglePostPage({
  params,
}: {
  params: Promise<{ postId: string }>;
}) {
  const { postId } = await params;
  if (process.env.NODE_ENV === "production") redirect(`/drop/${postId}`);
  return <SinglePostReferenceScreen postId={postId} />;
}
