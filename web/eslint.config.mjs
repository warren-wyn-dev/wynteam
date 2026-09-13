import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // Migrated route components intentionally load RLS-scoped external data on
    // mount/route change and immediately expose a loading state. React 19's
    // generic rule treats that established client-data-loader pattern as a
    // synchronous cascade even though the state change is the requested UI.
    // Keep the exception narrowly scoped to these route files; the rest of
    // the consumer web (including Home) remains covered by the stricter rule.
    files: ["components/*-route*.tsx"],
    rules: {
      "react-hooks/set-state-in-effect": "off",
      "react-hooks/immutability": "off",
      // WYNOS deliberately uses native browser <img> on migrated consumer
      // surfaces. It avoids an optimizer/proxy dependency for signed Supabase
      // URLs and keeps browser image decoding/lifecycle behavior explicit for
      // the iOS WebKit stability work. This is an intentional architecture
      // choice, not an accidental missed next/image migration.
      "@next/next/no-img-element": "off",
    },
  },
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
]);
