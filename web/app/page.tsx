import { HomeNavigationBridge } from "@/components/home-navigation-bridge";
import { ParityAuthGate } from "@/components/parity-auth-gate";

export default function HomePage() {
  return (
    <>
      <ParityAuthGate />
      <HomeNavigationBridge />
    </>
  );
}
