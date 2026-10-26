import {test, expect} from '@playwright/test';
const USER='11111111-1111-4111-8111-111111111111', STORE='22222222-2222-4222-8222-222222222222', ITEM='33333333-3333-4333-8333-333333333333';
test.use({serviceWorkers:'block'});
for(const mode of ['pickup','cod'] as const) test(`Food ${mode} checkout submits the correct server contract`,async({page})=>{
 page.on('pageerror',error=>console.log('Food fixture page error:',error.message));
 const calls:Array<{name:string,args:Record<string,unknown>}>=[];
 const store={id:STORE,slug:'fixture',name:'ร้านทดสอบรับเอง',address:'ที่อยู่ร้านจำลอง',phone:'0811111111',is_open:true,is_published:true,pickup_enabled:true,delivery_enabled:true,cod_enabled:true,prep_minutes:15,delivery_fee:0,minimum_order:0,promptpay_id:'0811111111',promptpay_name:'ร้านจำลอง',created_at:'2026-01-01T00:00Z'};
 const item={id:ITEM,store_id:STORE,name:'QA Meal',category:'อาหาร',price:75,is_available:true,options:[],sort_order:0};
 const slot=new Date(Date.now()+60*60*1000).toISOString();
 const address={id:'44444444-4444-4444-8444-444444444444',user_id:USER,label:'บ้าน',recipient_name:'ลูกค้าจำลอง',recipient_phone:'0811111111',address:'ที่อยู่จำลอง',province:'มหาสารคาม',district:'เมืองมหาสารคาม',subdistrict:'ตลาด',postal_code:'44000',is_default:true};
 await page.route('**/auth/v1/**',route=>route.fulfill({contentType:'application/json',body:'{}'}));
 await page.route('**/rest/v1/**',async route=>{
   const path=new URL(route.request().url()).pathname;let data:unknown=[];
   if(path.includes('/rpc/')) {
     const name=path.split('/').pop()!;const args=route.request().postDataJSON()??{};calls.push({name,args});
     if(['food_customer_access_enabled','food_public_access_enabled'].includes(name))data=true;
     else if(name==='is_developer_account')data=false;
     else if(name==='food_store_directory_v2')data=[{...store,categories:['อาหาร'],rating_count:0}];
     else if(name.startsWith('food_quote_order'))data={subtotal:75,total:75,delivery_fee:0,campaign_discount:0,delivery_discount:0,fulfillment_type:args.p_fulfillment_type??'delivery',pickup_slots:[slot]};
     else if(name==='food_create_order_v3')data='55555555-5555-4555-8555-555555555555';
     else if(name==='food_my_store_reviews')data=[];
     else if(name.includes('review'))data={reviews:[],count:0,average:0};
   } else if(path.endsWith('/food_stores'))data=store;
   else if(path.endsWith('/food_menu_items'))data=[item];
   else if(path.endsWith('/food_customer_addresses'))data=mode==='pickup'?[]:[address];
   return route.fulfill({contentType:'application/json',body:JSON.stringify(data)});
 });
 await page.addInitScript(({USER,STORE,ITEM})=>{
  const key='zoky.food.fulfillment.fixture';const exp=Math.floor(Date.now()/1000)+3600;
  const token=btoa(JSON.stringify({alg:'HS256',typ:'JWT'}))+'.'+btoa(JSON.stringify({sub:USER,aud:'authenticated',role:'authenticated',exp}))+'.synthetic';
  localStorage.setItem('wynos.active-account-storage.v1',key);
  localStorage.setItem(key,JSON.stringify({access_token:token,refresh_token:'synthetic',token_type:'bearer',expires_at:exp,expires_in:3600,user:{id:USER,aud:'authenticated',role:'authenticated',is_anonymous:false,email:'fixture@example.test',app_metadata:{},user_metadata:{}}}));
  localStorage.setItem(`wynos-food-store-v1:${USER}`,STORE);
  localStorage.setItem(`wynos-food-cart-v1:${USER}`,JSON.stringify([{menu_item_id:ITEM,quantity:1,note:'',selected_options:[]}]));
 },{USER,STORE,ITEM});
 await page.goto('/food?store='+STORE);
 await expect(page.getByText('QA Meal',{exact:true}).first()).toBeVisible({timeout:45000});
 await page.getByRole('button',{name:/ตะกร้า/}).first().click();
 await page.getByRole('button',{name:'ไปชำระเงิน',exact:true}).click();
 if(mode==='pickup') {
  await page.getByRole('radio',{name:'รับเองที่ร้าน',exact:true}).check();
  await page.getByLabel('ชื่อผู้รับอาหาร',{exact:true}).fill('ลูกค้าจำลอง');
  await page.getByLabel('เบอร์โทรผู้รับอาหาร',{exact:true}).fill('0811111111');
  await page.getByRole('combobox',{name:/เวลารับอาหารวันนี้/}).selectOption(slot);
  await expect(page.getByRole('button',{name:'เพิ่มที่อยู่ก่อนสั่ง',exact:true})).toHaveCount(0);
 } else await page.getByRole('radio',{name:'จ่ายเงินสดตอนรับของ',exact:true}).check();
 await page.getByRole('button',{name:'ยืนยันคำสั่งซื้อ',exact:true}).click();
 await expect.poll(()=>calls.filter(c=>c.name==='food_create_order_v3').length).toBe(1);
 const args=calls.find(c=>c.name==='food_create_order_v3')!.args;
 expect(args.p_fulfillment_type).toBe(mode==='pickup'?'pickup':'delivery');
 expect(args.p_payment_method).toBe(mode==='cod'?'cod':'transfer');
 if(mode==='pickup'){expect(args.p_pickup_at).toBe(slot);expect(args.p_latitude).toBe(null);}
 await page.screenshot({path:test.info().outputPath(`food-${mode}.png`),fullPage:true});
});
