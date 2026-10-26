import { expect, test, type Locator, type Page } from '@playwright/test';

type SaveFixture = Window & {
  qaHoldReport?: boolean;
  qaReleaseReport?: () => void;
  qaWrites?: { name: string; price: number }[];
};

async function focusForTyping(page: Page, field: Locator) {
  await field.click();
  await expect(field).toBeFocused();
  // Flutter applies native-input focus on its next frame. Wait for that handoff
  // before sending keyboard events, including on WebKit.
  await page.evaluate(() => new Promise<void>((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  }));
}

test('an open menu draft saves once after a background refresh completes', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  // The actual compiled renderer runs against an isolated synthetic bridge;
  // this page never authenticates or calls a real merchant API.
  await page.route('**/merchant-editor-refresh-qa', route => route.fulfill({
    contentType: 'text/html; charset=utf-8',
    body: `<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
      const store={id:'store-1',name:'ร้านทดสอบรีเฟรช',is_open:true,is_published:true,effective_open:true};
      window.qaHoldReport=false;window.qaWrites=[];
      window.zokyMerchant={request:async(method,raw)=>{
        const args=JSON.parse(raw);let data=null;
        switch(method){
          case 'stores':data=[store];break;
          case 'hasRole':data=true;break;
          case 'menu':case 'orders':data=[];break;
          case 'report':
            if(window.qaHoldReport)await new Promise(resolve=>window.qaReleaseReport=()=>{window.qaHoldReport=false;resolve();});
            data={today_sales:0,today_orders:0,month_sales:0,total_orders:0,best:[]};break;
          case 'quality':data={available:false};break;
          case 'campaigns':data={can_manage:true,campaigns:[]};break;
          case 'pushStatus':data={enabled:false,available:false};break;
          case 'saveMenu':window.qaWrites.push(args.values);break;
        }
        return JSON.stringify({ok:true,data});
      }};
      </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="_flutter.loader.load({config:{entrypointBaseUrl:'/merchant-flutter/',assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})"></script></body></html>`,
  }));
  await page.goto('/merchant-editor-refresh-qa');
  await expect(page.getByText('ร้านทดสอบรีเฟรช', { exact: true })).toBeVisible({ timeout: 45000 });
  await page.getByRole('tab', { name: 'เมนูอาหาร', exact: true })
    .or(page.getByRole('button', { name: 'เมนูอาหาร', exact: true })).first().click();
  await page.getByRole('button', { name: 'เพิ่มเมนู', exact: true }).click();
  const name = page.getByRole('textbox', { name: 'ชื่อเมนู', exact: true });
  const price = page.getByRole('textbox', { name: 'ราคา (บาท)', exact: true });
  await focusForTyping(page, name);
  await name.pressSequentially('draft during refresh');
  await focusForTyping(page, price);
  await price.pressSequentially('89');
  await expect(price).toHaveValue('89');
  await page.evaluate(() => {
    (window as SaveFixture).qaHoldReport = true;
    window.dispatchEvent(new Event('zoky-merchant-order-change'));
  });
  await expect.poll(() => page.evaluate(() => typeof (window as SaveFixture).qaReleaseReport)).toBe('function');
  await page.getByRole('button', { name: 'บันทึก', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as SaveFixture).qaWrites)).toEqual([]);
  await page.evaluate(() => (window as SaveFixture).qaReleaseReport!());
  await expect(page.getByText('เพิ่มเมนูอาหาร', { exact: true })).toHaveCount(0);
  await expect.poll(() => page.evaluate(() => (window as SaveFixture).qaWrites)).toEqual([
    { name: 'draft during refresh', price: 89, category: 'อาหาร', description: '' },
  ]);
  expect(errors).toEqual([]);
});
