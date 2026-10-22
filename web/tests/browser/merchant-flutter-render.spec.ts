import { expect, test } from '@playwright/test';

// A synthetic host exercises the actual compiled Flutter renderer without
// touching authentication, customer data, production APIs or payment services.
test('Flutter merchant processes slip review through mandatory photo completion', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  const image = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACgAAABQCAIAAADk7aCWAAAAPklEQVR4nO3NQQEAAAQEMPTvfGLw2Aqsk9SFOVnFYrFYLBaLxWKxWCwWi8VisVgsFovFYrFYLBaLxWKx+G289qoDnUEG01QAAAAASUVORK5CYII=', 'base64');
  await page.route('**/merchant-qa-photo.png', route => route.fulfill({contentType:'image/png',body:image}));
  await page.route('**/merchant-flutter-qa', route => route.fulfill({contentType:'text/html; charset=utf-8',body:`<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body,#host{margin:0;width:100%;height:100%;overflow:hidden}</style></head><body><div id="host"></div><script>
    const store={id:'store-1',name:'ร้าน QA',is_open:true,is_published:true,phone:'0811111111',address:'ที่อยู่ทดสอบ'};
    const order={id:'order-1',order_number:'QA-001',status:'pending_acceptance',payment_status:'submitted',payment_slip_path:'slips/order-1/slip.png',recipient_name:'ลูกค้าทดสอบ',recipient_phone:'0811111111',shipping_address:'ที่อยู่ทดสอบ',total:75,subtotal:75,delivery_fee:0,created_at:'2026-10-21T03:00:00Z',food_order_items:[{item_name:'ข้าวกะเพรา',quantity:1}]};
    window.qaWrites=[];
    window.zokyMerchant={request:async(method,raw)=>{
      const a=JSON.parse(raw);let data=null;
      switch(method){
        case 'stores':data=[store];break;
        case 'hasRole':data=true;break;
        case 'menu':data=[{id:'menu-1',name:'ข้าวกะเพรา',price:75,category:'อาหาร',is_available:true}];break;
        case 'orders':data=order.status===a.status?[order]:[];break;
        case 'report':data={today_sales:order.status==='delivered'?75:0,today_orders:order.status==='delivered'?1:0,month_sales:order.status==='delivered'?75:0,total_orders:order.status==='delivered'?1:0,best:[]};break;
        case 'campaigns':data={can_manage:true,campaigns:[]};break;
        case 'pushStatus':data={enabled:false,available:false};break;
        case 'signedUrl':data=location.origin+'/merchant-qa-photo.png';break;
        case 'payment':order.payment_status=a.status;window.qaWrites.push(method);break;
        case 'transition':if(order.payment_status!=='paid')return JSON.stringify({ok:false,error:'ต้องชำระก่อน'});order.status=a.status;window.qaWrites.push(a.status);break;
        case 'pickDeliveryPhoto':data={path:'delivery/order-1/proof.png',previewUrl:location.origin+'/merchant-qa-photo.png'};break;
        case 'completeDelivery':if(!a.imagePath)return JSON.stringify({ok:false,error:'ต้องแนบรูป'});order.status='delivered';window.qaWrites.push('delivered');break;
      }
      return JSON.stringify({ok:true,data});
    }};
    </script><script src="/merchant-flutter/flutter_bootstrap.js" onload="_flutter.loader.load({config:{entrypointBaseUrl:'/merchant-flutter/',assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'},onEntrypointLoaded:async(i)=>{const r=await i.initializeEngine({multiViewEnabled:true,assetBase:'/merchant-flutter/',canvasKitBaseUrl:'/merchant-flutter/canvaskit/'});const app=await r.runApp();app.addView({hostElement:document.querySelector('#host')});}})"></script></body></html>`}));
  await page.goto('/merchant-flutter-qa');
  await page.locator('flutter-view').waitFor({timeout:45000});
  await expect(page.getByText('ร้าน QA',{exact:true}).first()).toBeVisible({timeout:30000});
  await page.getByRole('button',{name:'จัดการออเดอร์ →',exact:true}).click();
  await page.getByRole('button',{name:'ตรวจการชำระเงิน',exact:true}).click();
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
});
