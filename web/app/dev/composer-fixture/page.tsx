import { notFound } from "next/navigation";
import { ComposerFixture } from "@/components/composer-fixture";

// Only for Playwright's next-dev browser suite, never an accessible production route.
export default function ComposerFixturePage() {
  if (process.env.NODE_ENV !== "development") notFound();
  return <ComposerFixture />;
}
