// Runs only behind the existing production environment reviewer. Never logs
// API response bodies or credentials; only fixed release metadata is returned.
import { readFile } from 'node:fs/promises';

const manifest = JSON.parse(await readFile(new URL('../.wyn/docs/deployment/zoky-merchant-ui-release.json', import.meta.url), 'utf8'));
const token = process.env.VERCEL_TOKEN;
if (!token) throw new Error('Vercel authentication unavailable');
const command = process.argv[2];
const candidateUrl = process.env.MERCHANT_DEPLOYMENT_URL;
const customerAliases = ['wynos.online','geo.wynos.online','www.wynos.online','food.wynos.online','maps.wynos.online','zoky.wynos.online','tiles.wynos.online','routing.wynos.online','merchant.wynos.online'];
// --skip-domain sets autoAssignCustomDomains:false in CLI 63.1.2. Vercel
// still assigns this generated project alias; it is not a customer origin.
const generatedAlias = 'web-warren14.vercel.app';
const require = (value, message) => { if (!value) throw new Error(message); };
async function deployment(id) {
  const response = await fetch(`https://api.vercel.com/v13/deployments/${encodeURIComponent(id)}?teamId=${manifest.teamId}`, {
    headers: { authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(30000),
  });
  require(response.ok, `Deployment inspection rejected (${response.status})`);
  return response.json();
}
function target(d, sha) {
  require(d.projectId === manifest.projectId || d.project?.id === manifest.projectId, 'Wrong Vercel project');
  require(d.target === 'production' && d.readyState === 'READY', 'Artifact must be READY production');
  require((d.gitSource?.sha ?? d.meta?.githubCommitSha) === sha, 'Deployment source differs from reviewed SHA');
}
function artifactHost(url) {
  require(url === manifest.stagedUrl && /^https:\/\/web-[a-z0-9]+-warren14\.vercel\.app$/.test(url ?? ''), 'Invalid pinned staged artifact URL');
  return new URL(url).hostname;
}
function knownAliases(d, staged = false) {
  require(Array.isArray(d.alias) && d.alias.every(alias => typeof alias === 'string' &&
    (alias === generatedAlias || (!staged && customerAliases.includes(alias)))),
  staged ? 'Staging unexpectedly assigned a customer or unknown alias' : 'Unexpected production alias metadata');
}
async function resolvedAliases(aliases, id, sha) {
  // Deployment alias arrays can retain aliases that have since moved. Resolve
  // each customer hostname directly rather than relying on that stale array.
  const deployments = await Promise.all(aliases.map(alias => deployment(alias)));
  for (const d of deployments) {
    target(d, sha);
    require(d.id === id, 'Customer alias no longer resolves to the reviewed deployment');
  }
}
async function stagedArtifact(url) {
  const d = await deployment(artifactHost(url));
  target(d, manifest.releaseSha);
  require(d.id === manifest.stagedDeploymentId, 'Staged deployment differs from the reviewed immutable artifact');
  knownAliases(d, true);
  await resolvedAliases(customerAliases, manifest.rollbackDeployment, manifest.productionBase);
  return d;
}
async function foodUnchanged() {
  const r = await fetch('https://food.wynos.online/', {redirect:'manual',signal:AbortSignal.timeout(30000)});
  require(r.status === 200 && !r.headers.has('location'), 'Live Food phase changed; rebase and review the release');
}
if (command === 'current') {
  const d = await deployment('merchant.wynos.online');
  target(d, manifest.productionBase);
  require(d.id === manifest.rollbackDeployment, 'Live deployment changed while awaiting review');
  knownAliases(d);
  await resolvedAliases(customerAliases, manifest.rollbackDeployment, manifest.productionBase);
  await foodUnchanged();
  console.log(`PASS current production ${d.id} / ${manifest.productionBase}`);
} else if (command === 'resume-url') {
  await stagedArtifact(manifest.stagedUrl);
  console.log(manifest.stagedUrl);
} else if (command === 'staged') {
  const d = await stagedArtifact(candidateUrl);
  console.log(`PASS staged production ${d.id} / ${manifest.releaseSha}`);
} else if (command === 'promoted') {
  const staged = await deployment(artifactHost(candidateUrl));
  target(staged, manifest.releaseSha);
  require(staged.id === manifest.stagedDeploymentId, 'Wrong promoted artifact');
  const live = await deployment('merchant.wynos.online');
  target(live, manifest.releaseSha);
  require(live.id === staged.id, 'Production is not the tested artifact');
  knownAliases(live);
  await resolvedAliases([...customerAliases, generatedAlias], staged.id, manifest.releaseSha);
  await foodUnchanged();
  console.log(`PASS promoted production ${live.id} / ${manifest.releaseSha}`);
} else {
  throw new Error('Unknown release inspection');
}
