"use client";

import { useState } from "react";

import { MAX_POST_IMAGES } from "@/lib/post-limits";

/**
 * WYNOS Web Beta1, item 12: reproduces beta4-composer.tsx's gallery-picker
 * onChange logic (the piece that actually changed -- truncate to
 * MAX_POST_IMAGES and notify when the picked set overflows it) without the
 * rest of the composer, which needs a live Supabase session. Test-only,
 * not linked from anywhere in the app.
 */
export function ImageLimitFixture() {
  const [files, setFiles] = useState<File[]>([]);
  const [error, setError] = useState("");
  return (
    <div>
      <input
        id="gallery-input"
        type="file"
        accept="image/*"
        multiple
        onChange={(event) => {
          const picked = Array.from(event.target.files ?? []);
          setError("");
          setFiles((current) => {
            const combined = [...current, ...picked];
            if (combined.length > MAX_POST_IMAGES) setError(`เลือกรูปได้สูงสุด ${MAX_POST_IMAGES} รูปต่อโพสต์`);
            return combined.slice(0, MAX_POST_IMAGES);
          });
          event.currentTarget.value = "";
        }}
      />
      <div id="image-count">{files.length}/{MAX_POST_IMAGES}</div>
      {error ? <p id="image-error">{error}</p> : null}
    </div>
  );
}
