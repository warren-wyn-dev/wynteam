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
    window.qaWrites=[];
    window.zokyMerchant={request:async(method,raw)=>{
      const a=JSON.parse(raw);let data=null;
      switch(method){
        case 'stores':data=[store];break;
        case 'hasRole':data=true;break;
        case 'menu':data=[{id:'menu-1',name:'ข้าวกะเพรา',price:75,category:'อาหาร',is_available:true}];break;
        case 'orders':data=order.status===a.status?[order]:[];break;
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
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="_flutter.loader.load({config:{entrypointBaseUrl:'/merchant-flutter/',assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})"></script></body></html>`}));
  await page.goto('/merchant-flutter-qa');
  await page.locator('flutter-view').waitFor({timeout:45000});
  await expect(page.getByText('ร้าน QA',{exact:true}).first()).toBeVisible({timeout:30000});
  await page.getByRole('tab',{name:'ออเดอร์',exact:true}).or(page.getByRole('button',{name:'ออเดอร์',exact:true})).first().click();
  await page.getByRole('button',{name:'ตรวจการชำระเงิน',exact:true}).click();
  if (manualPayment) {
    await expect(page.getByRole('button',{name:'ยืนยันว่ารับเงินแล้ว',exact:true})).toBeDisabled();
    await page.getByRole('checkbox',{name:'ตรวจสอบแล้วว่าได้รับเงินครบตามยอด',exact:true}).click();
  }
  await expect(page.getByRole('button',{name:'ยืนยันว่ารับเงินแล้ว',exact:true})).toBeEnabled();
  await page.getByRole('button',{name:'ยืนยันว่ารับเงินแล้ว',exact:true}).click();
  await page.getByRole('button',{name:'รับออเดอร์',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยัน',exact:true}).click();
  await page.getByRole('checkbox',{name:'กำลังเตรียม',exact:true}).click();
  await page.getByRole('button',{name:'อาหารพร้อมแล้ว',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยัน',exact:true}).click();
  await page.getByRole('checkbox',{name:'พร้อมส่ง',exact:true}).click();
  await page.getByRole('button',{name:'เริ่มจัดส่ง',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยัน',exact:true}).click();
  await page.getByRole('checkbox',{name:'กำลังจัดส่ง',exact:true}).click();
  await page.getByRole('button',{name:'แนบรูปและยืนยันส่งสำเร็จ',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยันส่งสำเร็จ',exact:true}).click();
  await expect(page.getByRole('alertdialog').getByText('กรุณาแนบรูปหลักฐานส่งสำเร็จ',{exact:true}).first()).toBeVisible();
  await page.getByRole('button',{name:'แนบรูปหลักฐาน (จำเป็น)',exact:true}).click();
  await page.getByRole('button',{name:'ยืนยันส่งสำเร็จ',exact:true}).click();
  await page.getByRole('checkbox',{name:'สำเร็จ',exact:true}).click();
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
      </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="_flutter.loader.load({config:{entrypointBaseUrl:'/merchant-flutter/',assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})"></script></body></html>`}));
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
    window.qaWrites=[];
    window.zokyMerchant={request:async(method,raw)=>{
      const a=JSON.parse(raw);let data=null;
      switch(method){
        case 'stores':data=[store];break;
        case 'hasRole':data=true;break;
        case 'orders':data=a.status===order.status?[order]:[];break;
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
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="_flutter.loader.load({config:{entrypointBaseUrl:'/merchant-flutter/',assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})"></script></body></html>` }));
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
  await page.getByRole('checkbox', { name: 'พร้อมส่ง/ให้รับ', exact: true }).click();
  await page.getByRole('button', { name: 'ลูกค้ารับแล้ว', exact: true }).click();
  await page.getByRole('button', { name: 'ยืนยัน', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as Window & {qaWrites?: string[]}).qaWrites)).toEqual(['reject', 'ready_for_pickup', 'picked_up']);
});
