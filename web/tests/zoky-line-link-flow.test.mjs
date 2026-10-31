import { test } from 'node:test';
import assert from 'node:assert/strict';
import { startMerchantLineLink, finishMerchantLineLink } from '../../supabase/functions/zoky-line-webhook/link-flow.mjs';
const userId = '123e4567-e89b-42d3-a456-426614174000';
const storeId = '123e4567-e89b-42d3-a456-426614174001';
const lineUserId = 'U'+'a'.repeat(32);
const now = 1800000000000;
class MemoryRepo {
  pending = new Map(); linked = new Map(); active = true; clock = now;
  async requireActiveMember(){if(!this.active) throw Error('forbidden')}
  async savePendingLink(record){this.pending.set(record.nonceHash,record)}
  async consumeAndAttach({nonceHash,lineUserId}){
    const pending=this.pending.get(nonceHash);
    if(!pending||!this.active||Date.parse(pending.expiresAt)<=this.clock) return false;
    this.pending.delete(nonceHash);this.linked.set(pending.storeId,lineUserId);return true;
  }
}
async function link(repo){
  const { redirectUrl }=await startMerchantLineLink({userId,storeId,linkToken:'ValidLineTokenValue123456',repository:repo,now});
  const nonce=new URL(redirectUrl).searchParams.get('nonce');
  return {type:'accountLink',source:{type:'user',userId:lineUserId},link:{result:'ok',nonce}};
}
test('verified LINK event maps eligible store owner to LINE only once',async()=>{
  const repository=new MemoryRepo(),verifiedEvent=await link(repository);
  assert.equal((await finishMerchantLineLink({verifiedEvent,repository})).result,'linked');
  assert.equal((await finishMerchantLineLink({verifiedEvent,repository})).result,'rejected');
  assert.equal(repository.linked.get(storeId),lineUserId);
});
test('expired LINK nonce fails closed',async()=>{
  const repository=new MemoryRepo(),verifiedEvent=await link(repository);
  repository.clock=now+600001;
  assert.equal((await finishMerchantLineLink({verifiedEvent,repository})).result,'rejected');
});
test('revoked staff membership fails closed',async()=>{
  const repository=new MemoryRepo(),verifiedEvent=await link(repository);
  repository.active=false;
  assert.equal((await finishMerchantLineLink({verifiedEvent,repository})).result,'rejected');
});
test('unverified store membership cannot start linking',async()=>{
  const repository=new MemoryRepo();repository.active=false;
  await assert.rejects(()=>link(repository),/forbidden/);
});
