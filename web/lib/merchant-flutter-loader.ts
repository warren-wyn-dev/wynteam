/** Loads the reviewed, same-origin Flutter build without a shell service worker. */
export const MERCHANT_FLUTTER_ASSET_BASE = "/merchant-flutter/";

export type MerchantFlutterApp = {
  addView: (options: { hostElement: HTMLElement }) => number;
  removeView: (viewId: number) => void;
};

type FlutterInitializer = {
  initializeEngine: (options: { multiViewEnabled: true; assetBase: string; canvasKitBaseUrl: string }) => Promise<{
    runApp: () => Promise<MerchantFlutterApp>;
  }>;
};

type FlutterBrowser = Window & {
  _flutter?: {
    merchantAssetBase?: string;
    loader: {
      load: (options: {
        config: { entrypointBaseUrl: string; assetBase: string; canvasKitBaseUrl: string; forceSingleThreadedSkwasm: true };
        onEntrypointLoaded: (initializer: FlutterInitializer) => Promise<void>;
      }) => Promise<unknown>;
    };
  };
};

let loadedApp: Promise<MerchantFlutterApp> | undefined;

/** A singleton engine supports add/remove views across Next.js route changes. */
export function loadMerchantFlutterApp(): Promise<MerchantFlutterApp> {
  if (loadedApp) return loadedApp;
  loadedApp = new Promise((resolve, reject) => {
    const browser = window as FlutterBrowser;
    const timeout = window.setTimeout(() => reject(new Error("merchant_flutter_load_timeout")), 45_000);
    const fail = () => {
      window.clearTimeout(timeout);
      reject(new Error("merchant_flutter_load_failed"));
    };
    const script = document.createElement("script");
    script.src = `${MERCHANT_FLUTTER_ASSET_BASE}flutter_bootstrap.js`;
    script.async = true;
    script.dataset.zokyMerchant = "loader";
    script.onerror = fail;
    script.onload = () => {
      const loader = browser._flutter?.loader;
      if (!loader) { fail(); return; }
      // The stable bootstrap declares its matching immutable payload. Reject
      // malformed/external paths rather than executing a different entrypoint.
      const declaredBase = browser._flutter?.merchantAssetBase;
      if (declaredBase !== undefined && !/^\/merchant-flutter\/builds\/[a-f0-9]{20}\/$/.test(declaredBase)) {
        fail(); return;
      }
      // Compatibility with an already-open document from the previous build.
      const assetBase = declaredBase ?? MERCHANT_FLUTTER_ASSET_BASE;
      void loader.load({
        config: {
          entrypointBaseUrl: assetBase,
          assetBase,
          canvasKitBaseUrl: `${assetBase}canvaskit/`,
          // Preserve shared-origin behavior without requiring cross-origin
          // isolation headers. SDK feature detection chooses the JS fallback.
          forceSingleThreadedSkwasm: true,
        },
        onEntrypointLoaded: async (initializer) => {
          try {
            const runner = await initializer.initializeEngine({ multiViewEnabled: true, assetBase, canvasKitBaseUrl: `${assetBase}canvaskit/` });
            const app = await runner.runApp();
            if (typeof app.addView !== "function" || typeof app.removeView !== "function") {
              fail(); return;
            }
            window.clearTimeout(timeout);
            resolve(app);
          } catch { fail(); }
        },
      }).catch(fail);
    };
    document.head.appendChild(script);
  });
  // A failed engine cannot safely restart in the same document. The error UI
  // offers a full reload rather than executing a second Dart entrypoint.
  return loadedApp;
}
