import { expect, test, type Page } from '@playwright/test';
import { writeFile } from 'node:fs/promises';

// The actual compiled Flutter app runs against a content-free synthetic bridge.
// This suite never signs in or reads/writes production merchant records.
test.use({ serviceWorkers: 'block' });

type StartupEvent = {
  viewId: number;
  phase: 'content-ready';
  elapsedMs: number;
  fontWarmupMs: number;
  fontWarmupTimedOut: boolean;
};
type FixtureBrowser = Window & {
  qaReadyEvents: StartupEvent[];
  qaCurrentView: number;
  qaCounts: Record<string, number>;
  qaReleaseStores: () => void;
  qaReleaseSummaries: () => void;
  qaRemount: () => Promise<{ previous: number; current: number }>;
};

async function startupHost(page: Page, {
  holdStores = false,
  holdSummaries = false,
  scenario = 'store',
  menuCount = 0,
  renderer,
}: {
  holdStores?: boolean;
  holdSummaries?: boolean;
  scenario?: 'store' | 'empty' | 'error';
  menuCount?: number;
  renderer?: 'canvaskit';
} = {}) {
  await page.route('**/merchant-startup-qa', route => route.fulfill({
    contentType: 'text/html; charset=utf-8',
    body: `<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
      const store={id:'startup-store',name:'ร้านเริ่มต้น QA',is_open:true,is_published:true,effective_open:true};
      const scenario=${JSON.stringify(scenario)};
      let holdStores=${holdStores};
      const storesReady=new Promise(resolve=>window.qaReleaseStores=()=>{holdStores=false;resolve();});
      const summariesReady=new Promise(resolve=>window.qaReleaseSummaries=resolve);
      window.qaReadyEvents=[];window.qaCounts={};
      window.addEventListener('zoky-merchant-startup',event=>window.qaReadyEvents.push(event.detail));
      window.zokyMerchant={request:async(method,raw)=>{
        window.qaCounts[method]=(window.qaCounts[method]||0)+1;
        if(method==='stores'&&holdStores)await storesReady;
        if(${holdSummaries}&&['report','quality','campaigns'].includes(method))await summariesReady;
        let data=null;
        switch(method){
          case 'stores':if(scenario==='error')return JSON.stringify({ok:false,error:'การเชื่อมต่อทดสอบขัดข้อง'});data=scenario==='empty'?[]:[store];break;
          case 'hasRole':data=true;break;
          case 'menu':data=Array.from({length:${menuCount}},(_,index)=>({id:'startup-menu-'+index,name:'อาหารทดสอบ '+(index+1),price:50,category:'อาหาร',is_available:true,image_url:location.origin+'/merchant-startup-image-'+index+'.png'}));break;
          case 'orders':data=[];break;
          case 'report':data={today_sales:0,today_orders:0,month_sales:0,total_orders:0,best:[]};break;
          case 'quality':data={available:false};break;
          case 'campaigns':data={can_manage:true,campaigns:[]};break;
          case 'pushStatus':data={enabled:false,available:false};break;
        }
        return JSON.stringify({ok:true,data});
      }};
      window.qaMountApp=async(initializer)=>{
        const base=_flutter.merchantAssetBase||'/merchant-flutter/';
        const runner=await initializer.initializeEngine({multiViewEnabled:true,assetBase:base,canvasKitBaseUrl:base+'canvaskit/'});
        const app=await runner.runApp();
        window.qaCurrentView=app.addView({hostElement:document.querySelector('#host')});
        window.qaRemount=async()=>{
          const previous=window.qaCurrentView;
          app.removeView(previous);
          document.querySelector('#host').replaceChildren();
          holdStores=false;
          await new Promise(requestAnimationFrame);
          window.qaCurrentView=app.addView({hostElement:document.querySelector('#host')});
          return {previous,current:window.qaCurrentView};
        };
      };
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="(()=>{const base=_flutter.merchantAssetBase||'/merchant-flutter/';_flutter.loader.load({config:{entrypointBaseUrl:base,assetBase:base,canvasKitBaseUrl:base+'canvaskit/',forceSingleThreadedSkwasm:true,renderer:${renderer === 'canvaskit' ? "'canvaskit'" : 'null'}},onEntrypointLoaded:window.qaMountApp});})()"></script></body></html>`,
  }));
  await page.goto('/merchant-startup-qa', { waitUntil: 'domcontentloaded' });
  await page.locator('flutter-view').waitFor({ timeout: 45_000 });
}

async function readyEvents(page: Page) {
  return page.evaluate(() => (window as unknown as FixtureBrowser).qaReadyEvents);
}

async function viewportEvidence(page: Page) {
  return page.evaluate(() => ({
    scrollY: window.scrollY,
    documentScrollTop: document.documentElement.scrollTop,
    viewRects: [...document.querySelectorAll('flutter-view')].map(view => {
      const rect = view.getBoundingClientRect();
      return { top: rect.top, left: rect.left, width: rect.width, height: rect.height };
    }),
  }));
}

function checkReadyEvent(event: StartupEvent, viewId: number) {
  expect(event.viewId).toBe(viewId);
  expect(event.phase).toBe('content-ready');
  expect(Number.isFinite(event.elapsedMs)).toBe(true);
  expect(event.elapsedMs).toBeGreaterThanOrEqual(0);
  expect(Number.isFinite(event.fontWarmupMs)).toBe(true);
  expect(event.fontWarmupMs).toBeGreaterThanOrEqual(0);
  expect(typeof event.fontWarmupTimedOut).toBe('boolean');
  expect(Object.keys(event).sort()).toEqual(['elapsedMs', 'fontWarmupMs', 'fontWarmupTimedOut', 'phase', 'viewId']);
}

test('startup waits for critical store content while summaries and decorative atlas remain pending', async ({ page }) => {
  let releaseAtlas!: () => void;
  const atlasReady = new Promise<void>(resolve => { releaseAtlas = resolve; });
  let atlasRequests = 0;
  await page.route('**/merchant-tools-3d.webp', async route => {
    atlasRequests++;
    await atlasReady;
    await route.continue();
  });
  try {
    await startupHost(page, { holdStores: true, holdSummaries: true });
    await expect(page.locator('[aria-label="กำลังโหลดข้อมูลร้าน"]').or(page.getByText('กำลังโหลดข้อมูลร้าน', { exact: true })).first()).toBeVisible();
    await expect.poll(() => atlasRequests).toBe(1);
    expect(await readyEvents(page)).toEqual([]);
    await page.evaluate(() => (window as unknown as FixtureBrowser).qaReleaseStores());
    await expect.poll(async () => (await readyEvents(page)).length).toBe(1);
    const currentView = await page.evaluate(() => (window as unknown as FixtureBrowser).qaCurrentView);
    const event = (await readyEvents(page))[0];
    checkReadyEvent(event, currentView);
    await test.info().attach('startup-readiness.json', { body: JSON.stringify(event), contentType: 'application/json' });
    await writeFile(test.info().outputPath('startup-readiness.json'), JSON.stringify({ event, viewport: await viewportEvidence(page) }, null, 2));
    await expect(page.getByText('ร้านเริ่มต้น QA', { exact: true }).first()).toBeVisible();
    await expect(page.getByRole('group', { name: 'ยอดขายวันนี้ กำลังโหลดยอดขาย', exact: true })).toBeVisible();
    await expect(page.getByRole('button', { name: 'การเงิน', exact: true })).toBeEnabled();
    await page.screenshot({ path: test.info().outputPath('startup-atlas-pending.png'), fullPage: true });
    expect(atlasRequests).toBe(1);
  } finally {
    releaseAtlas();
    await page.evaluate(() => (window as unknown as FixtureBrowser).qaReleaseSummaries?.());
  }
});

for (const renderer of ['skwasm', 'canvaskit'] as const) {
  test(`healthy ${renderer} startup reports cold and warm view timings`, async ({ page }) => {
    await startupHost(page, { renderer: renderer === 'canvaskit' ? renderer : undefined });
    await expect.poll(async () => (await readyEvents(page)).length).toBe(1);
    await expect(page.locator('[flt-renderer]')).toHaveAttribute('flt-renderer', renderer);
    const cold = (await readyEvents(page))[0];
    const views = await page.evaluate(() => (window as unknown as FixtureBrowser).qaRemount());
    await expect.poll(async () => (await readyEvents(page)).length).toBe(2);
    const warm = (await readyEvents(page))[1];
    checkReadyEvent(cold, views.previous);
    checkReadyEvent(warm, views.current);
    expect(warm.fontWarmupMs).toBe(cold.fontWarmupMs);
    expect(warm.fontWarmupTimedOut).toBe(cold.fontWarmupTimedOut);
    await expect(page.locator('flutter-view')).toHaveCount(1);
    const header = page.getByText('ร้านเริ่มต้น QA', { exact: true }).first();
    await expect(header).toBeVisible();
    const headerBounds = await header.boundingBox();
    expect(headerBounds?.y).toBeGreaterThanOrEqual(0);
    expect(headerBounds?.y).toBeLessThan(120);
    await test.info().attach('startup-cold-warm.json', { body: JSON.stringify({ renderer, cold, warm }), contentType: 'application/json' });
    await writeFile(test.info().outputPath('startup-cold-warm.json'), JSON.stringify({ renderer, cold, warm, viewport: await viewportEvidence(page), headerBounds }, null, 2));
    await page.screenshot({ path: test.info().outputPath(`startup-${renderer}-ready.png`), fullPage: true });
  });
}

for (const scenario of ['empty', 'error'] as const) {
  test(`startup exposes the ${scenario} terminal state and account exit`, async ({ page }) => {
    await startupHost(page, { scenario });
    await expect.poll(async () => (await readyEvents(page)).length).toBe(1);
    const currentView = await page.evaluate(() => (window as unknown as FixtureBrowser).qaCurrentView);
    checkReadyEvent((await readyEvents(page))[0], currentView);
    if (scenario === 'empty') {
      await expect(page.getByRole('group', { name: /^ไม่พบร้านที่บัญชีนี้มีสิทธิ์จัดการ / })).toBeVisible();
    } else {
      await expect(page.getByText('การเชื่อมต่อทดสอบขัดข้อง', { exact: true })).toBeVisible();
    }
    await expect(page.getByRole('button', { name: 'ออกจากระบบ', exact: true })).toBeEnabled();
  });
}

test('removing a pending view prevents its late ready event from reaching a new view', async ({ page }) => {
  await startupHost(page, { holdStores: true });
  await expect(page.locator('[aria-label="กำลังโหลดข้อมูลร้าน"]').or(page.getByText('กำลังโหลดข้อมูลร้าน', { exact: true })).first()).toBeVisible();
  const views = await page.evaluate(() => (window as unknown as FixtureBrowser).qaRemount());
  expect(views.current).not.toBe(views.previous);
  await expect.poll(async () => (await readyEvents(page)).length).toBe(1);
  checkReadyEvent((await readyEvents(page))[0], views.current);
  await page.evaluate(() => (window as unknown as FixtureBrowser).qaReleaseStores());
  await expect(page.getByText('ร้านเริ่มต้น QA', { exact: true }).first()).toBeVisible();
  // Let pending read completions and their post-frame callbacks run.
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  expect((await readyEvents(page)).map(event => event.viewId)).toEqual([views.current]);
});

test('unavailable fallback fonts have a bounded startup result', async ({ page }) => {
  let releaseFonts!: () => void;
  const fontsReady = new Promise<void>(resolve => { releaseFonts = resolve; });
  let fallbackRequests = 0;
  // Roboto may be an engine-initialization prerequisite; hold only the Thai
  // fallback whose readiness the Merchant warmup bounds after main starts.
  await page.route('https://fonts.gstatic.com/s/notosansthai/**', async route => {
    fallbackRequests++;
    await fontsReady;
    await route.abort();
  });
  try {
    await startupHost(page);
    await expect.poll(async () => (await readyEvents(page)).length).toBe(1);
    await expect.poll(() => fallbackRequests).toBeGreaterThan(0);
    const event = (await readyEvents(page))[0];
    expect(event.fontWarmupTimedOut).toBe(true);
    expect(event.fontWarmupMs).toBeGreaterThanOrEqual(1_100);
    expect(event.fontWarmupMs).toBeLessThan(10_000);
  } finally {
    releaseFonts();
  }
});

test('menu images remain lazy and delayed images preserve row geometry', async ({ page }) => {
  let releaseImages!: () => void;
  const imagesReady = new Promise<void>(resolve => { releaseImages = resolve; });
  const requested = new Set<string>();
  const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACgAAABQCAIAAADk7aCWAAAAPklEQVR4nO3NQQEAAAQEMPTvfGLw2Aqsk9SFOVnFYrFYLBaLxWKxWCwWi8VisVgsFovFYrFYLBaLxWKx+G289qoDnUEG01QAAAAASUVORK5CYII=', 'base64');
  await page.route('**/merchant-startup-image-*.png', async route => {
    requested.add(new URL(route.request().url()).pathname);
    await imagesReady;
    await route.fulfill({ contentType: 'image/png', body: image });
  });
  try {
    await startupHost(page, { menuCount: 50 });
    await expect.poll(async () => (await readyEvents(page)).length).toBe(1);
    expect(requested.size).toBe(0);
    await page.getByRole('tab', { name: 'เมนูอาหาร', exact: true }).or(page.getByRole('button', { name: 'เมนูอาหาร', exact: true })).first().click();
    // The decorative Image can merge the row's text into an image/group name.
    // Stable action semantics remain separate in both pending/decoded states.
    const edit = page.getByRole('button', { name: 'แก้ไขเมนู อาหารทดสอบ 1', exact: true });
    const toggle = page.getByRole('switch', { name: 'เปิดขาย อาหารทดสอบ 1', exact: true });
    await expect(edit).toBeVisible();
    await expect(toggle).toBeEnabled();
    await expect.poll(() => requested.size).toBeGreaterThan(0);
    expect(requested.size).toBeLessThan(50);
    const before = { edit: await edit.boundingBox(), toggle: await toggle.boundingBox() };
    await page.screenshot({ path: test.info().outputPath('startup-menu-image-pending.png'), fullPage: true });
    const imageFinished = page.waitForResponse(response => /\/merchant-startup-image-0\.png$/.test(response.url()) && response.status() === 200);
    releaseImages();
    await imageFinished;
    await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
    await expect(edit).toBeVisible();
    const after = { edit: await edit.boundingBox(), toggle: await toggle.boundingBox() };
    expect(after).toEqual(before);
    await page.screenshot({ path: test.info().outputPath('startup-menu-image-ready.png'), fullPage: true });
  } finally {
    releaseImages();
  }
});
