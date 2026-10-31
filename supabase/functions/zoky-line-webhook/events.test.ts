import { createLineEventProcessor } from "./events.mjs";
import { handleLineWebhook } from "./handler.mjs";
import { newLinkNonce } from "./account-link.mjs";
const secret = "test-local-secret";
const user = "U" + "a".repeat(32);
const orderId = "123e4567-e89b-42d3-a456-426614174000";
function assert(value: unknown, label: string) { if (!value) throw Error(label); }
async function signed(body: string) {
  const bytes = new TextEncoder().encode(body);
  const key = await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC",key,bytes));
  return new Request("https://example.test/line",{method:"POST",headers:{"x-line-signature":btoa(String.fromCharCode(...sig))},body});
}
function repo() { return { links:0,transitions:0,
  async completeLink(){this.links++;return true},
  async transitionOrder(){this.transitions++;return {ok:false}},
}; }
Deno.test("Only signed requests can invoke merchant LINE actions", async () => {
  const r=repo(),processor=createLineEventProcessor({repository:r,channelToken:"test-token",
    http: async()=>new Response(null,{status:200})});
  const body=JSON.stringify({events:[{type:"postback",source:{type:"user",userId:user},
    postback:{data:"v=1&a=accept&oid="+orderId}}]});
  const request=await signed(body);
  const result=await handleLineWebhook(request,secret,processor);
  assert(result.status===200 && r.transitions===1,"valid postback failed");
  const bad=new Request("https://example.test/line",{method:"POST",headers:{"x-line-signature":"bad"},body});
  const invalid=await handleLineWebhook(bad,secret,processor);
  assert(invalid.status===401 && r.transitions===1,"unsigned postback executed");
});
Deno.test("AccountLink event only accepts valid LINE user and nonce",async()=>{
  const r=repo();
  const processor=createLineEventProcessor({repository:r,channelToken:"test-token"});
  await processor({type:"accountLink",source:{type:"user",userId:user},
    link:{result:"ok",nonce:newLinkNonce()}});
  assert(r.links===1,"link not recorded");
  let rejected=false;
  try {await processor({type:"accountLink",source:{type:"user",userId:"@620wwvcd"},
    link:{result:"ok",nonce:newLinkNonce()}})} catch {rejected=true}
  assert(rejected && r.links===1,"spoofed user allowed");
});
Deno.test("Connect request issues linkToken and sends one fixed-origin reply",async()=>{
  const sent: Array<{url:string,body?:string}>=[];
  const http=async (url: string|URL|Request,options?: RequestInit): Promise<Response>=>{
    sent.push({url:String(url),body:typeof options?.body==="string"?options.body:undefined});
    if(String(url).includes("/linkToken")) return new Response(JSON.stringify({linkToken:"ValidTokenFromLine12345678"}),{status:200});
    return new Response(null,{status:200});
  };
  const processor=createLineEventProcessor({repository:repo(),channelToken:"test-token",http});
  await processor({type:"message",source:{type:"user",userId:user},replyToken:"ValidReplyToken123456",
    message:{type:"text",text:"เชื่อมบัญชี"}});
  assert(sent.length===2 && sent[0].url.includes("/linkToken"),"LINE link token not requested");
  assert(sent[1].url.endsWith("/message/reply"),"LINE reply not sent");
  const reply=JSON.parse(sent[1].body??"{}");
  const uri=reply.messages[0].template.actions[0].uri;
  assert(new URL(uri).origin==="https://merchant.wynos.online","unsafe origin");
});
Deno.test("Unknown action cannot mutate store orders",async()=>{
  const r=repo(),processor=createLineEventProcessor({repository:r,channelToken:"test-token"});
  await processor({type:"postback",source:{type:"user",userId:user},
    postback:{data:"v=1&a=delete&oid="+orderId}});
  assert(r.transitions===0,"unknown action changed order");
});
