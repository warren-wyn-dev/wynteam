import { DropDeepLinkRoute } from "@/components/deep-link-routes";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <DropDeepLinkRoute dropId={id} />;
}
