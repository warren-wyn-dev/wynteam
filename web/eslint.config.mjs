import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // Phase 3 route components intentionally load RLS-scoped external data on
    // mount/route change and immediately expose a loading state. React 19's
    // generic rule treats that established client-data-loader pattern as a
    // synchronous cascade even though the state change is the requested UI.
    // Keep the exception narrowly scoped to these route files; the rest of
    // the consumer web (including Home) remains covered by the stricter rule.
    files: ["components/*-route*.tsx"],
    rules: {
      "react-hooks/set-state-in-effect": "off",
      // Internal Next navigation is preferred, but two destructive/terminal
      // flows intentionally assign location so auth/deleted-session state is
      // discarded by a full document navigation.
      "react-hooks/immutability": "off",
    },
  },
  globalIgnores([".next/**", "out/**", "build/**", "next-env.d.ts"]),
]);
