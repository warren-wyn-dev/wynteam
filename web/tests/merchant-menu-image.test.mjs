import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
const source = readFileSync(new URL('../lib/merchant-menu-image.ts', import.meta.url), 'utf8');
const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
const exports = {};
runInNewContext(code, { exports, URL });
const thumbnail = exports.merchantMenuThumbnailUrl;
const project = 'https://merchant-project.supabase.co';
const image = `${project}/storage/v1/object/public/food-public/stores/one/menu/photo.jpg`;
test('known public menu image uses an existing same-origin 128px image optimizer', () => {
  const url = new URL(thumbnail(image, project), 'https://merchant.wynos.online');
  assert.equal(url.origin, 'https://merchant.wynos.online');
  assert.equal(url.pathname, '/_next/image');
  assert.equal(url.searchParams.get('url'), image);
  assert.equal(url.searchParams.get('w'), '128');
  assert.equal(url.searchParams.get('q'), '75');
});
test('private, signed, external, SVG and malformed images are never proxied', () => {
  for (const original of [null, '', 'data:image/png;base64,AA', '/local.png',
    image.replace(project, 'https://other.supabase.co'),
    image.replace('/public/', '/sign/') + '?token=private',
    image + '?token=private', image + '#fragment',
    image.replace('food-public/', 'private-bucket/'), image.replace('.jpg', '.svg'),
    image.replace('https://', 'https://user:pass@')]) {
    assert.equal(thumbnail(original, project), original);
  }
  assert.equal(thumbnail(image), image);
  assert.equal(thumbnail(image, 'invalid'), image);
});
