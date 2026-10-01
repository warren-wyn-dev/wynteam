import type { Metadata } from "next";

import { SocialOrderApp } from "@/components/social-commerce/social-order-app";

import "./social-order.css";

export const metadata: Metadata = {
  title: "สั่งซื้อจาก WYNOS",
  description: "สั่งซื้อจากโพสต์ WYNOS และชำระด้วย PromptPay",
  robots: { index: false, follow: false },
};

export default async function BuyFromPostPage({
  params,
}: {
  params: Promise<{ dropId: string }>;
}) {
  const { dropId } = await params;
  return <SocialOrderApp dropId={dropId} />;
}
