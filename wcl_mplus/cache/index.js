const fs = require('node:fs/promises');
const path = require('node:path');

function normalizePart(value) {
  return String(value ?? '')
    .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .trim().toLocaleLowerCase('en-US');
}

function identityOf(applicant) {
  const region = normalizePart(applicant.region);
  const realm = normalizePart(applicant.realm);
  const name = normalizePart(applicant.name);
  if (!region || !realm || !name) throw new Error('region, realm and name are required');
  return { region, realm, name, key: `${region}/${realm}/${name}` };
}

function safeFileName(key) {
  return Buffer.from(key, 'utf8').toString('base64url') + '.json';
}

class JsonCache {
  constructor({ dir, ttlMs = 15 * 60 * 1000, now = () => Date.now() }) {
    if (!dir) throw new Error('cache dir is required');
    this.dir = dir;
    this.ttlMs = ttlMs;
    this.now = now;
  }

  async get(applicant) {
    const identity = identityOf(applicant);
    try {
      const record = JSON.parse(await fs.readFile(path.join(this.dir, safeFileName(identity.key)), 'utf8'));
      if (record.identity !== identity.key || typeof record.savedAt !== 'number') return null;
      if (this.ttlMs >= 0 && this.now() - record.savedAt > this.ttlMs) return null;
      return record.value;
    } catch (error) {
      if (error.code === 'ENOENT' || error instanceof SyntaxError) return null;
      throw error;
    }
  }

  async set(applicant, value) {
    const identity = identityOf(applicant);
    await fs.mkdir(this.dir, { recursive: true });
    const file = path.join(this.dir, safeFileName(identity.key));
    const temp = `${file}.${process.pid}.${Math.random().toString(16).slice(2)}.tmp`;
    const record = JSON.stringify({ identity: identity.key, savedAt: this.now(), value });
    await fs.writeFile(temp, record, { encoding: 'utf8', mode: 0o600 });
    await fs.rename(temp, file);
    return value;
  }

  static identityOf(applicant) { return identityOf(applicant); }
}

module.exports = { JsonCache, identityOf };
