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
    loader: {
      load: (options: {
        config: { entrypointBaseUrl: string; assetBase: string; canvasKitBaseUrl: string };
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
      void loader.load({
        config: {
          entrypointBaseUrl: MERCHANT_FLUTTER_ASSET_BASE,
          assetBase: MERCHANT_FLUTTER_ASSET_BASE,
          canvasKitBaseUrl: `${MERCHANT_FLUTTER_ASSET_BASE}canvaskit/`,
        },
        onEntrypointLoaded: async (initializer) => {
          try {
            const runner = await initializer.initializeEngine({ multiViewEnabled: true, assetBase: MERCHANT_FLUTTER_ASSET_BASE, canvasKitBaseUrl: `${MERCHANT_FLUTTER_ASSET_BASE}canvaskit/` });
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
