import { PostDetailKeyboardFixture } from "@/components/dev/post-detail-keyboard-fixture";

export default async function PostDetailKeyboardFixturePage({ searchParams }: { searchParams: Promise<{ loading?: string }> }) {
  const query = await searchParams;
  return <PostDetailKeyboardFixture loading={query.loading === "1"} />;
}
