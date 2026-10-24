import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const manifest = JSON.parse(readFileSync(new URL('../.wyn/docs/deployment/zoky-merchant-ui-release.json', import.meta.url), 'utf8'));
const aliases = ['wynos.online','geo.wynos.online','www.wynos.online','food.wynos.online','maps.wynos.online','zoky.wynos.online','tiles.wynos.online','routing.wynos.online','merchant.wynos.online','web-warren14.vercel.app'];
function artifact(current = true) {
  return {id: current ? manifest.rollbackDeployment : 'dpl_fixture',projectId:manifest.projectId,
    target:'production',readyState:'READY',meta:{githubCommitSha:current ? manifest.productionBase : manifest.releaseSha},alias:current ? aliases : []};
}
function inspect(command, responses, url='https://web-fixture-warren14.vercel.app') {
  const source = `
    process.env.VERCEL_TOKEN='synthetic-not-a-credential';
    process.env.MERCHANT_DEPLOYMENT_URL=${JSON.stringify(url)};
    process.argv[2]=${JSON.stringify(command)};
    const responses=${JSON.stringify(responses)};
    globalThis.fetch=async url=>{
      if(!['api.vercel.com','food.wynos.online'].includes(new URL(url).hostname))throw new Error('Unexpected network target');
      const item=responses.shift();if(!item)throw new Error('Unexpected request');
      return new Response(JSON.stringify(item.body??{}),{status:item.status??200,headers:item.headers??{}});
    };
    await import(${JSON.stringify(new URL('./merchant_ui_release_ops.mjs', import.meta.url).href)});
    if(responses.length)throw new Error('Expected requests were skipped');
  `;
  return spawnSync(process.execPath, ['--input-type=module','-e',source], {encoding:'utf8'});
}

test('current alias accepts only the recorded live deployment and Food phase', () => {
  const result=inspect('current',[{body:artifact()},{status:200}]);
  assert.equal(result.status,0,result.stderr);
  for(const mutation of [
    d=>{d.id='dpl_newer';},d=>{d.projectId='prj_other';},d=>{d.target='preview';},
    d=>{d.readyState='BUILDING';},d=>{d.meta.githubCommitSha='b'.repeat(40);},d=>{d.alias=aliases.slice(1);},
  ]) {
    const d=artifact();mutation(d);
    assert.notEqual(inspect('current',[{body:d},{status:200}]).status,0);
  }
  assert.notEqual(inspect('current',[{body:artifact()},{status:307,headers:{location:'https://zoky.wynos.online/'}}]).status,0);
});

test('staging rejects preview, another project/source and production aliases', () => {
  let result=inspect('staged',[{body:artifact(false)}]);
  assert.equal(result.status,0,result.stderr);
  for(const mutation of [d=>{d.target='preview';},d=>{d.projectId='prj_wrong';},d=>{d.meta.githubCommitSha='c'.repeat(40);},d=>{d.alias=aliases;}]) {
    const d=artifact(false);mutation(d);
    assert.notEqual(inspect('staged',[{body:d}]).status,0);
  }
  for(const url of ['https://evil.test','https://web-fixture-warren14.vercel.app/path','http://web-fixture-warren14.vercel.app']) {
    assert.notEqual(inspect('staged',[{body:artifact(false)}],url).status,0);
  }
});

test('promotion must assign every original alias to the same tested artifact', () => {
  const staged=artifact(false),live={...artifact(false),alias:aliases};
  let result=inspect('promoted',[{body:staged},{body:live},{status:200}]);
  assert.equal(result.status,0,result.stderr);
  assert.notEqual(inspect('promoted',[{body:staged},{body:{...live,id:'dpl_different'}},{status:200}]).status,0);
  assert.notEqual(inspect('promoted',[{body:staged},{body:{...live,alias:aliases.slice(1)}},{status:200}]).status,0);
});

test('upload directory follows only the existing project root without changing settings', () => {
  for(const rootDirectory of [null,'','web']) {
    const result=inspect('upload-root',[{body:{id:manifest.projectId,name:'web',rootDirectory}}]);
    assert.equal(result.status,0,result.stderr);
    assert.equal(result.stdout.trim(),rootDirectory === 'web' ? '..' : '.');
  }
  assert.notEqual(inspect('upload-root',[{body:{id:manifest.projectId,name:'web',rootDirectory:'admin'}}]).status,0);
  assert.notEqual(inspect('upload-root',[{body:{id:'prj_other',name:'web',rootDirectory:null}}]).status,0);
});
