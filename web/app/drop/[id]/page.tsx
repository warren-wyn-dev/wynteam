import { PostDetailRoute } from "@/components/post-detail-route";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <PostDetailRoute dropId={id} />;
}
