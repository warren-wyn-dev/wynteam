"use client";

import { followButtonLabel } from "@/components/ui/follow-button-label";

/**
 * WYNOS Web Beta1, item 9: exercises followButtonLabel() (web/components/ui/
 * follow-button-label.tsx), the shared label logic every follow/unfollow
 * button in the app now uses. Pure function, no Supabase/session needed.
 * Test-only, not linked from anywhere in the app.
 */
export function FollowButtonFixture() {
  return (
    <ul>
      <li id="state-idle">{followButtonLabel({ busy: false, following: false, requested: false })}</li>
      <li id="state-busy">{followButtonLabel({ busy: true, following: false, requested: false })}</li>
      <li id="state-following">{followButtonLabel({ busy: false, following: true, requested: false })}</li>
      <li id="state-requested">{followButtonLabel({ busy: false, following: false, requested: true })}</li>
      <li id="state-busy-while-following">{followButtonLabel({ busy: true, following: true, requested: false })}</li>
    </ul>
  );
}
