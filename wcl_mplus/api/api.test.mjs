import test from 'node:test';
import assert from 'node:assert/strict';
import { WclClient, WclGraphQLError, WclTokenProvider, extractMythicPlusMetrics, resolveCharacter } from './index.mjs';

const response = (body, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => body });

test('gets and caches an OAuth token in memory', async () => {
  const calls = [];
  const provider = new WclTokenProvider({ clientId: 'id', clientSecret: 'secret', now: () => 1000, fetchImpl: async (url, init) => { calls.push({ url, init }); return response({ access_token: 'token', expires_in: 3600 }); } });
  assert.equal(await provider.getToken(), 'token');
  assert.equal(await provider.getToken(), 'token');
  assert.equal(calls.length, 1);
  assert.match(calls[0].init.headers.Authorization, /^Basic /);
  assert.doesNotMatch(JSON.stringify(calls[0]), /secret/);
});

test('sends GraphQL with bearer token and resolves a character', async () => {
  const requests = [];
  const tokenProvider = { getToken: async () => 'token' };
  const client = new WclClient({ tokenProvider, fetchImpl: async (url, init) => { requests.push({ url, init }); return response({ data: { characterData: { character: { id: 7, name: 'Éowyn', server: { slug: 'hyjal', region: { slug: 'eu' } }, rankings: { score: 412, throughputRankings: [{ percentile: 74 }] } } } } }); } });
  const character = await resolveCharacter(client, { name: 'Éowyn', realm: 'Hyjal', region: 'EU' });
  assert.equal(character.id, 7);
  assert.equal(character.mplus.score, 412);
  const sent = JSON.parse(requests[0].init.body);
  assert.deepEqual(sent.variables, { name: 'Éowyn', serverSlug: 'hyjal', serverRegion: 'EU' });
  assert.match(sent.query, /characterData/);
  assert.match(sent.query, /rankings\(metric: points_and_damage\)/);
});

test('turns GraphQL errors into a typed error', async () => {
  const client = new WclClient({ tokenProvider: { getToken: async () => 'token' }, fetchImpl: async () => response({ errors: [{ message: 'bad query' }] }) });
  await assert.rejects(() => client.query('query X { nope }'), (error) => error instanceof WclGraphQLError && error.code === 'WCL_GRAPHQL_ERROR');
});

test('keeps M+ score and percentiles as separate metrics', () => {
  assert.deepEqual(extractMythicPlusMetrics({ mythicPlusReport: { score: 412, keyPercentile: 88.5, damagePercentile: 74 } }), {
    score: 412,
    keyPercentile: 88.5,
    damagePercentile: 74,
    parsePercent: 74,
    averageParse: null,
  });
});

test('averages only explicit per-run parse values', () => {
  const metrics = extractMythicPlusMetrics({ rankings: { score: 500, throughputRankings: [{ percentile: 80 }, { percentile: 60 }] } });
  assert.equal(metrics.score, 500);
  assert.equal(metrics.averageParse, 70);
  assert.equal(metrics.keyPercentile, null);
});
