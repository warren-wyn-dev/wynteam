import { expect, test } from '@playwright/test';

// A synthetic host exercises the actual compiled Flutter renderer without
// touching authentication, customer data, production APIs or payment services.
for (const manualPayment of [false, true]) {
test(`Flutter merchant processes ${manualPayment ? 'manual no-slip payment' : 'slip review'} through mandatory photo completion`, async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACgAAABQCAIAAADk7aCWAAAAPklEQVR4nO3NQQEAAAQEMPTvfGLw2Aqsk9SFOVnFYrFYLBaLxWKxWCwWi8VisVgsFovFYrFYLBaLxWKx+G289qoDnUEG01QAAAAASUVORK5CYII=', 'base64');
  await page.route('**/merchant-qa-photo.png', route => route.fulfill({contentType:'image/png',body:image}));
  await page.route('**/merchant-flutter-qa', route => route.fulfill({contentType:'text/html; charset=utf-8',body:`<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
    const store={id:'store-1',name:'ร้าน QA',is_open:true,is_published:true,phone:'0811111111',address:'ที่อยู่ทดสอบ',business_hours:'09:00–22:00',delivery_area:'พื้นที่ทดสอบ',effective_open:true,status_text:'เปิดรับออเดอร์'};
    const order={id:'order-1',order_number:'QA-001',status:'pending_acceptance',payment_status:'${manualPayment ? 'pending' : 'submitted'}',payment_slip_path:${manualPayment ? 'null' : "'slips/order-1/slip.png'"},recipient_name:'ลูกค้าทดสอบ',recipient_phone:'0811111111',shipping_address:'ที่อยู่ทดสอบ',total:75,subtotal:75,delivery_fee:0,created_at:'2026-10-21T03:00:00Z',food_order_items:[{item_name:'ข้าวกะเพรา',quantity:1}]};
    window.qaWrites=[];const orderTab=s=>s==='ready_for_delivery'||s==='out_for_delivery'?'delivering':s;
    window.zokyMerchant={request:async(method,raw)=>{
      const a=JSON.parse(raw);let data=null;
      switch(method){
        case 'stores':data=[store];break;
        case 'hasRole':data=true;break;
        case 'menu':data=[{id:'menu-1',name:'ข้าวกะเพรา',price:75,category:'อาหาร',is_available:true}];break;
        case 'orders':data=orderTab(order.status)===a.status?[order]:[];break;
        case 'report':data={today_sales:order.status==='delivered'?75:0,today_orders:order.status==='delivered'?1:0,month_sales:order.status==='delivered'?75:0,total_orders:order.status==='delivered'?1:0,best:[]};break;
        case 'quality':data={available:true,count:12,average:4.8,unanswered:2};break;
        case 'campaigns':data={can_manage:true,campaigns:[]};break;
        case 'pushStatus':data={enabled:false,available:false};break;
        case 'signedUrl':data=location.origin+'/merchant-qa-photo.png';break;
        case 'payment':if(!order.payment_slip_path && !a.manualConfirmation)throw new Error('manual receipt confirmation missing');order.payment_status=a.status;window.qaWrites.push(method);break;
        case 'transition':if(a.status==='preparing' && !(a.etaMinutes>=1))throw new Error('preparation ETA missing');if(order.payment_status!=='paid')return JSON.stringify({ok:false,error:'ต้องชำระก่อน'});order.status=a.status;window.qaWrites.push(a.status);break;
        case 'pickDeliveryPhoto':data={path:'delivery/order-1/proof.png',previewUrl:location.origin+'/merchant-qa-photo.png'};break;
        case 'completeDelivery':if(!a.imagePath)return JSON.stringify({ok:false,error:'ต้องแนบรูป'});order.status='delivered';window.qaWrites.push('delivered');break;
      }
      return JSON.stringify({ok:true,data});
    }};
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="(()=>{const b=_flutter.merchantAssetBase||'/merchant-flutter/';_flutter.loader.load({config:{entrypointBaseUrl:b,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/'),forceSingleThreadedSkwasm:true},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/')});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})})()"></script></body></html>`}));
  await page.goto('/merchant-flutter-qa');
  await page.locator('flutter-view').waitFor({timeout:45000});
  await expect(page.getByText('ร้าน QA',{exact:true}).first()).toBeVisible({timeout:30000});
  await page.getByRole('tab',{name:'ออเดอร์',exact:true}).or(page.getByRole('button',{name:'ออเดอร์',exact:true})).first().click();
  // One action checks the payment and accepts with the ETA chosen on the card.
  await page.getByRole('button',{name:manualPayment ? 'ตรวจเงินเข้า · รับออเดอร์' : 'ตรวจสลิป · รับออเดอร์',exact:true}).click();
  if (manualPayment) {
    await expect(page.getByRole('button',{name:'ยืนยันว่ารับเงินแล้ว',exact:true})).toBeDisabled();
    await page.getByRole('checkbox',{name:'ตรวจสอบแล้วว่าได้รับเงินครบตามยอด',exact:true}).click();
  }
  await expect(page.getByRole('button',{name:'ยืนยันว่ารับเงินแล้ว',exact:true})).toBeEnabled();
  await page.getByRole('button',{name:'ยืนยันว่ารับเงินแล้ว',exact:true}).click();
  await page.getByRole('checkbox',{name:'กำลังเตรียม',exact:true}).click();
  await page.getByRole('button',{name:'อาหารพร้อมแล้ว',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยัน',exact:true}).click();
  await page.getByRole('checkbox',{name:'จัดส่ง',exact:true}).click();
  await page.getByRole('button',{name:'เริ่มจัดส่ง',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยัน',exact:true}).click();
  // Ready and out-for-delivery orders share the "จัดส่ง" tab.
  await page.getByRole('button',{name:'แนบรูปและยืนยันส่งสำเร็จ',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยันส่งสำเร็จ',exact:true}).click();
  await expect(page.getByRole('alertdialog').getByText('กรุณาแนบรูปหลักฐานส่งสำเร็จ',{exact:true}).first()).toBeVisible();
  await page.getByRole('button',{name:'แนบรูปหลักฐาน (จำเป็น)',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยันส่งสำเร็จ',exact:true}).click();
  await page.getByRole('checkbox',{name:'เสร็จ',exact:true}).click();
  await expect(page.getByRole('group',{name:/#QA-001/}).first()).toBeVisible();
  await expect.poll(()=>page.evaluate(()=> (window as Window & {qaWrites?: string[]}).qaWrites)).toEqual(['payment','preparing','ready_for_delivery','out_for_delivery','delivered']);
  expect(errors).toEqual([]);
  await page.screenshot({path:test.info().outputPath('merchant-completed.png'),fullPage:true});
  // A fresh synthetic document removes queued mutation toasts from design captures.
  await page.reload();
  await expect(page.getByRole('button',{name:/ยอดขายวันนี้/}).first()).toBeVisible();
  // This isolated fixture has no network polling; wait for renderer/font requests.
  await page.waitForLoadState('networkidle');
  await page.screenshot({path:test.info().outputPath('merchant-dashboard.png'),fullPage:true});
  // Quality is a tool destination; its metrics describe all reviews, not a
  // fabricated weekly summary or a duplicate card at the bottom of the home.
  await expect(page.getByText('คุณภาพร้านสัปดาห์นี้',{exact:true})).toHaveCount(0);
  const quality = page.getByRole('button',{name:'คุณภาพร้าน',exact:true});
  await quality.scrollIntoViewIfNeeded();
  await quality.click();
  await expect(page.getByText(/รีวิวทั้งหมด/)).toBeVisible();
  await expect(page.getByRole('button',{name:'ดูรีวิวและตอบกลับ',exact:true})).toBeVisible();
  await expect(page.getByText(/4\.8 \/5/)).toBeVisible();
  await page.screenshot({path:test.info().outputPath('merchant-quality.png'),fullPage:true});
  await page.getByRole('tab',{name:'เมนูอาหาร',exact:true}).or(page.getByRole('button',{name:'เมนูอาหาร',exact:true})).first().click();
  await expect(page.getByRole('switch',{name:'เปิดขาย ข้าวกะเพรา',exact:true})).toBeVisible();
  await page.screenshot({path:test.info().outputPath('merchant-menu.png'),fullPage:true});
  await page.getByRole('tab',{name:'เพิ่มเติม',exact:true}).or(page.getByRole('button',{name:'เพิ่มเติม',exact:true})).click();
  await expect(page.getByRole('button',{name:'รายงานยอดขาย',exact:true})).toBeVisible();
  await page.screenshot({path:test.info().outputPath('merchant-more.png'),fullPage:true});
});

}

for (const scenario of ['empty', 'offline', 'revoked'] as const) {
  test(`Flutter account exit remains available after ${scenario} store access`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('**/merchant-account-exit-qa', route => route.fulfill({contentType:'text/html; charset=utf-8', body:`<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
      const scenario=${JSON.stringify(scenario)};
      const store={id:'store-1',name:'ร้านบัญชีทดสอบ',is_open:true,is_published:true,effective_open:true};
      window.qaStoreAccess=true;window.qaSignedOut=0;
      window.zokyMerchant={request:async(method)=>{
        let data=null;
        switch(method){
          case 'stores':
            if(scenario==='offline')return JSON.stringify({ok:false,error:'offline'});
            data=scenario==='revoked'&&window.qaStoreAccess?[store]:[];break;
          case 'hasRole':data=true;break;
          case 'menu':case 'orders':data=[];break;
          case 'report':data={today_sales:0,today_orders:0,month_sales:0,total_orders:0,best:[]};break;
          case 'quality':data={available:false};break;
          case 'campaigns':data={can_manage:true,campaigns:[]};break;
          case 'pushStatus':data={enabled:false,available:false};break;
          case 'signOut':window.qaSignedOut++;break;
        }
        return JSON.stringify({ok:true,data});
      }};
      </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="(()=>{const b=_flutter.merchantAssetBase||'/merchant-flutter/';_flutter.loader.load({config:{entrypointBaseUrl:b,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/'),forceSingleThreadedSkwasm:true},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/')});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})})()"></script></body></html>`}));
    await page.goto('/merchant-account-exit-qa');
    await page.locator('flutter-view').waitFor({timeout:45000});
    if (scenario === 'revoked') {
      await expect(page.getByText('ร้านบัญชีทดสอบ',{exact:true})).toBeVisible({timeout:30000});
      await expect(page.getByRole('button',{name:/ยอดขายวันนี้/}).first()).toBeVisible();
      await page.evaluate(() => {
        (window as Window & {qaStoreAccess?:boolean}).qaStoreAccess=false;
        window.dispatchEvent(new Event('zoky-merchant-order-change'));
      });
      await expect(page.getByText('ร้านบัญชีทดสอบ',{exact:true})).toHaveCount(0);
    }
    const exit = page.getByRole('button',{name:'ออกจากระบบ',exact:true});
    await expect(exit).toBeVisible({timeout:30000});
    await exit.click();
    await expect.poll(() => page.evaluate(() => (window as Window & {qaSignedOut?:number}).qaSignedOut)).toBe(1);
    expect(errors).toEqual([]);
  });
}

test('pickup cancellation rejection refreshes the order and pickup completes without delivery evidence', async ({ page }) => {
  await page.route('**/merchant-fulfillment-qa', route => route.fulfill({ contentType: 'text/html; charset=utf-8', body: `<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
    const store={id:'store-1',name:'ร้านรับเอง QA',is_open:true,is_published:true,effective_open:true};
    const order={id:'order-1',order_number:'PICKUP-01',status:'preparing',fulfillment_type:'pickup',payment_method:'transfer',payment_status:'paid',pickup_at:'2026-10-26T05:00:00Z',pickup_code:'A23',cancel_requested_at:'2026-10-26T04:00:00Z',cancel_request_note:'ขอเปลี่ยนแผน',recipient_name:'ลูกค้าทดสอบ',recipient_phone:'0811111111',total:75,subtotal:75,delivery_fee:0,created_at:'2026-10-26T03:00:00Z',food_order_items:[]};
    window.qaWrites=[];const orderTab=s=>s==='ready_for_delivery'||s==='out_for_delivery'?'delivering':s;
    window.zokyMerchant={request:async(method,raw)=>{
      const a=JSON.parse(raw);let data=null;
      switch(method){
        case 'stores':data=[store];break;
        case 'hasRole':data=true;break;
        case 'orders':data=a.status===orderTab(order.status)?[order]:[];break;
        case 'menu':data=[];break;
        case 'report':data={today_sales:0,today_orders:0,month_sales:0,total_orders:0,best:[]};break;
        case 'quality':data={available:false};break;
        case 'campaigns':data={can_manage:false,campaigns:[]};break;
        case 'pushStatus':data={enabled:false,available:false};break;
        case 'resolveCancel':if(a.approve)throw new Error('expected rejection');order.cancel_requested_at=null;window.qaWrites.push('reject');break;
        // Contract v2: the bridge maps pickup actions to the stored statuses.
        case 'transition':order.status=a.status==='ready_for_pickup'?'ready_for_delivery':a.status==='picked_up'?'delivered':a.status;window.qaWrites.push(a.status);break;
        case 'pickDeliveryPhoto':case 'completeDelivery':throw new Error('pickup must not use delivery evidence');
      }
      return JSON.stringify({ok:true,data});
    }};
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="(()=>{const b=_flutter.merchantAssetBase||'/merchant-flutter/';_flutter.loader.load({config:{entrypointBaseUrl:b,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/'),forceSingleThreadedSkwasm:true},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/')});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})})()"></script></body></html>` }));
  await page.goto('/merchant-fulfillment-qa');
  await expect(page.getByText('ร้านรับเอง QA', { exact: true }).first()).toBeVisible({ timeout: 45000 });
  await page.getByRole('tab', { name: 'ออเดอร์', exact: true }).or(page.getByRole('button', { name: 'ออเดอร์', exact: true })).first().click();
  await page.getByRole('checkbox', { name: 'กำลังเตรียม', exact: true }).click();
  await expect(page.getByRole('group', { name: /รหัสรับอาหาร: A23/ })).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('merchant-pickup-request.png'), fullPage: true });
  await expect(page.getByRole('button', { name: 'อนุมัติคำขอยกเลิก', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'ปฏิเสธคำขอยกเลิก', exact: true }).click();
  await page.getByRole('button', { name: 'ยืนยัน', exact: true }).click();
  await expect(page.getByRole('button', { name: 'ปฏิเสธคำขอยกเลิก', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'พร้อมให้รับ', exact: true }).click();
  await page.getByRole('button', { name: 'ยืนยัน', exact: true }).click();
  await page.getByRole('checkbox', { name: 'จัดส่ง', exact: true }).click();
  await page.getByRole('button', { name: 'ลูกค้ารับแล้ว', exact: true }).click();
  await page.getByRole('button', { name: 'ยืนยัน', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as Window & {qaWrites?: string[]}).qaWrites)).toEqual(['reject', 'ready_for_pickup', 'picked_up']);
});

async function performanceHost(page: import('@playwright/test').Page, holdSummaries = false, renderer?: 'canvaskit') {
  await page.route('**/merchant-performance-qa', route => route.fulfill({ contentType: 'text/html; charset=utf-8', body: `<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
    const stores=[{id:'store-a',name:'ร้าน QA A',is_open:true,is_published:true,effective_open:true},{id:'store-b',name:'ร้าน QA B',is_open:true,is_published:true,effective_open:true}];
    window.qaCounts={};window.qaWrites=[];const orderTab=s=>s==='ready_for_delivery'||s==='out_for_delivery'?'delivering':s;window.qaBlockOrders=false;window.qaAllowed=true;
    const summaries=new Promise(resolve=>window.qaReleaseSummaries=resolve);
    const waitingOrders=[];window.qaReleaseOrders=()=>{window.qaBlockOrders=false;waitingOrders.splice(0).forEach(resolve=>resolve());};
    window.zokyMerchant={request:async(method,raw)=>{
      const a=JSON.parse(raw);let data=null;
      window.qaCounts[method]=(window.qaCounts[method]||0)+1;
      if(${holdSummaries}&&['report','quality','campaigns'].includes(method))await summaries;
      if(method==='orders'&&window.qaBlockOrders)await new Promise(resolve=>waitingOrders.push(resolve));
      switch(method){
        case 'stores':data=window.qaAllowed?stores:[];break;
        case 'hasRole':data=window.qaAllowed;break;
        case 'menu':data=[{id:'menu-'+a.storeId,name:'เมนู '+a.storeId,price:75,category:'อาหาร',is_available:true}];break;
        case 'orders':data=[];break;
        case 'report':data={today_sales:100,today_orders:1,month_sales:100,total_orders:1,best:[]};break;
        case 'quality':data={available:false};break;
        case 'campaigns':data={can_manage:true,campaigns:[]};break;
        case 'finance':data={sales_net:a.storeId==='store-a'?1111:2222,orders:1,food:75,delivery:0,discounts:0,refunds:0,income:a.storeId==='store-a'?3333:4444,days:[]};break;
        case 'pushStatus':data={enabled:false,available:false};break;
        case 'saveMenu':window.qaWrites.push({method,storeId:a.storeId});break;
      }
      return JSON.stringify({ok:true,data});
    }};
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="(()=>{const b=_flutter.merchantAssetBase||'/merchant-flutter/';_flutter.loader.load({config:{entrypointBaseUrl:b,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/'),forceSingleThreadedSkwasm:true,renderer:${renderer === 'canvaskit' ? "'canvaskit'" : 'null'}},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:b,canvasKitBaseUrl:(_flutter.merchantCanvasKitBase||b+'canvaskit/')});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})})()"></script></body></html>` }));
  await page.goto('/merchant-performance-qa');
  expect(await page.evaluate(() => (window as Window & { _flutter?: { merchantAssetBase?: string } })._flutter?.merchantAssetBase)).toMatch(/^\/merchant-flutter\/builds\/[a-f0-9]{20}\/$/);
  await expect(page.getByText('ร้าน QA A', { exact: true }).first()).toBeVisible({ timeout: 45000 });
  await expect(page.locator('[flt-renderer]')).toHaveAttribute('flt-renderer', renderer ?? 'skwasm');
}

async function merchantTab(page: import('@playwright/test').Page, name: string) {
  await page.getByRole('tab', { name, exact: true }).or(page.getByRole('button', { name, exact: true })).first().click();
}

function counts(page: import('@playwright/test').Page) {
  return page.evaluate(() => (window as Window & { qaCounts?: Record<string, number> }).qaCounts ?? {});
}

test('critical menu stays usable while summaries and realtime order refresh are pending', async ({ page }) => {
  await performanceHost(page, true);
  const pendingSales = page.getByRole('group', { name: 'ยอดขายวันนี้ กำลังโหลดยอดขาย', exact: true });
  await expect(pendingSales).toBeVisible();
  await expect(pendingSales).not.toHaveAccessibleName(/฿0\.00/);
  await merchantTab(page, 'เมนูอาหาร');
  const available = page.getByRole('switch', { name: 'เปิดขาย เมนู store-a', exact: true });
  await expect(available).toBeVisible();
  await expect(available).toBeEnabled();
  await expect.poll(async () => (await counts(page)).report).toBe(1);
  const before = await counts(page);
  expect(before.stores).toBe(1);
  await page.evaluate(() => {
    const fixture = window as Window & { qaReleaseSummaries?: () => void; qaBlockOrders?: boolean };
    fixture.qaReleaseSummaries?.();
    fixture.qaBlockOrders = true;
    window.dispatchEvent(new Event('zoky-merchant-order-change'));
  });
  await expect.poll(async () => (await counts(page)).orders).toBeGreaterThan(before.orders);
  await expect(available).toBeEnabled();
  await expect(page.getByRole('button', { name: 'แก้ไขเมนู เมนู store-a', exact: true })).toBeEnabled();
  expect((await counts(page)).menu).toBe(before.menu);
  expect((await counts(page)).report).toBe(before.report);
  await page.evaluate(() => (window as Window & { qaReleaseOrders?: () => void }).qaReleaseOrders?.());
});

test('finance reuses the active store data across tab visits and evicts it on store change', async ({ page }) => {
  await performanceHost(page);
  await merchantTab(page, 'เพิ่มเติม');
  await page.getByRole('button', { name: 'การเงิน', exact: true }).click();
  const finance = page.getByRole('group', { name: /^ยอดขายสุทธิ / });
  await expect(finance).toBeVisible();
  await expect(finance).toHaveAccessibleName(/฿1111\.00/);
  expect((await counts(page)).finance).toBe(1);
  await merchantTab(page, 'เมนูอาหาร');
  await merchantTab(page, 'เพิ่มเติม');
  await page.getByRole('button', { name: 'การเงิน', exact: true }).click();
  await expect(finance).toBeVisible();
  await expect(finance).toHaveAccessibleName(/฿1111\.00/);
  expect((await counts(page)).finance).toBe(1);
  await page.getByRole('button', { name: 'ร้าน QA A', exact: true }).click();
  await page.getByRole('menuitem', { name: 'ร้าน QA B', exact: true }).click();
  await expect(page.getByRole('button', { name: 'ร้าน QA B', exact: true })).toBeVisible();
  await expect(page.getByRole('group', { name: /^ยอดขายสุทธิ .*฿1111\.00/ })).toHaveCount(0);
  await expect(finance).toHaveAccessibleName(/฿2222\.00/);
  expect((await counts(page)).finance).toBe(2);
  await page.evaluate(() => {
    (window as Window & { qaAllowed?: boolean }).qaAllowed = false;
    window.dispatchEvent(new Event('zoky-merchant-order-change'));
  });
  await expect(page.getByRole('group', { name: /^ยอดขายสุทธิ .*฿2222\.00/ })).toHaveCount(0);
});


test('CanvasKit fallback keeps the compiled Flutter menu interactive', async ({ page }) => {
  const requests: string[] = [];
  page.on('request', request => requests.push(new URL(request.url()).pathname));
  await performanceHost(page, false, 'canvaskit');
  await merchantTab(page, 'เมนูอาหาร');
  await expect(page.getByRole('switch', { name: 'เปิดขาย เมนู store-a', exact: true })).toBeEnabled();
  expect(requests.some(path => /\/main\.dart\.js$/.test(path))).toBe(true);
  expect(requests.some(path => /\/main\.dart\.wasm$/.test(path))).toBe(false);
});
