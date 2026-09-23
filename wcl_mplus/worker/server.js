const http = require('node:http');
const path = require('node:path');
const { JsonCache, identityOf } = require('../cache');

const DEFAULT_PORT = 28777;

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.setEncoding('utf8');
    request.on('data', chunk => { body += chunk; if (body.length > 1_000_000) reject(new Error('body too large')); });
    request.on('end', () => { try { resolve(body ? JSON.parse(body) : {}); } catch { reject(new Error('invalid JSON')); } });
    request.on('error', reject);
  });
}

function httpStatusToResult(status, body) {
  if (status === 401 || status === 403) return { status: 'private' };
  if (status === 404) return { status: 'missing' };
  if (status === 202 || status === 204) return { status: 'pending' };
  if (status >= 200 && status < 300) return { status: 'ready', data: body };
  return { status: 'error', error: `upstream HTTP ${status}` };
}

class SnapshotCoordinator {
  constructor({ cache, resolver, concurrency = 3, dryRun = false }) {
    this.cache = cache;
    this.resolver = resolver;
    this.concurrency = Math.max(1, Number(concurrency) || 1);
    this.dryRun = dryRun;
    this.inFlight = new Map();
  }

  async resolve(applicant) {
    const identity = identityOf(applicant);
    const cached = await this.cache.get(identity);
    if (cached !== null) return { status: 'ready', data: cached, cached: true };
    if (this.dryRun) return { status: 'pending' };
    if (!this.inFlight.has(identity.key)) {
      const job = Promise.resolve().then(() => this.resolver(identity)).then(async result => {
        if (result.status === 'ready') await this.cache.set(identity, result.data);
        return result;
      }).finally(() => this.inFlight.delete(identity.key));
      this.inFlight.set(identity.key, job);
    }
    return this.inFlight.get(identity.key);
  }

  async snapshot(applicants) {
    const unique = new Map();
    for (const applicant of applicants) {
      const identity = identityOf(applicant);
      if (!unique.has(identity.key)) unique.set(identity.key, identity);
    }
    const entries = [...unique.values()];
    const results = new Array(entries.length);
    let cursor = 0;
    const worker = async () => {
      while (cursor < entries.length) {
        const index = cursor++;
        try { results[index] = await this.resolve(entries[index]); }
        catch (error) { results[index] = { status: 'error', error: error.message }; }
      }
    };
    await Promise.all(Array.from({ length: Math.min(this.concurrency, entries.length) }, worker));
    return entries.map((applicant, index) => ({ applicant, ...results[index] }));
  }
}

function createDefaultResolver({ endpoint = process.env.WCL_MPLUS_ENDPOINT, token = process.env.WCL_API_TOKEN, fetchImpl = globalThis.fetch, clientId = process.env.WCL_CLIENT_ID, clientSecret = process.env.WCL_CLIENT_SECRET, wclClient } = {}) {
  let clientPromise = wclClient ? Promise.resolve(wclClient) : null;
  return async applicant => {
    if (clientId && clientSecret) {
      if (!clientPromise) clientPromise = createWclClient({ clientId, clientSecret, fetchImpl });
      return resolveWithWcl(applicant, { client: await clientPromise });
    }
    if (wclClient) return resolveWithWcl(applicant, { client: await clientPromise });
    if (!endpoint || !token || typeof fetchImpl !== 'function') return { status: 'error', error: 'upstream is not configured' };
    try {
      const url = new URL(endpoint);
      url.searchParams.set('region', applicant.region);
      url.searchParams.set('realm', applicant.realm);
      url.searchParams.set('name', applicant.name);
      const response = await fetchImpl(url, { headers: { authorization: `Bearer ${token}`, accept: 'application/json' } });
      let body = null;
      if (response.status !== 204) { try { body = await response.json(); } catch { body = null; } }
      return httpStatusToResult(response.status, body);
    } catch (error) { return { status: 'error', error: error.message }; }
  };
}

async function createWclClient({ clientId, clientSecret, fetchImpl }) {
  const { WclClient, WclTokenProvider } = await import('../api/index.mjs');
  const tokenProvider = new WclTokenProvider({ clientId, clientSecret, fetchImpl });
  return new WclClient({ tokenProvider, fetchImpl });
}

async function resolveWithWcl(applicant, { client }) {
  try {
    const { resolveCharacter } = await import('../api/index.mjs');
    const character = await resolveCharacter(client, applicant);
    return { status: 'ready', data: { character, mplus: character.mplus } };
  } catch (error) {
    if (error?.code === 'WCL_NOT_FOUND' || error?.status === 404) return { status: 'missing' };
    if (error?.status === 401 || error?.status === 403) return { status: 'private' };
    if (error?.status === 429) return { status: 'pending', error: 'WCL rate limit reached' };
    return { status: 'error', error: error?.message || 'WCL request failed' };
  }
}

function writeJson(response, status, payload, corsOrigin = 'null') {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'access-control-allow-origin': corsOrigin,
    'access-control-allow-headers': 'content-type',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
  });
  response.end(JSON.stringify(payload));
}

function createServer(options = {}) {
  const cache = options.cache || new JsonCache({ dir: options.cacheDir || path.join(__dirname, '..', 'cache', 'data'), ttlMs: options.ttlMs });
  const coordinator = options.coordinator || new SnapshotCoordinator({ cache, resolver: options.resolver || createDefaultResolver(options), concurrency: options.concurrency, dryRun: options.dryRun });
  const corsOrigin = options.corsOrigin || process.env.WCL_MPLUS_ORIGIN || 'null';
  let latest = { status: 'idle', results: [], updatedAt: null };
  const server = http.createServer(async (request, response) => {
    try {
      if (request.method === 'OPTIONS') return writeJson(response, 204, null, corsOrigin);
      if (request.method === 'GET' && request.url === '/v1/health') {
        return writeJson(response, 200, { ok: true, dryRun: Boolean(coordinator.dryRun) }, corsOrigin);
      }
      if (request.method === 'GET' && request.url === '/v1/applicants/latest') {
        return writeJson(response, 200, latest, corsOrigin);
      }
      if (request.method !== 'POST' || request.url !== '/v1/applicants/snapshot') {
        response.writeHead(404); return response.end();
      }
      const payload = await readJson(request);
      if (!Array.isArray(payload.applicants)) throw new Error('applicants must be an array');
      const results = await coordinator.snapshot(payload.applicants);
      const snapshotId = `snap_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      const hasError = results.some(result => result.status === 'error');
      const hasPending = results.some(result => result.status === 'pending');
      latest = { snapshotId, status: hasError ? 'partial' : hasPending ? 'loading' : 'ready', results, updatedAt: new Date().toISOString() };
      return writeJson(response, 200, latest, corsOrigin);
    } catch (error) {
      return writeJson(response, error.message === 'invalid JSON' ? 400 : 422, { error: error.message }, corsOrigin);
    }
  });
  return server;
}

if (require.main === module) {
  const server = createServer({ dryRun: process.argv.includes('--dry-run') });
  server.listen(Number(process.env.WCL_MPLUS_PORT || DEFAULT_PORT), '127.0.0.1', () => console.log(JSON.stringify({ address: server.address() })));
}

module.exports = { SnapshotCoordinator, createDefaultResolver, createServer, httpStatusToResult, resolveWithWcl };
