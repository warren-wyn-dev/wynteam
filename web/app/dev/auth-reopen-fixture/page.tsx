"use client";

import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { useState } from "react";
import { ParityAuthEntry } from "@/components/parity-auth-entry";

// This fixture never contacts production Auth, creates tokens, or stores
// credentials. It reproduces the cold-start event ordering on iOS when a
// temporary session-storage/network error occurs at app launch.
function createFailingClient() {
  type Callback = (event: "INITIAL_SESSION" | "SIGNED_OUT", session: Session | null) => void;
  const listeners = new Set<Callback>();
  let reads = 0;
  const client = {
    auth: {
      getSession: async () => {
        reads += 1;
        return { data: { session: null }, error: new Error("Temporary session check error") };
      },
      onAuthStateChange: (callback: Callback) => {
        listeners.add(callback);
        queueMicrotask(() => callback("INITIAL_SESSION", null));
        return { data: { subscription: { unsubscribe: () => listeners.delete(callback) } } };
      },
    },
  } as unknown as SupabaseClient;
  return {
    client,
    signOut: () => listeners.forEach((listener) => listener("SIGNED_OUT", null)),
    reads: () => reads,
  };
}

export default function AuthReopenFixture() {
  const [fixture] = useState(createFailingClient);
  const [shownReads, setShownReads] = useState(0);
  return (
    <>
      <div style={{ position: "fixed", bottom: 0, zIndex: 200, padding: 8, background: "#fff" }}>
        <button type="button" onClick={() => { fixture.signOut(); }}>Simulate explicit sign out</button>
        <button type="button" onClick={() => setShownReads(fixture.reads())}>Read session-check count</button>
        <output aria-label="session checks">{shownReads}</output>
      </div>
      <ParityAuthEntry clientOverride={fixture.client} />
    </>
  );
}
