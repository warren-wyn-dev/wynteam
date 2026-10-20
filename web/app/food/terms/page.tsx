import type { Metadata } from "next";

import { FoodLegalPage } from "@/components/food/food-legal-page";
import { foodLegalReady, foodTerms } from "@/lib/food-legal";

export const metadata: Metadata = {
  title: foodTerms.title,
  description: foodTerms.description,
  alternates: { canonical: foodTerms.path },
  robots: { index: foodLegalReady, follow: true },
};

export default function FoodTermsPage() {
  return <FoodLegalPage document={foodTerms} />;
}
