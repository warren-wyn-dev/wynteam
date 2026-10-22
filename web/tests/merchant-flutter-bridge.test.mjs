import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';

const STORE = '10000000-0000-4000-8000-000000000001';
const OTHER = '20000000-0000-4000-8000-000000000002';
const ORDER = '30000000-0000-4000-8000-000000000003';
const ITEM = '40000000-0000-4000-8000-000000000004';
const source = readFileSync(new URL('../lib/merchant-flutter-bridge.ts',import.meta.url),'utf8');
const compiled = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;

function harness() {
  const calls=[];
  const state={user:'merchant-a',access:true,manage:true,noOp:false,store:{id:STORE,name:'ร้านเรา',phone:'0811111111',address:'มหาสารคาม',is_open:true},order:{id:ORDER,store_id:STORE,status:'out_for_delivery',payment_provider:null,payment_slip_path:'buyer/slips/slip.jpg'}, disposedChannels:0, orderEvent:null, injectRead:null};
  const menu={id:ITEM,name:'เดิม',category:'อาหาร',description:null,price:60,image_path:'stores/store/menu/original.jpg',is_available:true,options:[{id:'spicy',name:'ความเผ็ด',choices:[{id:'mild',name:'น้อย',price:0}]}],daily_stock_limit:20,sold_out_until:'2026-10-22T00:00:00Z'};
  const client={
    auth:{getSession:async()=>({data:{session:state.user?{user:{id:state.user,is_anonymous:false}}:null},error:null})},
    rpc:async(name,args)=>{calls.push({name,args});return {data:name==='food_has_merchant_access'?state.access && args.p_store_id!==OTHER:name==='merchant_has_store_role'?state.manage:true,error:null};},
    from:(table)=>{
      const filters={};const chain={};let update=null,insert=null;
      for(const name of ['select','order','range'])chain[name]=(...args)=>{calls.push({table,name,args});return chain};
      chain.update=(patch)=>{update=patch;calls.push({table,name:'update',patch});return chain};
      chain.insert=(patch)=>{insert=patch;calls.push({table,name:'insert',patch});return chain};
      chain.eq=(key,value)=>{filters[key]=value;return chain};
      const resolve=async()=>{
        if(state.injectRead)await state.injectRead(table,filters);
        if(table==='food_stores')return {data:filters.id?state.store:[{id:STORE,name:'ร้านเรา'},{id:OTHER,name:'ร้านอื่น'}],error:null};
        if(table==='food_menu_items'){if(state.noOp&&(update||insert))return {data:null,error:null};if(update)Object.assign(menu,update);return {data:insert?{...insert,id:ITEM}:menu,error:null};}
        if(table==='food_orders')return {data:filters.store_id && filters.store_id!==state.order.store_id?null:state.order,error:null};
        throw new Error('Unexpected table '+table);
      };
      chain.single=resolve;chain.maybeSingle=resolve;chain.then=(...args)=>resolve().then(...args);return chain;
    },
    removeChannel:async()=>{state.disposedChannels++;},
  };
  const food={
    saveMenuItem:async(...args)=>{calls.push({name:'saveMenuItem',args});},
    updateFoodStore:async(...args)=>{calls.push({name:'updateFoodStore',args});if(!state.noOp)Object.assign(state.store,args[2]);},
    transitionFoodOrder:async(...args)=>{calls.push({name:'transitionFoodOrder',args});},
    setFoodPaymentStatus:async(...args)=>{calls.push({name:'setFoodPaymentStatus',args});},
    completeFoodDelivery:async(...args)=>{calls.push({name:'completeFoodDelivery',args});},
    foodPrivateSignedUrl:async(...args)=>{calls.push({name:'foodPrivateSignedUrl',args});return args[1]?'https://signed.invalid/private-image':null;},
    uploadFoodPrivateImage:async(...args)=>{calls.push({name:'uploadFoodPrivateImage',args});return `${args[2]}/photo.jpg`;},
    subscribeMerchantOrders:(_client,_store,callback)=>{state.orderEvent=callback;return {};},
    fetchMerchantSalesReport:async()=>({today_sales:200}),
  };
  let picked=null;
  const input={files:null,style:{},listeners:{},addEventListener(name,callback){this.listeners[name]=callback;},remove(){},click(){this.files=picked?[picked]:[];this.listeners[picked?'change':'cancel']();}};
  const exports={};
  runInNewContext(compiled,{
    exports,Uint8Array,URL,Image:class {},Notification:{permission:'granted'},
    createImageBitmap:async()=>({width:1,height:1,close(){}}),
    document:{createElement:()=>input,body:{appendChild(){}}},
    window:{addEventListener(){},removeEventListener(){},setTimeout},
    require(path){
      if(path==='@/lib/food-merchant')return food;
      if(path==='@/lib/food-delivery-proof')return {orderDeliveryProof:o=>Array.isArray(o.food_delivery_proofs)?o.food_delivery_proofs[0]:o.food_delivery_proofs};
      if(path==='@/lib/merchant-campaigns')return {fetchMerchantCampaigns:async()=>({can_manage:true,campaigns:[]}),saveMerchantCampaign:async(...args)=>{calls.push({name:'saveMerchantCampaign',args});},setMerchantCampaignActive:async()=>{}};
      if(path==='@/lib/push-notifications')return {getPushAvailability:async()=>({available:true}),hasActivePushSubscription:async()=>true,subscribeToPushNotifications:async()=>({ok:true}),unsubscribeFromPushNotifications:async()=>true,pushReasonDescription:r=>r};
      throw new Error('Unexpected import '+path);
    },
  });
  let changed=0;
  const bridge=exports.createMerchantFlutterBridge({client,userId:'merchant-a',signOut:async()=>{state.user=null;},onOrderChange:()=>{changed++;}});
  return {calls,state,bridge,menu,setFile(file){picked=file;},get changed(){return changed;},request:async(method,args={})=>JSON.parse(await bridge.request(method,JSON.stringify(args)))};
}

test('shared session is required, and account changes suppress stale in-flight responses',async()=>{
  const h=harness();h.state.user=null;
  assert.equal((await h.request('stores')).ok,false);assert.equal(h.calls.length,0);
  const a=harness();a.state.injectRead=async()=>{a.state.user='merchant-b';};
  assert.equal((await a.request('requestedOrder',{orderId:ORDER})).ok,false);
});
test('store listing removes published stores without merchant access',async()=>{
  const h=harness();const result=await h.request('stores');
  assert.equal(result.ok,true);assert.deepEqual(result.data,[{id:STORE,name:'ร้านเรา'}]);
});
test('cross-store order mutation is denied before invoking the existing transition',async()=>{
  const h=harness();const result=await h.request('transition',{storeId:OTHER,orderId:ORDER,status:'preparing'});
  assert.equal(result.ok,false);assert.equal(h.calls.some(c=>c.name==='transitionFoodOrder'),false);
});
test('order transitions cannot directly mark delivered, and cancel delegates through server RPC helper',async()=>{
  const h=harness();assert.equal((await h.request('transition',{storeId:STORE,orderId:ORDER,status:'delivered'})).ok,false);
  assert.equal((await h.request('transition',{storeId:STORE,orderId:ORDER,status:'cancelled',note:'ลูกค้าขอยกเลิก'})).ok,true);
  const call=h.calls.find(c=>c.name==='transitionFoodOrder');assert.equal(call.args[1],ORDER);assert.equal(call.args[2],'cancelled');
});
test('manual payment never overwrites Stripe webhook-managed status',async()=>{
  const h=harness();h.state.order.payment_provider='stripe';
  assert.equal((await h.request('payment',{storeId:STORE,orderId:ORDER,status:'paid'})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='setFoodPaymentStatus'),false);
});
test('menu partial edits preserve original options, picture and stock and ignore ownership injection',async()=>{
  const h=harness();const result=await h.request('saveMenu',{storeId:STORE,id:ITEM,values:{name:'ใหม่',store_id:OTHER,image_path:'attacker',options:[]}});
  assert.equal(result.ok,true);const write=h.calls.find(c=>c.table==='food_menu_items'&&c.name==='update');
  assert.deepEqual(JSON.parse(JSON.stringify(write.patch)),{name:'ใหม่'});
  assert.equal(h.menu.image_path,'stores/store/menu/original.jpg');assert.equal(h.menu.daily_stock_limit,20);
  assert.equal(h.menu.options[0].id,'spicy');assert.equal('store_id' in write.patch,false);
});
test('private viewer derives the slip path from its authorized order rather than caller input',async()=>{
  const h=harness();assert.equal((await h.request('signedUrl',{storeId:STORE,orderId:ORDER,kind:'slip',path:'other/slips/private.jpg'})).ok,true);
  const call=h.calls.find(c=>c.name==='foodPrivateSignedUrl');assert.equal(call.args[1],h.state.order.payment_slip_path);assert.equal(call.args[2],900);
});
test('delivery completion rejects another order photo and dropoff without a location',async()=>{
  const h=harness();assert.equal((await h.request('completeDelivery',{storeId:STORE,orderId:ORDER,method:'direct',imagePath:`delivery/${OTHER}/photo.jpg`})).ok,false);
  assert.equal((await h.request('completeDelivery',{storeId:STORE,orderId:ORDER,method:'dropoff',imagePath:`delivery/${ORDER}/photo.jpg`})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='completeFoodDelivery'),false);
  assert.equal((await h.request('completeDelivery',{storeId:STORE,orderId:ORDER,method:'dropoff',locationNote:'หน้าประตู',imagePath:`delivery/${ORDER}/photo.jpg`})).ok,true);
});
test('file cancellation performs no upload; spoofed image signatures are rejected',async()=>{
  const h=harness();const args={storeId:STORE,orderId:ORDER};
  assert.deepEqual(await h.request('pickDeliveryPhoto',args),{ok:true,data:null});
  h.setFile({size:5,type:'image/jpeg',slice:()=>({arrayBuffer:async()=>new Uint8Array([1,2,3,4,5]).buffer})});
  assert.equal((await h.request('pickDeliveryPhoto',args)).ok,false);assert.equal(h.calls.some(c=>c.name==='uploadFoodPrivateImage'),false);
});
test('validated photo upload delegates to existing location-stripping uploader and yields a private preview',async()=>{
  const h=harness();h.setFile({size:10,type:'image/jpeg',slice:()=>({arrayBuffer:async()=>new Uint8Array([255,216,255,217]).buffer})});
  const result=await h.request('pickDeliveryPhoto',{storeId:STORE,orderId:ORDER});
  assert.equal(result.ok,true);assert.equal(result.data.path,`delivery/${ORDER}/photo.jpg`);
  assert.equal(h.calls.find(c=>c.name==='uploadFoodPrivateImage').args[2],`delivery/${ORDER}`);
});
test('dispose silences realtime events, removes channel and rejects future operations',async()=>{
  const h=harness();assert.equal((await h.request('subscribe',{storeId:STORE})).ok,true);
  h.state.orderEvent();assert.equal(h.changed,1);h.bridge.dispose();h.state.orderEvent();
  assert.equal(h.changed,1);assert.equal(h.state.disposedChannels,1);assert.equal((await h.request('stores')).ok,false);
});
test('malformed and excessive requests never reach an RPC, and arbitrary methods cannot invoke it',async()=>{
  const h=harness();assert.equal(JSON.parse(await h.bridge.request('orders','{')).ok,false);
  assert.equal(JSON.parse(await h.bridge.request('orders','x'.repeat(17000))).ok,false);
  assert.equal((await h.request('executeSQL',{storeId:STORE,query:'select secrets'})).ok,false);
});


test('viewer role cannot update menu or store, even when rows are readable',async()=>{
  const h=harness();h.state.manage=false;
  assert.equal((await h.request('saveMenu',{storeId:STORE,id:ITEM,values:{name:'forbidden'}})).ok,false);
  assert.equal((await h.request('saveStore',{storeId:STORE,values:{name:'forbidden'}})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='update'||c.name==='updateFoodStore'),false);
});
test('a zero-row menu update and unchanged store readback are never reported as success',async()=>{
  const h=harness();h.state.noOp=true;
  assert.equal((await h.request('saveMenu',{storeId:STORE,id:ITEM,values:{name:'ใหม่'}})).ok,false);
  assert.equal((await h.request('saveStore',{storeId:STORE,values:{name:'ใหม่'}})).ok,false);
});
test('create requires name and price and verifies the inserted row in the selected store',async()=>{
  const h=harness();assert.equal((await h.request('saveMenu',{storeId:STORE,values:{name:'ใหม่'}})).ok,false);
  assert.equal((await h.request('saveMenu',{storeId:STORE,values:{name:'ใหม่',price:55}})).ok,true);
  const write=h.calls.find(c=>c.name==='insert');assert.equal(write.patch.store_id,STORE);assert.equal(write.patch.price,55);
});
test('manual payment without the customer slip is rejected',async()=>{
  const h=harness();h.state.order.payment_slip_path=null;
  assert.equal((await h.request('payment',{storeId:STORE,orderId:ORDER,status:'paid'})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='setFoodPaymentStatus'),false);
});
