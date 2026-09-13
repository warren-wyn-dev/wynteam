import { HomeNavigationBridge } from "@/components/home-navigation-bridge";
import { ParityAuthEntry } from "@/components/parity-auth-entry";

export default function HomePage() {
  return (
    <>
      <ParityAuthEntry />
      <HomeNavigationBridge />
    </>
  );
}
