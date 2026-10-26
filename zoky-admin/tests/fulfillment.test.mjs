import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import {runInNewContext} from 'node:vm';
import ts from 'typescript';
function fixture() {
 const exports={}, calls=[]; let allowed=true;
 const client={rpc:async(name,args)=>{calls.push({name,args});return {data:[],error:null}},storage:{from:bucket=>({createSignedUrl:async(path,seconds)=>{calls.push({bucket,path,seconds});return {data:{signedUrl:'https://signed.example.test/refund'},error:null}}})}};
 const code=ts.transpileModule(readFileSync(new URL('../lib/admin-food.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 runInNewContext(code,{exports,Intl,Date,require:name=>name.includes('/auth')?{requireAdminRole:async()=>({}),adminCan:()=>allowed}:{createClient:async()=>client}});
 return {api:exports,calls,deny:()=>{allowed=false}};
}
test('refund aging excludes cash/Stripe and uses the actual refund request date',()=>{
 const {api}=fixture();const now=Date.parse('2026-10-27T12:00Z');
 const order={refund_status:'pending',payment_method:'transfer',created_at:'2026-10-20T12:00Z',refund_requested_at:'2026-10-27T11:00Z'};
 assert.equal(api.isOverdueTransferRefund(order,now),false);
 assert.equal(api.isOverdueTransferRefund({...order,refund_requested_at:'2026-10-26T11:59Z'},now),true);
 for(const patch of [{payment_method:'cod'},{payment_provider:'stripe'},{refund_status:'refunded'}])assert.equal(api.isOverdueTransferRefund({...order,refund_requested_at:'2026-10-20T12:00Z',...patch},now),false);
});
test('refund evidence is permission and order scoped and uses short-lived private signing',async()=>{
 const h=fixture();const order={id:'order',store_id:'store',refund_slip_path:'food-refund-slips/store/order/slip.jpg'};
 assert.equal((await h.api.signAdminFoodRefundEvidence({...order,refund_slip_path:'food-refund-slips/foreign/order/slip.jpg'})).status,'error');assert.equal(h.calls.length,0);
 assert.equal((await h.api.signAdminFoodRefundEvidence(order)).status,'ready');assert.equal(h.calls[0].bucket,'food-private');assert.equal(h.calls[0].seconds,600);
 h.deny();assert.equal((await h.api.signAdminFoodRefundEvidence(order)).status,'error');assert.equal(h.calls.length,1);
});
test('list filters run in server RPC before pagination',async()=>{
 const h=fixture();await h.api.fetchAdminFoodOrders({status:'refund_overdue',fulfillmentType:'pickup',paymentMethod:'transfer',limit:50});
 assert.equal(h.calls[0].name,'admin_food_orders_v2');assert.equal(h.calls[0].args.p_status,'refund_overdue');assert.equal(h.calls[0].args.p_fulfillment_type,'pickup');assert.equal(h.calls[0].args.p_payment_method,'transfer');assert.equal(h.calls[0].args.p_limit,50);
});
