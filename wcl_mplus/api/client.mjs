import { WclGraphQLError, WclHttpError, WclValidationError } from './errors.mjs';

const DEFAULT_API_URL = 'https://www.warcraftlogs.com/api/v2/client';

export class WclClient {
  constructor({ tokenProvider, fetchImpl = globalThis.fetch, apiUrl = DEFAULT_API_URL } = {}) {
    if (!tokenProvider || typeof tokenProvider.getToken !== 'function') throw new WclValidationError('A token provider is required.');
    if (typeof fetchImpl !== 'function') throw new WclValidationError('A fetch implementation is required.');
    this.tokenProvider = tokenProvider;
    this.fetch = fetchImpl;
    this.apiUrl = apiUrl;
  }

  async query(query, variables = {}) {
    if (!query || typeof query !== 'string') throw new WclValidationError('A GraphQL query is required.');
    const token = await this.tokenProvider.getToken();
    let response;
    try {
      response = await this.fetch(this.apiUrl, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, variables }),
      });
    } catch (cause) {
      throw new WclHttpError('Unable to reach the WCL GraphQL endpoint.', { cause });
    }
    if (!response.ok) throw new WclHttpError(`WCL GraphQL endpoint returned HTTP ${response.status}.`, { status: response.status });
    let body;
    try { body = await response.json(); } catch (cause) { throw new WclHttpError('WCL GraphQL endpoint returned invalid JSON.', { cause }); }
    if (body.errors?.length) {
      const message = body.errors.map((error) => error.message).filter(Boolean).join('; ') || 'GraphQL request failed.';
      throw new WclGraphQLError(message, { cause: body.errors });
    }
    return body.data ?? {};
  }
}
