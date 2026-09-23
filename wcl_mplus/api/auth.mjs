import { WclAuthError, WclHttpError } from './errors.mjs';

const DEFAULT_TOKEN_URL = 'https://www.warcraftlogs.com/oauth/token';

export class WclTokenProvider {
  #clientId;
  #clientSecret;
  #fetch;
  #tokenUrl;
  #now;
  #token;
  #expiresAt = 0;
  #request;

  constructor({ clientId, clientSecret, fetchImpl = globalThis.fetch, tokenUrl = DEFAULT_TOKEN_URL, now = Date.now } = {}) {
    if (!clientId || !clientSecret) throw new WclAuthError('WCL client credentials are required.');
    if (typeof fetchImpl !== 'function') throw new WclAuthError('A fetch implementation is required.');
    this.#clientId = clientId;
    this.#clientSecret = clientSecret;
    this.#fetch = fetchImpl;
    this.#tokenUrl = tokenUrl;
    this.#now = now;
  }

  async getToken() {
    if (this.#token && this.#now() < this.#expiresAt) return this.#token;
    if (!this.#request) this.#request = this.#fetchToken().finally(() => { this.#request = undefined; });
    return this.#request;
  }

  async #fetchToken() {
    let response;
    try {
      response = await this.#fetch(this.#tokenUrl, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${this.#clientId}:${this.#clientSecret}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      });
    } catch (cause) {
      throw new WclAuthError('Unable to reach the WCL token endpoint.', { cause });
    }
    if (!response.ok) throw new WclHttpError(`WCL token endpoint returned HTTP ${response.status}.`, { status: response.status });
    const body = await readJson(response, 'WCL token endpoint');
    if (!body.access_token) throw new WclAuthError('WCL token response did not contain an access token.');
    this.#token = body.access_token;
    const lifetimeMs = Math.max(0, Number(body.expires_in ?? 3600) * 1000);
    this.#expiresAt = this.#now() + lifetimeMs - 30_000;
    return this.#token;
  }
}

async function readJson(response, endpoint) {
  try { return await response.json(); } catch (cause) { throw new WclAuthError(`${endpoint} returned invalid JSON.`, { cause }); }
}
