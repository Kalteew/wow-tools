const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { JsonCache } = require('../cache');
const { SnapshotCoordinator, createDefaultResolver, createServer } = require('./server');

async function tempDir() { return fs.mkdtemp(path.join(os.tmpdir(), 'wcl-mplus-')); }

test('cache writes atomically and expires by TTL', async () => {
  const dir = await tempDir(); let now = 1000;
  const cache = new JsonCache({ dir, ttlMs: 10, now: () => now });
  const applicant = { region: 'EU', realm: 'Hyjal', name: 'Azåelle' };
  await cache.set(applicant, { score: 42 });
  assert.deepEqual(await cache.get({ region: 'eu', realm: 'hyjal', name: 'azaelle' }), { score: 42 });
  now += 11; assert.equal(await cache.get(applicant), null);
});

test('snapshot deduplicates identities and limits concurrent work', async () => {
  const dir = await tempDir(); let active = 0; let peak = 0; let calls = 0;
  const coordinator = new SnapshotCoordinator({ cache: new JsonCache({ dir }), concurrency: 2, resolver: async applicant => {
    calls++; active++; peak = Math.max(peak, active); await new Promise(r => setTimeout(r, 5)); active--; return { status: 'ready', data: applicant.name };
  }});
  const result = await coordinator.snapshot([{ region: 'EU', realm: 'Hyjal', name: 'Kylse' }, { region: 'eu', realm: 'hyjal', name: 'kylse' }, { region: 'EU', realm: 'Hyjal', name: 'Kalteew' }]);
  assert.equal(result.length, 2); assert.equal(calls, 2); assert.ok(peak <= 2);
});

test('loopback API exposes health and dry-run statuses', async t => {
  const server = createServer({ cacheDir: await tempDir(), dryRun: true });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => server.close());
  const address = server.address(); const base = `http://127.0.0.1:${address.port}`;
  assert.equal((await fetch(`${base}/v1/health`)).status, 200);
  const response = await fetch(`${base}/v1/applicants/snapshot`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ applicants: [{ region: 'EU', realm: 'Hyjal', name: 'Kylse' }] }) });
  const payload = await response.json(); assert.match(payload.snapshotId, /^snap_/); assert.equal(payload.results[0].status, 'pending');
  const latest = await fetch(`${base}/v1/applicants/latest`);
  assert.equal((await latest.json()).snapshotId, payload.snapshotId);
});

test('default resolver uses the WCL GraphQL client when credentials are supplied', async () => {
  const resolver = createDefaultResolver({
    clientId: 'id',
    clientSecret: 'secret',
    fetchImpl: async (url, init) => {
      if (String(url).includes('/oauth/token')) return { ok: true, status: 200, json: async () => ({ access_token: 'token', expires_in: 3600 }) };
      const request = JSON.parse(init.body);
      assert.match(request.query, /characterData/);
      return { ok: true, status: 200, json: async () => ({ data: { characterData: { character: { id: 8, name: 'Kylse', server: { name: 'Hyjal', slug: 'hyjal', region: { slug: 'eu' } }, rankings: { score: 300 } } } } }) };
    },
  });
  const result = await resolver({ region: 'EU', realm: 'Hyjal', name: 'Kylse' });
  assert.equal(result.status, 'ready');
  assert.equal(result.data.mplus.score, 300);
});
