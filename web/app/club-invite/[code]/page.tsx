import type { Metadata } from "next";

import { ClubInviteLinkRoute } from "@/components/club-invite-route";
import { shareMetadata } from "@/lib/share-metadata";

export async function generateMetadata({ params }: { params: Promise<{ code: string }> }): Promise<Metadata> {
  const { code } = await params;
  return shareMetadata("คำเชิญเข้าร่วม Club บน WYNOS", "เปิดลิงก์นี้เพื่อเข้าร่วม Club บน WYNOS", `/club-invite/${encodeURIComponent(code)}`);
}

export default async function Page({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  return <ClubInviteLinkRoute code={code} />;
}
