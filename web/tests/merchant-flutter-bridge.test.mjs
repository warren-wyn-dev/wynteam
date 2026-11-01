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
      if(state.rpcHook)await state.rpcHook(name,args);
      if(state.rpcError?.name===name)return {data:null,error:{message:state.rpcError.message}};
      if(name==='merchant_store_reviews'){
        if(state.reviewHook)await state.reviewHook();
        return {data:state.reviewData??{count:0,average:0,unanswered:0,reviews:[]},error:state.reviewError??null};
      }
      if(name==='merchant_store_readiness')return {data:state.readiness??{ready:true,missing:[]},error:null};
      if(name==='food_service_area_check')return {data:state.insideArea??true,error:null};
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
        if(table==='profiles')return {data:filters.id===state.user?{username:state.myUsername??'me_admin'}:null,error:null};
        if(table==='food_stores'){
          if(update&&typeof filters.id==='string'){if(!state.noOp)Object.assign(state.store,update);return {data:null,error:null};}
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
    uploadFoodPublicImage:async(...args)=>{calls.push({name:'uploadFoodPublicImage',args});return `${args[2]}/qr.png`;},
    subscribeMerchantOrders:(_client,_store,callback)=>{state.orderEvent=callback;return {};},
    fetchMerchantSalesReport:async()=>({today_sales:200}),
  };
  let picked=null;
  const input={files:null,style:{},listeners:{},addEventListener(name,callback){this.listeners[name]=callback;},remove(){},click(){this.files=picked?[picked]:[];this.listeners[picked?'change':'cancel']();}};
  const exports={};
  runInNewContext(compiled,{
    exports,process:{env:{}},Uint8Array,crypto:{randomUUID},URL:class extends URL {static createObjectURL(){const url='blob:'+randomUUID();calls.push({name:'createObjectURL',url});return url;}static revokeObjectURL(url){calls.push({name:'revokeObjectURL',url});}},Image:class {},Notification:{permission:'granted'},
    createImageBitmap:async()=>({width:1,height:1,close(){}}),
    document:{createElement:()=>input,body:{appendChild(){}}},
    window:{addEventListener(){},removeEventListener(){},setTimeout},
    require(path){
      if(path==='@/lib/food-merchant')return food;
      if(path==='@/lib/merchant-menu-image')return {merchantMenuThumbnailUrl:url=>url};
      if(path==='@/lib/food-store-availability')return availability;
      if(path==='@/lib/merchant-core')return {...merchantCore,fetchMerchantStaff:async()=>state.staffMembers??[],addMerchantStaff:async(...args)=>{calls.push({name:'addMerchantStaff',args});},updateMerchantStaff:async(...args)=>{calls.push({name:'updateMerchantStaff',args});}};
      if(path==='@/lib/food-delivery-proof')return {orderDeliveryProof:o=>Array.isArray(o.food_delivery_proofs)?o.food_delivery_proofs[0]:o.food_delivery_proofs};
      if(path==='@/lib/merchant-finance')return {periodRange:(p)=>({from:'2026-10-'+(p==='month'?'01':'27'),to:'2026-10-27'}),fetchFinanceSummary:async(...args)=>{calls.push({name:'fetchFinanceSummary',args});return {sales_net:500,orders:3,days:[]};}};
      if(path==='@/lib/merchant-ads')return {fetchMerchantAdAccount:async()=>{if(state.adError)throw new Error(state.adError);return {can_manage:true,balance:100};},requestAdTopup:async(...args)=>{calls.push({name:'requestAdTopup',args});},setAdActive:async(...args)=>{calls.push({name:'setAdActive',args});if(state.adError)throw new Error(state.adError);},merchantAdError:(e)=>{const m=e instanceof Error?e.message:'';return m.includes('top up before starting ads')?'เติมเครดิตก่อนเริ่มโฆษณา':m||'ดำเนินการไม่สำเร็จ';}};
      if(path==='@/lib/merchant-platform-campaigns')return {fetchPlatformCampaigns:async()=>({can_manage:true,campaigns:[]}),joinPlatformCampaign:async(...args)=>{calls.push({name:'joinPlatformCampaign',args});},leavePlatformCampaign:async(...args)=>{calls.push({name:'leavePlatformCampaign',args});},platformCampaignError:(e)=>(e instanceof Error?e.message:'')||'ดำเนินการไม่สำเร็จ'};
      if(path==='@/lib/merchant-campaigns')return {fetchMerchantCampaigns:async()=>({can_manage:true,campaigns:[]}),saveMerchantCampaign:async(...args)=>{calls.push({name:'saveMerchantCampaign',args});},setMerchantCampaignActive:async()=>{}};
      if(path==='@/lib/push-notifications')return {getPushAvailability:async()=>({available:true}),hasActivePushSubscription:async()=>true,requestPushPermissionFromGesture:()=>{state.events.push('permission');return state.permissionRequest??Promise.resolve('granted');},subscribeToPushNotifications:async(_client,_user,options)=>{await options.permissionRequest;await options.ensureActive();state.events.push('subscribe');return {ok:true}},unsubscribeFromPushNotifications:async()=>true,pushReasonDescription:r=>r};
      if(path==='@/lib/food-fulfillment-merchant') {
        const code=ts.transpileModule(readFileSync(new URL('../lib/food-fulfillment-merchant.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
        const exports={};runInNewContext(code,{exports,Uint8Array,require:()=>food});return exports;
      }
      throw new Error('Unexpected import '+path);
    },
  });
  let changed=0;
  const bridge=exports.createMerchantFlutterBridge({client,userId:'merchant-a',signOut:async()=>{state.user=null;},onOrderChange:()=>{changed++;},pickLocation:async(request)=>{state.mapRequests=[...(state.mapRequests??[]),request];return state.mapResult??null;}});
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


test('fulfillment settings call only the contract RPC and expose schedule/mode errors safely', async()=>{
  const h=harness();
  const args={storeId:STORE,values:{pickup:true,delivery:false,cod:false,prepMinutes:15}};
  assert.equal((await h.request('setFulfillment',args)).ok,true);
  assert.deepEqual(JSON.parse(JSON.stringify(h.calls.find(c=>c.name==='food_store_set_fulfillment').args)),{p_store_id:STORE,p_pickup:true,p_delivery:false,p_cod:false,p_prep_minutes:15});
  assert.equal(h.calls.some(c=>c.table==='food_stores' && c.name==='update'),false);
  for(const message of ['pickup_requires_schedule','at_least_one_mode']) {
    h.state.rpcError={name:'food_store_set_fulfillment',message};
    const result=await h.request('setFulfillment',args);
    assert.equal(result.ok,false);assert.ok(result.error.includes(message));
  }
  h.state.rpcError={name:'food_store_set_fulfillment',message:'internal secret diagnostic'};
  assert.equal((await h.request('setFulfillment',args)).error.includes('secret'),false);
});
test('settings roles, validation and foreign store requests fail closed',async()=>{
  const h=harness();h.state.manage=false;
  assert.equal((await h.request('setFulfillment',{storeId:STORE,values:{pickup:true,delivery:true,cod:false,prepMinutes:15}})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='food_store_set_fulfillment'),false);
  const a=harness();
  for(const prepMinutes of [0,121,5.5]) assert.equal((await a.request('setFulfillment',{storeId:STORE,values:{pickup:true,delivery:true,cod:false,prepMinutes}})).ok,false);
  assert.equal((await a.request('resolveCancel',{storeId:OTHER,orderId:ORDER,approve:true,refund:true})).ok,false);
  assert.equal(a.calls.some(c=>c.name==='food_resolve_cancel_request'),false);
});
// Contract v2: pickup reuses ready_for_delivery / delivered; collection goes through food_complete_pickup.
test('pickup actions map to ready_for_delivery and food_complete_pickup, delivery completion stays separate',async()=>{
  const h=harness();h.state.order.fulfillment_type='pickup';
  for(const status of ['ready_for_pickup','picked_up']) assert.equal((await h.request('transition',{storeId:STORE,orderId:ORDER,status})).ok,true);
  assert.deepEqual(h.calls.filter(c=>c.name==='food_transition_order').map(c=>c.args.p_status),['ready_for_delivery']);
  assert.deepEqual(h.calls.filter(c=>c.name==='food_complete_pickup').map(c=>c.args.p_order_id),[ORDER]);
  assert.equal((await h.request('transition',{storeId:STORE,orderId:ORDER,status:'delivered'})).ok,false);
  const d=harness();
  for(const status of ['ready_for_pickup','picked_up']) assert.equal((await d.request('transition',{storeId:STORE,orderId:ORDER,status})).ok,false);
  assert.equal(d.calls.some(c=>c.name==='food_complete_pickup'||c.name==='food_transition_order'),false);
});
test('cancel resolution forwards refund decision, rejection always disables refund',async()=>{
  const h=harness();
  for(const approve of [false,true]) assert.equal((await h.request('resolveCancel',{storeId:STORE,orderId:ORDER,approve,refund:true})).ok,true);
  assert.deepEqual(h.calls.filter(c=>c.name==='food_resolve_cancel_request').map(c=>c.args.p_refund),[false,true]);
  h.state.rpcError={name:'food_resolve_cancel_request',message:'denied'};
  assert.equal((await h.request('resolveCancel',{storeId:STORE,orderId:ORDER,approve:true,refund:true})).ok,false);
});
test('COD cannot be marked paid through slip review or completed without explicit cash confirmation',async()=>{
  const h=harness();h.state.order.payment_method='cod';
  assert.equal((await h.request('payment',{storeId:STORE,orderId:ORDER,status:'paid'})).ok,false);
  h.setFile(jpeg());
  const photo=await h.request('pickDeliveryPhoto',{storeId:STORE,orderId:ORDER});
  const args={storeId:STORE,orderId:ORDER,method:'direct',imagePath:photo.data.path};
  assert.equal((await h.request('completeDelivery',args)).ok,false);
  assert.equal(h.calls.some(c=>c.name==='completeFoodDelivery'),false);
  assert.equal((await h.request('completeDelivery',{...args,cashReceived:true})).ok,true);
});
test('refund slips remain private, order-scoped, role-gated and reusable after failed RPC',async()=>{
  const h=harness();h.state.order.refund_status='pending';h.setFile(jpeg());
  const photo=await h.request('pickRefundSlip',{storeId:STORE,orderId:ORDER});
  assert.equal(photo.ok,true);
  const args={storeId:STORE,orderId:ORDER,imagePath:photo.data.path};
  assert.equal((await h.request('completeDelivery',{...args,method:'direct'})).ok,false);
  assert.equal((await h.request('markRefunded',{...args,orderId:OTHER})).ok,false);
  h.state.rpcError={name:'food_store_mark_refunded',message:'network failure'};
  assert.equal((await h.request('markRefunded',args)).ok,false);
  const uploads=h.calls.filter(c=>c.name==='uploadFoodPrivateImage');
  assert.equal(uploads.length,1);assert.equal(uploads[0].args[2],`refunds/${ORDER}`);
  h.state.rpcError=null;
  assert.equal((await h.request('markRefunded',args)).ok,true);
  assert.equal(h.calls.filter(c=>c.name==='uploadFoodPrivateImage').length,1);
  assert.equal((await h.request('markRefunded',args)).ok,false);
});
test('Stripe refunds and denied roles cannot upload a store refund slip',async()=>{
  for(const stripe of [true,false]) {
    const h=harness();h.state.order.refund_status='pending';h.setFile(jpeg());
    if(stripe)h.state.order.payment_provider='stripe';else h.state.manage=false;
    assert.equal((await h.request('pickRefundSlip',{storeId:STORE,orderId:ORDER})).ok,false);
    assert.equal(h.calls.some(c=>c.name==='uploadFoodPrivateImage'),false);
  }
});

const PNG=()=>({size:100,type:'image/png',slice:()=>({arrayBuffer:async()=>new Uint8Array([137,80,78,71,13,10,26,10,0,0,0,0,0,0,0,0]).buffer})});
const WEEK=(open='09:00')=>({weekly:Object.fromEntries(['mon','tue','wed','thu','fri','sat','sun'].map(d=>[d,{enabled:d!=='sun',open,close:'21:00'}]))});
test('payment channels and opening hours are validated, saved and read back',async()=>{
  const h=harness();
  const ok=await h.request('saveStore',{storeId:STORE,values:{promptpay_name:' ร้านเรา ',promptpay_id:'081-234-5678',bank_name:'กสิกร',bank_account_name:'ร้านเรา',bank_account_number:'123-4-56789-0',business_schedule:WEEK(),special_closed_dates:['2026-12-31','2026-11-01','2026-12-31']}});
  assert.equal(ok.ok,true,ok.error);
  const patch=h.calls.find(c=>c.name==='updateFoodStore').args[2];
  assert.equal(patch.promptpay_id,'0812345678');assert.equal(patch.bank_account_number,'1234567890');assert.equal(patch.promptpay_name,'ร้านเรา');
  assert.equal(JSON.stringify(patch.special_closed_dates),JSON.stringify(['2026-11-01','2026-12-31']));
  assert.equal(patch.business_schedule.weekly.sun.enabled,false);
  // Blank clears a channel, like the legacy form.
  assert.equal((await h.request('saveStore',{storeId:STORE,values:{promptpay_id:'',promptpay_name:''}})).ok,true);
  assert.equal(h.state.store.promptpay_id,null);
});
test('bad payment details and schedules are refused before any write',async()=>{
  for(const values of [
    {promptpay_id:'1812345678'},{promptpay_id:'08123'},{promptpay_id:'08x2345678'},{promptpay_id:'08123456789012'},
    {bank_account_number:'12345'},{bank_account_number:'12345abcde'},
    {payment_qr_path:'stores/other/payment/x.png'},
    {business_schedule:{weekly:{mon:{enabled:true,open:'09:00',close:'21:00'}}}},
    {business_schedule:{weekly:{...WEEK().weekly,mon:{enabled:true,open:'25:00',close:'21:00'}}}},
    {business_schedule:{weekly:{...WEEK().weekly,mon:{enabled:'yes',open:'09:00',close:'21:00'}}}},
    {special_closed_dates:['31/12/2026']},{special_closed_dates:'2026-12-31'},
  ]){
    const h=harness();
    assert.equal((await h.request('saveStore',{storeId:STORE,values})).ok,false,JSON.stringify(values));
    assert.equal(h.calls.some(c=>c.name==='updateFoodStore'),false,JSON.stringify(values));
  }
});
test('payment and hours changes need the manage role and a read-back match',async()=>{
  const h=harness();h.state.manage=false;
  assert.equal((await h.request('saveStore',{storeId:STORE,values:{business_schedule:WEEK()}})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='updateFoodStore'),false);
  const n=harness();n.state.noOp=true;
  assert.equal((await n.request('saveStore',{storeId:STORE,values:{business_schedule:WEEK('10:00')}})).ok,false);
});
test('payment QR upload is store-scoped, validated and verified',async()=>{
  const h=harness();h.setFile(PNG());
  const result=await h.request('pickPaymentQr',{storeId:STORE});
  assert.equal(result.ok,true,result.error);
  assert.equal(result.data.path,`stores/${STORE}/payment/qr.png`);
  assert.equal(h.state.store.payment_qr_path,`stores/${STORE}/payment/qr.png`);
  const bad=harness();bad.setFile({size:100,type:'image/png',slice:()=>({arrayBuffer:async()=>new Uint8Array(16).buffer})});
  assert.equal((await bad.request('pickPaymentQr',{storeId:STORE})).ok,false);
  assert.equal(bad.calls.some(c=>c.name==='uploadFoodPublicImage'),false);
  const staff=harness();staff.state.manage=false;staff.setFile(PNG());
  assert.equal((await staff.request('pickPaymentQr',{storeId:STORE})).ok,false);
  assert.equal(staff.calls.some(c=>c.name==='uploadFoodPublicImage'),false);
  const other=harness();other.setFile(PNG());
  assert.equal((await other.request('pickPaymentQr',{storeId:OTHER})).ok,false);
  const cancel=harness();cancel.setFile(null);
  assert.deepEqual(await cancel.request('pickPaymentQr',{storeId:STORE}),{ok:true,data:null});
  // Removing the QR is the only direct payment_qr_path write.
  assert.equal((await h.request('saveStore',{storeId:STORE,values:{payment_qr_path:null}})).ok,true);
  assert.equal(h.state.store.payment_qr_path,null);
});

test('store finance is for managers only and only offers fixed Bangkok periods',async()=>{
  const h=harness();
  const result=await h.request('finance',{storeId:STORE,period:'month'});
  assert.equal(result.ok,true,result.error);assert.equal(result.data.sales_net,500);
  const call=h.calls.find(c=>c.name==='fetchFinanceSummary');
  assert.equal(call.args[1],STORE);assert.equal(JSON.stringify(call.args[2]),JSON.stringify({from:'2026-10-01',to:'2026-10-27'}));
  for(const period of ['custom','year','',null]){
    const bad=harness();
    assert.equal((await bad.request('finance',{storeId:STORE,period})).ok,false);
    assert.equal(bad.calls.some(c=>c.name==='fetchFinanceSummary'),false);
  }
  const staff=harness();staff.state.manage=false;
  assert.equal((await staff.request('finance',{storeId:STORE,period:'today'})).ok,false);
  assert.equal(staff.calls.some(c=>c.name==='fetchFinanceSummary'),false);
  const other=harness();
  assert.equal((await other.request('finance',{storeId:OTHER,period:'today'})).ok,false);
});

const MEMBER='60000000-0000-4000-8000-000000000006';
test('staff list marks the signed-in member and who may manage the team',async()=>{
  const h=harness();h.state.staffMembers=[{user_id:'merchant-a',username:'me',display_name:'ฉัน',role:'admin',active:true,created_at:'',updated_at:''},{user_id:MEMBER,username:'cook',display_name:null,role:'orders',active:true,created_at:'',updated_at:''}];
  const result=await h.request('staff',{storeId:STORE});
  assert.equal(result.ok,true,result.error);assert.equal(result.data.canManage,true);
  assert.deepEqual(result.data.members.map(m=>m.self),[true,false]);
  assert.equal('created_at' in result.data.members[0],false);
  const viewer=harness();viewer.state.staffMembers=[{user_id:'merchant-a',role:'orders',active:true}];
  assert.equal((await viewer.request('staff',{storeId:STORE})).data.canManage,false);
  const off=harness();off.state.staffMembers=[{user_id:'merchant-a',role:'owner',active:false}];
  assert.equal((await off.request('staff',{storeId:STORE})).data.canManage,false);
  assert.equal((await harness().request('staff',{storeId:OTHER})).ok,false);
});
test('adding and changing staff is owner/admin only, never the owner role or yourself',async()=>{
  const h=harness();
  assert.equal((await h.request('addStaff',{storeId:STORE,username:'@cook_1',role:'orders'})).ok,true);
  assert.equal(h.calls.find(c=>c.name==='merchant_has_store_role').args.p_roles.join(),'owner,admin');
  assert.equal((await h.request('updateStaff',{storeId:STORE,userId:MEMBER,role:'manager',active:false})).ok,true);
  assert.deepEqual(h.calls.find(c=>c.name==='updateMerchantStaff').args.slice(1),[STORE,MEMBER,'manager',false]);
  for(const [method,args] of [
    ['addStaff',{username:'cook',role:'owner'}],['addStaff',{username:'a b',role:'orders'}],['addStaff',{username:'x',role:'orders'}],
    ['updateStaff',{userId:MEMBER,role:'owner',active:true}],['updateStaff',{userId:'merchant-a',role:'orders',active:true}],
    ['updateStaff',{userId:MEMBER,role:'orders',active:'yes'}],
    ['addStaff',{username:'@Me_Admin',role:'orders'}],['addStaff',{username:'me_admin',role:'admin'}],
  ]){
    const bad=harness();
    assert.equal((await bad.request(method,{storeId:STORE,...args})).ok,false,JSON.stringify(args));
    assert.equal(bad.calls.some(c=>c.name==='addMerchantStaff'||c.name==='updateMerchantStaff'),false,JSON.stringify(args));
  }
  const manager=harness();manager.state.manage=false;
  assert.equal((await manager.request('addStaff',{storeId:STORE,username:'cook',role:'orders'})).ok,false);
  assert.equal(manager.calls.some(c=>c.name==='addMerchantStaff'),false);
});

const CAMPAIGN='70000000-0000-4000-8000-000000000007';
test('ads are manager-only; top-up needs a whole amount and a real slip image',async()=>{
  const h=harness();
  assert.equal((await h.request('ads',{storeId:STORE})).data.balance,100);
  h.setFile(PNG());
  const result=await h.request('pickAdSlip',{storeId:STORE,amount:300});
  assert.equal(result.ok,true,result.error);
  h.setFile(PNG());assert.equal((await h.request('pickAdSlip',{storeId:STORE,amount:150.5})).ok,true);
  for(const amount of [150.05,300.03,0.07]){h.setFile(PNG());assert.equal((await h.request('pickAdSlip',{storeId:STORE,amount})).ok,true,String(amount));}
  const call=h.calls.find(c=>c.name==='requestAdTopup');assert.equal(call.args[1],STORE);assert.equal(call.args[2],300);
  for(const amount of [0,-5,12.345,'300',100001]){
    const bad=harness();bad.setFile(PNG());
    assert.equal((await bad.request('pickAdSlip',{storeId:STORE,amount})).ok,false,String(amount));
    assert.equal(bad.calls.some(c=>c.name==='requestAdTopup'),false);
  }
  const fake=harness();fake.setFile({size:100,type:'image/png',slice:()=>({arrayBuffer:async()=>new Uint8Array(16).buffer})});
  assert.equal((await fake.request('pickAdSlip',{storeId:STORE,amount:300})).ok,false);
  assert.equal(fake.calls.some(c=>c.name==='requestAdTopup'),false);
  const staff=harness();staff.state.manage=false;staff.setFile(PNG());
  for(const [method,args] of [['ads',{}],['pickAdSlip',{amount:300}],['setAdActive',{active:true}],['platformCampaigns',{}],['joinPlatformCampaign',{campaignId:CAMPAIGN,join:true}]]){
    assert.equal((await staff.request(method,{storeId:STORE,...args})).ok,false,method);
  }
  assert.equal(staff.calls.some(c=>['requestAdTopup','setAdActive','joinPlatformCampaign'].includes(c.name)),false);
});
test('known ad and campaign errors are shown in Thai, unknown server text is not',async()=>{
  const h=harness();h.state.adError='top up before starting ads';
  assert.equal((await h.request('setAdActive',{storeId:STORE,active:true})).error,'เติมเครดิตก่อนเริ่มโฆษณา');
  const raw=harness();raw.state.adError='relation "x" does not exist';
  const result=await raw.request('ads',{storeId:STORE});
  assert.equal(result.ok,false);assert.equal(result.error.includes('relation'),false);
});
test('joining and leaving ZOKY campaigns are store-scoped',async()=>{
  const h=harness();
  assert.equal((await h.request('joinPlatformCampaign',{storeId:STORE,campaignId:CAMPAIGN,join:true})).ok,true);
  assert.equal((await h.request('joinPlatformCampaign',{storeId:STORE,campaignId:CAMPAIGN,join:false})).ok,true);
  assert.deepEqual(h.calls.filter(c=>c.name.endsWith('PlatformCampaign')).map(c=>c.name),['joinPlatformCampaign','leavePlatformCampaign']);
  assert.equal((await h.request('joinPlatformCampaign',{storeId:STORE,campaignId:'bad',join:true})).ok,false);
  assert.equal((await h.request('joinPlatformCampaign',{storeId:OTHER,campaignId:CAMPAIGN,join:true})).ok,false);
});
test('your own staff access cannot be changed through add or update',async()=>{
  const h=harness();
  const add=await h.request('addStaff',{storeId:STORE,username:'@ME_ADMIN',role:'orders'});
  assert.equal(add.ok,false);assert.match(add.error,/ตัวเอง/);
  // The harness user id is not a UUID, so this is refused at input validation; real ids reach the self check.
  assert.equal((await h.request('updateStaff',{storeId:STORE,userId:'merchant-a',role:'orders',active:false})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='addMerchantStaff'||c.name==='updateMerchantStaff'),false);
});

test('parallel store reads share only an in-flight access check, later reads recheck',async()=>{
  const h=harness();let release,started;
  const blocked=new Promise(resolve=>{release=resolve;});
  const entered=new Promise(resolve=>{started=resolve;});
  h.state.rpcHook=async(name)=>{if(name==='food_has_merchant_access'){started();await blocked;}};
  const reads=[h.request('menu',{storeId:STORE}),h.request('report',{storeId:STORE}),h.request('hasRole',{storeId:STORE,roles:['owner']})];
  await entered;await new Promise(resolve=>setImmediate(resolve));
  assert.equal(h.calls.filter(c=>c.name==='food_has_merchant_access').length,1);
  release();assert.ok((await Promise.all(reads)).every(r=>r.ok));
  h.state.rpcHook=null;h.state.access=false;
  assert.equal((await h.request('menu',{storeId:STORE})).ok,false);
  assert.equal(h.calls.filter(c=>c.name==='food_has_merchant_access').length,2);
});
test('a write never shares a pending read access grant',async()=>{
  const h=harness();let release,started;
  const blocked=new Promise(resolve=>{release=resolve;});
  const entered=new Promise(resolve=>{started=resolve;});let grants=0;
  h.state.rpcHook=async(name)=>{if(name==='food_has_merchant_access'&&++grants===1){started();await blocked;}};
  const read=h.request('menu',{storeId:STORE});await entered;
  const write=await h.request('saveStore',{storeId:STORE,values:{name:'ร้านใหม่',phone:'0811111111',address:'มหาสารคาม',is_open:true}});
  assert.equal(write.ok,true);
  assert.equal(h.calls.filter(c=>c.name==='food_has_merchant_access').length,2);
  release();assert.equal((await read).ok,true);
});
test('coalesced reads still reject a changed account and disposed bridge',async()=>{
  for (const mode of ['account','dispose']) {
    const h=harness();let release,started;
    const blocked=new Promise(resolve=>{release=resolve;});
    const entered=new Promise(resolve=>{started=resolve;});
    h.state.rpcHook=async(name)=>{if(name==='food_has_merchant_access'){started();await blocked;}};
    const reads=[h.request('menu',{storeId:STORE}),h.request('report',{storeId:STORE})];
    await entered;
    if(mode==='account')h.state.user='merchant-b';else h.bridge.dispose();
    release();assert.ok((await Promise.all(reads)).every(r=>!r.ok));
    assert.equal(h.calls.some(c=>c.table==='food_menu_items'),false);
  }
});

test('the จัดส่ง tab reads ready and out-for-delivery orders; unknown tabs are rejected',async()=>{
  const h=harness();
  assert.equal((await h.request('orders',{storeId:STORE,status:'delivering',offset:0})).ok,true);
  const read=h.calls.filter(c=>c.table==='food_orders'&&c.name==='in').at(-1);
  assert.equal(JSON.stringify(read),JSON.stringify({table:'food_orders',name:'in',key:'status',values:['ready_for_delivery','out_for_delivery']}));
  assert.equal((await h.request('orders',{storeId:STORE,status:'preparing',offset:0})).ok,true);
  assert.equal(JSON.stringify(h.calls.filter(c=>c.table==='food_orders'&&c.name==='in').at(-1).values),'["preparing"]');
  for(const status of ['constructor','__proto__','toString','shipping'])assert.equal((await h.request('orders',{storeId:STORE,status,offset:0})).ok,false,status);
});

test('home order counts stay store-scoped and count only unpaid non-COD, non-Stripe orders for review',async()=>{
  const h=harness();h.state.order={id:ORDER,store_id:STORE,status:'pending_acceptance',payment_method:'transfer',payment_status:'pending',payment_provider:null};
  const result=await h.request('orderCounts',{storeId:STORE});
  assert.equal(result.ok,true);
  assert.equal(JSON.stringify(result.data),JSON.stringify({pending:0,review:0,preparing:0,delivering:0}));
  const reads=h.calls.filter(c=>c.table==='food_orders');
  assert.equal(reads.filter(c=>c.name==='eq'&&c.key==='store_id').length,3);
  assert.ok(reads.every(c=>c.name!=='eq'||c.key!=='store_id'||c.value===STORE));
  assert.equal(JSON.stringify(reads.filter(c=>c.name==='in').map(c=>c.values)),JSON.stringify([['pending_acceptance'],['preparing'],['ready_for_delivery','out_for_delivery']]));
  assert.equal((await h.request('orderCounts',{storeId:OTHER})).ok,false);
});

test('feedback reviews expose only whitelisted fields and the reply permission (Founder 2026-11-01)',async()=>{
  const h=harness();
  h.state.reviewData={count:2,average:4.5,unanswered:1,reviews:[{id:ORDER,rating:5,review_text:'อร่อย',tags:['รสชาติดี'],reviewer_label:'ลูกค้า WYNOS Food',created_at:'2026-11-01T00:00:00Z',merchant_reply:null,merchant_replied_at:null,customer_user_id:'secret-user',order_id:'secret-order'}]};
  const result=await h.request('reviews',{storeId:STORE});
  assert.equal(result.ok,true);
  assert.equal(result.data.can_reply,true);
  assert.equal(result.data.count,2);
  assert.deepEqual(Object.keys(result.data.reviews[0]).sort(),['created_at','id','merchant_replied_at','merchant_reply','rating','review_text','reviewer_label','tags']);
  assert.equal(JSON.stringify(result).includes('secret'),false);
  assert.equal(h.calls.find(c=>c.name==='merchant_store_reviews').args.p_store_id,STORE);
  h.state.manage=false;
  assert.equal((await h.request('reviews',{storeId:STORE})).data.can_reply,false);
  assert.equal((await harness().request('reviews',{storeId:OTHER})).ok,false);
});

test('a review reply needs a manage role, a review from this store and a bounded non-empty text',async()=>{
  const h=harness();
  h.state.reviewData={count:1,average:5,unanswered:1,reviews:[{id:ORDER,rating:5}]};
  assert.equal((await h.request('replyReview',{storeId:STORE,reviewId:ORDER,reply:' ขอบคุณครับ '})).ok,true);
  const call=h.calls.find(c=>c.name==='food_reply_store_review');
  assert.equal(call.args.p_review_id,ORDER);assert.equal(call.args.p_reply,'ขอบคุณครับ');
  const before=h.calls.filter(c=>c.name==='food_reply_store_review').length;
  assert.equal((await h.request('replyReview',{storeId:STORE,reviewId:ITEM,reply:'x'})).ok,false);
  for(const reply of ['', '   ', 'x'.repeat(501), 5])assert.equal((await h.request('replyReview',{storeId:STORE,reviewId:ORDER,reply})).ok,false);
  h.state.manage=false;
  assert.equal((await h.request('replyReview',{storeId:STORE,reviewId:ORDER,reply:'ok'})).ok,false);
  assert.equal(h.calls.filter(c=>c.name==='food_reply_store_review').length,before);
});

test('the full store editor fields are validated, saved and read back (Founder 2026-11-01)',async()=>{
  const h=harness();
  const future=new Date(Date.now()+3*86400000).toISOString();
  const values={description:' ส้มตำรสเด็ด ',business_hours:'10:00-20:00',delivery_area:'ในเมือง',delivery_fee:'25',minimum_order:100,delivery_radius_km:6.5,delivery_base_km:2,delivery_fee_per_km:7,
    temporary_closed_until:future,temporary_closed_reason:'พักร้อน',latitude:16.18,longitude:103.3,pickup_latitude:null,pickup_longitude:null,pickup_note:'หน้าร้าน',
    scheduled_orders_enabled:true,scheduled_min_notice_minutes:30,scheduled_max_days:7,tax_invoice_enabled:true,tax_legal_name:'บริษัท',tax_id:'1234567890123',tax_branch:'สำนักงานใหญ่',tax_address:'มหาสารคาม',logo_path:null};
  const result=await h.request('saveStore',{storeId:STORE,values});
  assert.equal(result.ok,true,JSON.stringify(result));
  const saved=h.calls.find(c=>c.name==='updateFoodStore').args[2];
  assert.equal(saved.description,'ส้มตำรสเด็ด');assert.equal(saved.delivery_fee,25);assert.equal(saved.logo_path,null);assert.equal(saved.latitude,16.18);assert.equal(saved.pickup_latitude,null);
  for(const bad of [{delivery_fee:-1},{delivery_radius_km:0.1},{latitude:91,longitude:0},{latitude:16},{scheduled_max_days:31},{scheduled_min_notice_minutes:10},{tax_id:'123'},
    {temporary_closed_until:'2000-01-01T00:00:00Z'},{logo_path:'stores/other/x.png'},{cover_path:'x'},{description:'x'.repeat(1001)}]){
    assert.equal((await h.request('saveStore',{storeId:STORE,values:bad})).ok,false,JSON.stringify(bad));
  }
  h.state.manage=false;
  assert.equal((await h.request('saveStore',{storeId:STORE,values:{description:'x'}})).ok,false);
});

test('publishing uses the readiness gate and a manage role; location checks are store-scoped',async()=>{
  const h=harness();h.state.store.is_published=false;
  h.state.readiness={ready:false,missing:['เมนู']};
  const blocked=await h.request('setPublished',{storeId:STORE,published:true});
  assert.equal(blocked.ok,false);assert.equal(h.state.store.is_published,false);
  h.state.readiness={ready:true,missing:[]};
  assert.equal((await h.request('setPublished',{storeId:STORE,published:true})).ok,true);assert.equal(h.state.store.is_published,true);
  assert.equal((await h.request('setPublished',{storeId:STORE,published:'yes'})).ok,false);
  h.state.manage=false;
  assert.equal((await h.request('setPublished',{storeId:STORE,published:false})).ok,false);assert.equal(h.state.store.is_published,true);
  const g=harness();
  assert.deepEqual((await g.request('checkLocation',{storeId:STORE,latitude:16.18,longitude:103.3})).data,{inside:true});
  g.state.insideArea=false;
  assert.deepEqual((await g.request('checkLocation',{storeId:STORE,latitude:16.18,longitude:103.3})).data,{inside:false});
  assert.equal((await g.request('checkLocation',{storeId:STORE,latitude:200,longitude:0})).ok,false);
  assert.equal((await harness().request('checkLocation',{storeId:OTHER,latitude:1,longitude:1})).ok,false);
});

test('store images accept only logo or cover and a manage role',async()=>{
  const h=harness();
  for(const kind of ['banner','',null])assert.equal((await h.request('pickStoreImage',{storeId:STORE,kind})).ok,false);
  h.state.manage=false;
  assert.equal((await h.request('pickStoreImage',{storeId:STORE,kind:'logo'})).ok,false);
  assert.equal(h.calls.some(c=>c.name==='uploadFoodPublicImage'),false);
});

test('the store map picker needs a manage role, validates both ends and never saves by itself',async()=>{
  const h=harness();
  h.state.mapResult={latitude:16.18,longitude:103.3,address:'ถนนนครสวรรค์'};
  const picked=await h.request('pickMapLocation',{storeId:STORE,kind:'store',latitude:16.1,longitude:103.2});
  assert.deepEqual(picked,{ok:true,data:{latitude:16.18,longitude:103.3,address:'ถนนนครสวรรค์'}});
  assert.equal(JSON.stringify(h.state.mapRequests[0]),JSON.stringify({kind:'store',initial:{latitude:16.1,longitude:103.2}}));
  assert.equal(h.calls.some(c=>c.name==='updateFoodStore'),false);
  assert.deepEqual((await h.request('pickMapLocation',{storeId:STORE,kind:'pickup'})).data.latitude,16.18);
  assert.equal(h.state.mapRequests[1].initial,null);
  h.state.mapResult=null;
  assert.deepEqual(await h.request('pickMapLocation',{storeId:STORE,kind:'store'}),{ok:true,data:null});
  h.state.mapResult={latitude:999,longitude:0};
  assert.equal((await h.request('pickMapLocation',{storeId:STORE,kind:'store'})).ok,false);
  for(const kind of ['home','',null])assert.equal((await h.request('pickMapLocation',{storeId:STORE,kind})).ok,false);
  const before=h.state.mapRequests.length;
  h.state.manage=false;
  assert.equal((await h.request('pickMapLocation',{storeId:STORE,kind:'store'})).ok,false);
  assert.equal(h.state.mapRequests.length,before);
  assert.equal((await harness().request('pickMapLocation',{storeId:OTHER,kind:'store'})).ok,false);
});
