import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
import { randomUUID } from 'node:crypto';

const STORE = '10000000-0000-4000-8000-000000000001';
const OTHER = '20000000-0000-4000-8000-000000000002';
const ORDER = '30000000-0000-4000-8000-000000000003';
const ACCOUNT = '50000000-0000-4000-8000-000000000005';
const ITEM = '40000000-0000-4000-8000-000000000004';
const source = readFileSync(new URL('../lib/merchant-flutter-bridge.ts',import.meta.url),'utf8');
const compiled = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;

function moduleExports(path) {
  const code=ts.transpileModule(readFileSync(new URL(path,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  const exports={};runInNewContext(code,{exports,Date,Intl});return exports;
}
const availability=moduleExports('../lib/food-store-availability.ts');
const merchantCore=moduleExports('../lib/merchant-core.ts');

function harness() {
  const calls=[];
  const state={events:[],memberships:[{merchant_account_id:ACCOUNT}],staff:[],completeFailures:0,user:'merchant-a',access:true,manage:true,noOp:false,store:{id:STORE,merchant_account_id:ACCOUNT,is_published:true,name:'ร้านเรา',phone:'0811111111',address:'มหาสารคาม',is_open:true},order:{id:ORDER,store_id:STORE,status:'out_for_delivery',payment_provider:null,payment_slip_path:'buyer/slips/slip.jpg'}, disposedChannels:0, orderEvent:null, injectRead:null};
  const menu={id:ITEM,name:'เดิม',category:'อาหาร',description:null,price:60,image_path:'stores/store/menu/original.jpg',is_available:true,options:[{id:'spicy',name:'ความเผ็ด',choices:[{id:'mild',name:'น้อย',price:0}]}],daily_stock_limit:20,sold_out_until:'2026-10-22T00:00:00Z'};
  const client={
    auth:{getSession:async()=>{state.events.push('session');return {data:{session:state.user?{user:{id:state.user,is_anonymous:false}}:null},error:null}}},
    rpc:async(name,args)=>{
      calls.push({name,args});
      if(name==='merchant_store_reviews'){
        if(state.reviewHook)await state.reviewHook();
        return {data:state.reviewData??{count:0,average:0,unanswered:0,reviews:[]},error:state.reviewError??null};
      }
      return {data:name==='food_has_merchant_access'?state.access && args.p_store_id!==OTHER:name==='merchant_has_store_role'?state.manage:true,error:null};
    },
    from:(table)=>{
      const filters={};const chain={};let update=null,insert=null,single=false;
      for(const name of ['select','order','range'])chain[name]=(...args)=>{calls.push({table,name,args});return chain};
      chain.update=(patch)=>{update=patch;calls.push({table,name:'update',patch});return chain};
      chain.insert=(patch)=>{insert=patch;calls.push({table,name:'insert',patch});return chain};
      chain.eq=(key,value)=>{filters[key]=value;calls.push({table,name:'eq',key,value});return chain};
      chain.in=(key,values)=>{filters[key]=values;calls.push({table,name:'in',key,values});return chain};
      const resolve=async()=>{
        if(state.injectRead)await state.injectRead(table,filters);
        if(table==='merchant_memberships')return {data:state.memberships,error:null};
        if(table==='food_staff')return {data:state.staff,error:null};
        if(table==='food_stores'){
          if(typeof filters.id==='string')return {data:state.store,error:null};
          if(!Array.isArray(filters.id)&&!Array.isArray(filters.merchant_account_id))throw new Error('unfiltered public catalog query');
          return {data:[state.store,{id:OTHER,merchant_account_id:OTHER,name:'ร้านอื่น'}].filter(row=>Array.isArray(filters.id)?filters.id.includes(row.id):filters.merchant_account_id.includes(row.merchant_account_id)),error:null};
        }
        if(table==='food_menu_items'){if(state.noOp&&(update||insert))return {data:null,error:null};if(update)Object.assign(menu,update);return {data:insert?{...insert,id:ITEM}:single?menu:[menu],error:null};}
        if(table==='food_orders')return {data:filters.store_id && filters.store_id!==state.order.store_id?null:state.order,error:null};
        throw new Error('Unexpected table '+table);
      };
      chain.single=()=>{single=true;return resolve()};chain.maybeSingle=()=>{single=true;return resolve()};chain.then=(...args)=>resolve().then(...args);return chain;
    },
    removeChannel:async()=>{state.disposedChannels++;},
  };
  const food={
    saveMenuItem:async(...args)=>{calls.push({name:'saveMenuItem',args});},
    updateFoodStore:async(...args)=>{calls.push({name:'updateFoodStore',args});if(!state.noOp)Object.assign(state.store,args[2]);},
    transitionFoodOrder:async(...args)=>{calls.push({name:'transitionFoodOrder',args});},
    setFoodPaymentStatus:async(...args)=>{calls.push({name:'setFoodPaymentStatus',args});},
    completeFoodDelivery:async(...args)=>{calls.push({name:'completeFoodDelivery',args});if(state.completeFailures-->0)throw new Error('network failed');state.order.status='delivered';state.order.food_delivery_proofs=[{image_path:args[4]}];},
    foodPublicUrl:(_client,path)=>{calls.push({name:'foodPublicUrl',path});return path?'https://public.invalid/'+path:null;},
    foodPrivateSignedUrl:async(...args)=>{calls.push({name:'foodPrivateSignedUrl',args});return args[1]?'https://signed.invalid/private-image':null;},
    uploadFoodPrivateImage:async(...args)=>{calls.push({name:'uploadFoodPrivateImage',args});return `${args[2]}/photo.jpg`;},
    subscribeMerchantOrders:(_client,_store,callback)=>{state.orderEvent=callback;return {};},
    fetchMerchantSalesReport:async()=>({today_sales:200}),
  };
  let picked=null;
  const input={files:null,style:{},listeners:{},addEventListener(name,callback){this.listeners[name]=callback;},remove(){},click(){this.files=picked?[picked]:[];this.listeners[picked?'change':'cancel']();}};
  const exports={};
  runInNewContext(compiled,{
    exports,Uint8Array,crypto:{randomUUID},URL:class extends URL {static createObjectURL(){const url='blob:'+randomUUID();calls.push({name:'createObjectURL',url});return url;}static revokeObjectURL(url){calls.push({name:'revokeObjectURL',url});}},Image:class {},Notification:{permission:'granted'},
    createImageBitmap:async()=>({width:1,height:1,close(){}}),
    document:{createElement:()=>input,body:{appendChild(){}}},
    window:{addEventListener(){},removeEventListener(){},setTimeout},
    require(path){
      if(path==='@/lib/food-merchant')return food;
      if(path==='@/lib/food-store-availability')return availability;
      if(path==='@/lib/merchant-core')return merchantCore;
      if(path==='@/lib/food-delivery-proof')return {orderDeliveryProof:o=>Array.isArray(o.food_delivery_proofs)?o.food_delivery_proofs[0]:o.food_delivery_proofs};
      if(path==='@/lib/merchant-campaigns')return {fetchMerchantCampaigns:async()=>({can_manage:true,campaigns:[]}),saveMerchantCampaign:async(...args)=>{calls.push({name:'saveMerchantCampaign',args});},setMerchantCampaignActive:async()=>{}};
      if(path==='@/lib/push-notifications')return {getPushAvailability:async()=>({available:true}),hasActivePushSubscription:async()=>true,requestPushPermissionFromGesture:()=>{state.events.push('permission');return state.permissionRequest??Promise.resolve('granted');},subscribeToPushNotifications:async(_client,_user,options)=>{await options.permissionRequest;await options.ensureActive();state.events.push('subscribe');return {ok:true}},unsubscribeFromPushNotifications:async()=>true,pushReasonDescription:r=>r};
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
  assert.equal(result.ok,true);assert.deepEqual(result.data.map(s=>s.id),[STORE]);
  assert.equal(h.calls.some(c=>c.name==='food_has_merchant_access'),false);
  for(const table of ['merchant_memberships','food_staff'])assert.ok(h.calls.some(c=>c.table===table&&c.name==='eq'&&c.key==='user_id'&&c.value==='merchant-a'));
  assert.ok(h.calls.some(c=>c.table==='food_stores'&&c.name==='in'&&c.key==='merchant_account_id'));
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

});
test('file cancellation performs no upload; spoofed image signatures are rejected',async()=>{
  const h=harness();const args={storeId:STORE,orderId:ORDER};
  assert.deepEqual(await h.request('pickDeliveryPhoto',args),{ok:true,data:null});
  h.setFile({size:5,type:'image/jpeg',slice:()=>({arrayBuffer:async()=>new Uint8Array([1,2,3,4,5]).buffer})});
  assert.equal((await h.request('pickDeliveryPhoto',args)).ok,false);assert.equal(h.calls.some(c=>c.name==='uploadFoodPrivateImage'),false);
});
const jpeg=()=>({size:10,type:'image/jpeg',slice:()=>({arrayBuffer:async()=>new Uint8Array([255,216,255,217]).buffer})});
test('validated photo stays local through selection, replacement and cancellation',async()=>{
  const h=harness();h.setFile(jpeg());const args={storeId:STORE,orderId:ORDER};
  const first=(await h.request('pickDeliveryPhoto',args)).data;
  assert.match(first.path,/^pending:/);assert.match(first.previewUrl,/^blob:/);
  const second=(await h.request('pickDeliveryPhoto',args)).data;
  assert.notEqual(first.path,second.path);
  assert.ok(h.calls.some(c=>c.name==='revokeObjectURL'&&c.url===first.previewUrl));
  assert.equal((await h.request('releaseDeliveryPhoto',{...args,imagePath:second.path})).ok,true);
  assert.ok(h.calls.some(c=>c.name==='revokeObjectURL'&&c.url===second.previewUrl));
  assert.equal(h.calls.some(c=>c.name==='uploadFoodPrivateImage'),false);
});
test('delivery uploads only at confirmation and reuses the upload after an RPC failure',async()=>{
  const h=harness();h.setFile(jpeg());const args={storeId:STORE,orderId:ORDER};
  const photo=(await h.request('pickDeliveryPhoto',args)).data;
  h.state.completeFailures=1;
  const payload={...args,method:'dropoff',locationNote:'หน้าประตู',imagePath:photo.path};
  assert.equal((await h.request('completeDelivery',payload)).ok,false);
  assert.equal((await h.request('completeDelivery',payload)).ok,true);
  assert.equal(h.calls.filter(c=>c.name==='uploadFoodPrivateImage').length,1);
  const call=h.calls.find(c=>c.name==='completeFoodDelivery');
  assert.equal(call.args[4],`delivery/${ORDER}/photo.jpg`);
  assert.ok(h.calls.some(c=>c.name==='revokeObjectURL'&&c.url===photo.previewUrl));
});
test('another order cannot consume a local photo and disposal revokes its preview',async()=>{
  const h=harness();h.setFile(jpeg());const photo=(await h.request('pickDeliveryPhoto',{storeId:STORE,orderId:ORDER})).data;
  assert.equal((await h.request('completeDelivery',{storeId:STORE,orderId:OTHER,method:'direct',imagePath:photo.path})).ok,false);
  h.bridge.dispose();assert.ok(h.calls.some(c=>c.name==='revokeObjectURL'&&c.url===photo.previewUrl));
  assert.equal(h.calls.some(c=>c.name==='uploadFoodPrivateImage'),false);
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

test('pending manual payment requires explicit receipt confirmation; submitted no-slip and Stripe stay blocked',async()=>{
 const h=harness();h.state.order.payment_slip_path=null;h.state.order.payment_status='pending';
 const payload={storeId:STORE,orderId:ORDER,status:'paid'};
 assert.equal((await h.request('payment',payload)).ok,false);
 assert.equal((await h.request('payment',{...payload,manualConfirmation:true})).ok,true);
 h.state.order.payment_status='submitted';assert.equal((await h.request('payment',{...payload,manualConfirmation:true})).ok,false);
 h.state.order.payment_status='pending';h.state.order.payment_provider='stripe';assert.equal((await h.request('payment',{...payload,manualConfirmation:true})).ok,false);
});
test('push permission capture happens synchronously before session validation and never registers for a switched account',async()=>{
 const h=harness();let settle;h.state.permissionRequest=new Promise(resolve=>{settle=resolve});
 const pending=h.request('pushEnable');assert.equal(h.state.events[0],'permission');
 h.state.user='merchant-b';settle('granted');assert.equal((await pending).ok,false);
 assert.equal(h.state.events.includes('subscribe'),false);
});
test('legacy staff grants are store-filtered and deduplicated with membership stores',async()=>{
 const h=harness();h.state.staff=[{store_id:STORE}];const result=await h.request('stores');assert.equal(result.ok,true);assert.equal(result.data.length,1);
 assert.ok(h.calls.some(c=>c.table==='food_stores'&&c.name==='in'&&c.key==='id'&&c.values[0]===STORE));
 const none=harness();none.state.memberships=[];none.state.staff=[];assert.deepEqual((await none.request('stores')).data,[]);assert.equal(none.calls.some(c=>c.table==='food_stores'),false);
});

test('menu and store image URLs use the existing public-image helper without changing stored paths',async()=>{
 const h=harness();h.state.store.logo_path='stores/store/logo.jpg';
 const stores=await h.request('stores');assert.equal(stores.ok,true);
 assert.equal(stores.data[0].image_url,'https://public.invalid/stores/store/logo.jpg');
 assert.equal(stores.data[0].logo_path,'stores/store/logo.jpg');
 const menu=await h.request('menu',{storeId:STORE});assert.equal(menu.ok,true);
 assert.equal(menu.data[0].image_url,'https://public.invalid/stores/store/menu/original.jpg');
 assert.equal(menu.data[0].image_path,'stores/store/menu/original.jpg');
 assert.equal(h.calls.some(c=>c.name==='foodPrivateSignedUrl'),false);
 h.state.store.logo_path=null;h.menu.image_path=null;
 assert.equal((await h.request('stores')).data[0].image_url,null);
 assert.equal((await h.request('menu',{storeId:STORE})).data[0].image_url,null);
});

test('store presentation distinguishes the manual switch from effective trading availability',async()=>{
 const h=harness();
 let store=(await h.request('stores')).data[0];assert.equal(store.effective_open,true);assert.equal(store.status_text,'เปิดรับออเดอร์');
 h.state.store.temporary_closed_until='2099-01-01T00:00:00Z';h.state.store.temporary_closed_reason='พักร้านชั่วคราว';
 store=(await h.request('stores')).data[0];assert.equal(store.is_open,true);assert.equal(store.effective_open,false);assert.equal(store.status_text,'พักร้านชั่วคราว');
 h.state.store.temporary_closed_until=null;
 h.state.store.business_schedule={weekly:Object.fromEntries(['mon','tue','wed','thu','fri','sat','sun'].map(day=>[day,{enabled:false,open:'09:00',close:'21:00'}]))};
 store=(await h.request('stores')).data[0];assert.equal(store.is_open,true);assert.equal(store.effective_open,false);assert.equal(store.status_text,'ปิดตามเวลาร้าน');
 h.state.store.business_schedule=null;h.state.store.is_open=false;
 store=(await h.request('stores')).data[0];assert.equal(store.effective_open,false);assert.equal(store.status_text,'ปิดรับออเดอร์');
});
test('unpublished and suspended stores never advertise that customers can order',async()=>{
 const h=harness();h.state.store.is_published=false;
 let store=(await h.request('stores')).data[0];assert.equal(store.is_open,true);assert.equal(store.effective_open,false);assert.equal(store.status_text,'ร้านยังไม่เผยแพร่');
 h.state.store.admin_suspended_at='2026-10-01T00:00:00Z';
 store=(await h.request('stores')).data[0];assert.equal(store.effective_open,false);assert.equal(store.status_text,'ร้านถูกระงับ กรุณาติดต่อทีม WYNOS');
});
test('quality returns real store-wide aggregates while omitting customer review details',async()=>{
 const h=harness();h.state.reviewData={count:21,average:4.7,unanswered:3,reviews:[{id:ORDER,rating:5,review_text:'private review detail',reviewer_label:'private name'}]};
 const result=await h.request('quality',{storeId:STORE});
 assert.deepEqual(result,{ok:true,data:{available:true,count:21,average:4.7,unanswered:3}});
 const call=h.calls.find(c=>c.name==='merchant_store_reviews');assert.equal(call.args.p_store_id,STORE);assert.equal(call.args.p_limit,1);
});
test('quality distinguishes zero reviews, missing RPC and failed access instead of inventing ratings',async()=>{
 const h=harness();assert.deepEqual((await h.request('quality',{storeId:STORE})).data,{available:true,count:0,average:null,unanswered:0});
 for(const code of ['PGRST202','42883']){
  h.state.reviewError={code,message:'missing RPC'};
  assert.deepEqual((await h.request('quality',{storeId:STORE})).data,{available:false,count:null,average:null,unanswered:null});
 }
 h.state.reviewError={code:'42501',message:'permission denied'};assert.equal((await h.request('quality',{storeId:STORE})).ok,false);
 const other=harness();assert.equal((await other.request('quality',{storeId:OTHER})).ok,false);assert.equal(other.calls.some(c=>c.name==='merchant_store_reviews'),false);
});
test('malformed quality aggregates and account switches cannot become successful dashboard metrics',async()=>{
 const h=harness();h.state.reviewData={count:3,average:6,unanswered:1,reviews:[]};assert.equal((await h.request('quality',{storeId:STORE})).ok,false);
 h.state.reviewData={count:3,average:4,unanswered:4,reviews:[]};assert.equal((await h.request('quality',{storeId:STORE})).ok,false);
 const switched=harness();switched.state.reviewHook=async()=>{switched.state.user='merchant-b'};
 assert.equal((await switched.request('quality',{storeId:STORE})).ok,false);
});
