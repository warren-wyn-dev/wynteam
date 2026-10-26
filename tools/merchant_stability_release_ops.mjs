// Only protected Production jobs call this trusted control-checkout helper.
// Never print response bodies, environment values, headers or credentials.
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

export async function inspectStabilityRelease({ manifest, command, candidateUrl, expectedId, token, fetch = globalThis.fetch }) {
  const require = (condition, message) => { if (!condition) throw new Error(message); };
  require(/^[0-9a-f]{40}$/.test(manifest.releaseSha) && manifest.releaseSha !== '0'.repeat(40), 'Unfinalized stability release');
  require(manifest.productionBase === 'b2e5c184eeaef42aeb7b94ef10e54627d5d594ab' && manifest.rollbackDeployment === 'dpl_CACVkPQDL3MDfFSZvY64Ggpyqu8v', 'Unexpected stability base');
  require(manifest.projectId === 'prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a' && manifest.teamId === 'team_Kamt1PUT5XKn9MWrF404re1w', 'Unexpected stability target');
  require(token, 'Vercel authentication unavailable');
  const customers = ['wynos.online','geo.wynos.online','www.wynos.online','food.wynos.online','maps.wynos.online','zoky.wynos.online','tiles.wynos.online','routing.wynos.online','merchant.wynos.online'];
  const generated = 'web-warren14.vercel.app';
  async function api(path) {
    const r = await fetch(`https://api.vercel.com${path}?teamId=${manifest.teamId}`, {
      headers: {authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(30000),
    });
    require(r.ok, `Vercel metadata inspection rejected (${r.status})`);
    return r.json();
  }
  const deployment = id => api(`/v13/deployments/${encodeURIComponent(id)}`);
  function target(d, sha) {
    require((d.projectId ?? d.project?.id) === manifest.projectId, 'Wrong deployment project');
    require(d.target === 'production' && d.readyState === 'READY', 'Expected a READY production build');
    require((d.gitSource?.sha ?? d.meta?.githubCommitSha) === sha, 'Wrong reviewed source');
  }
  function aliases(d, staged = false) {
    require(Array.isArray(d.alias) && d.alias.every(value => value === generated || (!staged && customers.includes(value))),
      'Unexpected customer or unknown deployment alias');
  }
  async function resolve(names, id, sha) {
    for (const d of await Promise.all(names.map(deployment))) {
      target(d, sha);
      require(d.id === id, 'A hostname moved from its reviewed deployment');
    }
  }
  async function foodPhase() {
    const r = await fetch('https://food.wynos.online/', {redirect:'manual',signal:AbortSignal.timeout(30000)});
    require(r.status === 200 && !r.headers.has('location'), 'Live Food phase changed');
  }
  async function current() {
    const d = await deployment('merchant.wynos.online');
    target(d, manifest.productionBase);
    require(d.id === manifest.rollbackDeployment, 'Production changed while awaiting review');
    aliases(d);
    // Alias arrays can be stale. Every customer hostname must independently agree.
    await resolve(customers, manifest.rollbackDeployment, manifest.productionBase);
    await foodPhase();
    return d;
  }
  function artifactHost() {
    require(/^https:\/\/web-[a-z0-9]+-warren14\.vercel\.app$/.test(candidateUrl ?? ''), 'Invalid immutable artifact URL');
    return new URL(candidateUrl).hostname;
  }
  async function artifact(checkId) {
    const host = artifactHost(), d = await deployment(host);
    target(d, manifest.releaseSha);
    require(d.url === host && /^dpl_[A-Za-z0-9]+$/.test(d.id), 'Expected an immutable build URL/ID');
    if (checkId) require(/^dpl_[A-Za-z0-9]+$/.test(expectedId ?? '') && d.id === expectedId, 'Artifact differs from inspected stage ID');
    return d;
  }
  if (command === 'upload-root') {
    const p = await api(`/v9/projects/${manifest.projectId}`);
    require(p.id === manifest.projectId && p.name === 'web', 'Unexpected upload project');
    require(p.rootDirectory == null || p.rootDirectory === '' || p.rootDirectory === 'web', 'Unsupported existing root directory');
    return p.rootDirectory === 'web' ? '..' : '.';
  } else if (command === 'current') {
    const d = await current(); return `PASS current production ${d.id} / ${manifest.productionBase}`;
  } else if (command === 'staged-output' || command === 'staged') {
    const d = await artifact(command === 'staged'); aliases(d, true);
    await resolve(customers, manifest.rollbackDeployment, manifest.productionBase);
    await foodPhase();
    return command === 'staged-output' ? `url=${candidateUrl}\nid=${d.id}` : `PASS inspected stage ${d.id} / ${manifest.releaseSha}`;
  } else if (command === 'promoted') {
    const d = await artifact(true); aliases(d);
    await resolve([...customers, generated], d.id, manifest.releaseSha);
    await foodPhase();
    return `PASS promoted production ${d.id} / ${manifest.releaseSha}`;
  } else throw new Error('Unknown stability release inspection');

}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  const manifest = JSON.parse(await readFile(new URL('../.wyn/docs/deployment/zoky-merchant-stability-release.json', import.meta.url), 'utf8'));
  console.log(await inspectStabilityRelease({ manifest, command: process.argv[2], candidateUrl: process.env.MERCHANT_DEPLOYMENT_URL, expectedId: process.env.MERCHANT_DEPLOYMENT_ID, token: process.env.VERCEL_TOKEN }));
}
