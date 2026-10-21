import type { Metadata } from "next";

import { FoodLegalPage } from "@/components/food/food-legal-page";
import { foodLegalReady, foodPrivacy } from "@/lib/food-legal";

export const metadata: Metadata = {
  title: foodPrivacy.title,
  description: foodPrivacy.description,
  alternates: { canonical: foodPrivacy.path },
  robots: { index: foodLegalReady, follow: true },
};

export default function FoodPrivacyPage() {
  return <FoodLegalPage document={foodPrivacy} />;
}
