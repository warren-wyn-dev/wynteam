import { SinglePostReferenceScreen } from "@/components/content-reference/screens";

export const metadata = { title: "Wynos — โพสต์" };

export default async function SinglePostPage({
  params,
}: {
  params: Promise<{ postId: string }>;
}) {
  const { postId } = await params;
  return <SinglePostReferenceScreen postId={postId} />;
}
