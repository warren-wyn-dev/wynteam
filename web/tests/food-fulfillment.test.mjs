import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
const source=readFileSync(new URL('../lib/food-customer.ts',import.meta.url),'utf8');
const code=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const exports={};runInNewContext(code,{exports,Date,Intl,require:()=>({})});
const api=exports;
function fixture(result={}) {
 const calls=[]; const client={rpc:async(name,args)=>{calls.push({name,args});return {data:result,error:null};},functions:{invoke:()=>{throw Error('unexpected provider invocation');}}};
 return {client,calls};
}
const items=[{menu_item_id:'item',quantity:1,note:'',selected_options:[]}];
test('pickup quote uses v3 without customer coordinates and only trusts server-issued valid slots',async()=>{
 const h=fixture({subtotal:75,total:75,delivery_fee:0,fulfillment_type:'pickup',pickup_slots:['2026-10-26T06:00:00Z','invalid',123]});
 const quote=await api.quoteFoodCustomerOrder(h.client,'store',items,{latitude:16,longitude:103},'SAVE','pickup');
 assert.equal(h.calls[0].name,'food_quote_order_v3');assert.equal(h.calls[0].args.p_latitude,null);assert.equal(h.calls[0].args.p_longitude,null);
 assert.equal(h.calls[0].args.p_fulfillment_type,'pickup');assert.equal(h.calls[0].args.p_coupon_code,'SAVE');
 assert.deepEqual(JSON.parse(JSON.stringify(quote.pickup_slots)),['2026-10-26T06:00:00Z']);assert.equal(quote.delivery_fee,0);
});
test('delivery quote preserves coordinates and coupon, missing new RPC never falls back to delivery semantics',async()=>{
 const h=fixture();await api.quoteFoodCustomerOrder(h.client,'store',items,{latitude:16,longitude:103},null,'delivery');
 assert.equal(h.calls[0].args.p_latitude,16);assert.equal(h.calls[0].args.p_longitude,103);
 let count=0;await assert.rejects(api.quoteFoodCustomerOrder({rpc:async()=>{count++;return {error:{message:'missing v3'}};}},'store',items,null,null,'pickup'));
 assert.equal(count,1);
});
test('pickup creates with contact and slot, no address pin, while delivery COD is explicit',async()=>{
 const h=fixture('order');
 const common={recipientName:'Customer',recipientPhone:'0811111111',shippingAddress:'',items,location:{latitude:16,longitude:103}};
 await api.createFoodCustomerOrder(h.client,'store',{...common,fulfillmentType:'pickup',pickupAt:'2026-10-26T06:00:00Z',paymentMethod:'transfer'});
 assert.equal(h.calls[0].name,'food_create_order_v3');assert.equal(h.calls[0].args.p_latitude,null);assert.equal(h.calls[0].args.p_pickup_at,'2026-10-26T06:00:00Z');assert.equal(h.calls[0].args.p_payment_method,'transfer');
 await api.createFoodCustomerOrder(h.client,'store',{...common,shippingAddress:'Delivery address',fulfillmentType:'delivery',paymentMethod:'cod'});
 assert.equal(h.calls[1].args.p_payment_method,'cod');assert.equal(h.calls[1].args.p_pickup_at,null);assert.equal(h.calls[1].args.p_latitude,16);
});
test('new transfer slips always wait for store verification without invoking an external provider',async()=>{
 const h=fixture();const result=await api.submitFoodPayment(h.client,'order','private/slip.jpg');
 assert.equal(result.status,'manual_review');assert.equal(h.calls.length,1);assert.equal(h.calls[0].name,'food_submit_payment');
});
test('cancellation requests use the own-order RPC and failures are surfaced',async()=>{
 const h=fixture();await api.requestFoodCustomerCancellation(h.client,'order',' Change plans ');
 assert.equal(h.calls[0].name,'food_request_cancel');assert.equal(h.calls[0].args.p_note,'Change plans');
 await assert.rejects(api.requestFoodCustomerCancellation({rpc:async()=>({error:{message:'not owner'}})},'order','note'),/not owner/);
});
test('pickup status labels cover ready and terminal states while checkout keeps slot membership and separate quote keys',()=>{
 assert.equal(api.foodOrderStatusLabel('ready_for_pickup'),'พร้อมให้รับ');assert.equal(api.foodOrderStatusLabel('picked_up'),'รับอาหารแล้ว');
 const ui=readFileSync(new URL('../components/food/wynos-food-developer-app.tsx',import.meta.url),'utf8');
 assert.match(ui,/pickupSlots\.includes\(pickupAt\)/);assert.match(ui,/const key = `\$\{fulfillmentType\}/);
 assert.match(ui,/onSubmit\(pickup \? null : address/);assert.match(ui,/scheduledFor: null/);
 assert.match(ui,/!FOOD_STRIPE_PAUSED && orderStore\?\.stripe_payments_enabled/);
});
