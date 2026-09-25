"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useState } from "react";

import { startGoogleOAuth } from "@/lib/google-pwa-oauth";

/** Credential-free test fixture: never contacts Google or production Auth. */
export default function GooglePwaOAuthFixture() {
  const [result, setResult] = useState("");
  const [redirect, setRedirect] = useState("");
  const [skip, setSkip] = useState("");
  const client = {
    auth: {
      signInWithOAuth: async ({ options }: {
        options?: { redirectTo?: string; skipBrowserRedirect?: boolean };
      }) => {
        setRedirect(options?.redirectTo ?? "");
        setSkip(String(options?.skipBrowserRedirect));
        const origin = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? window.location.origin).origin;
        return { data: { url: origin + "/auth/v1/authorize?provider=google" }, error: null };
      },
    },
  } as unknown as SupabaseClient;

  return <main>
    <button type="button" onClick={() => {
      void startGoogleOAuth(client, window.location.origin + "/welcome").then((response) => {
        setResult(response.started ? "started" : response.error ?? "failed");
      });
    }}>Start mocked Google</button>
    <output aria-label="OAuth result">{result}</output>
    <output aria-label="OAuth callback">{redirect}</output>
    <output aria-label="Skip browser redirect">{skip}</output>
  </main>;
}
