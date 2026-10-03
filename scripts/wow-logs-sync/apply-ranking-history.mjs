import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((items, value, index, all) => {
    if (value.startsWith('--')) items.push([value.slice(2), all[index + 1]]);
    return items;
  }, []),
);
const repoRoot = resolve(args.root ?? process.cwd());
const reportsRoot = resolve(args['reports-root'] ?? join(repoRoot, 'logs', 'reports'));
const historyPath = resolve(args.history ?? join(repoRoot, 'logs', 'requests.jsonl'));
const since = Date.parse(args.since ?? '');
if (!Number.isFinite(since)) throw new Error('Fournir --since avec la date des appels MCP à appliquer.');

const aliases = new Map([
  ['azaelle', 'Azaelle'], ['azael', 'Azaelle'],
  ['kalteew', 'Kalteew'], ['kaltou', 'Kalteew'],
  ['kylse', 'Kylse'], ['kils', 'Kylse'],
]);
function normalizeName(value) {
  return String(value ?? '')
    .normalize('NFKD')
    .replace(/\p{Diacritic}/gu, '')
    .replace(/[^a-z0-9]/giu, '')
    .toLocaleLowerCase('en-US');
}
const files = new Map(readdirSync(reportsRoot)
  .filter((name) => name.toLowerCase().endsWith('.json'))
  .map((name) => {
    const path = join(reportsRoot, name);
    const data = JSON.parse(readFileSync(path, 'utf8'));
    const tracked = new Map();
    for (const player of data.players ?? []) {
      const profile = aliases.get(normalizeName(player.name));
      if (profile) tracked.set(normalizeName(player.name), { profile, name: player.name });
    }
    return [`${data.reportCode}-fight-${data.fightID}`, { path, data, tracked }];
  }));

const candidates = new Map();
const usedRecords = [];
for (const line of readFileSync(historyPath, 'utf8').split(/\r?\n/u).filter(Boolean)) {
  let request;
  try { request = JSON.parse(line); } catch { continue; }
  if (
    request.tool !== 'mcp__warcraftlogs__get_report_rankings'
    || request.status !== 'success'
    || Date.parse(request.timestamp) < since
  ) continue;
  const metric = String(request.args?.playerMetric ?? '').toLowerCase();
  if (!['dps', 'hps', 'playerscore'].includes(metric)) continue;
  const fightID = request.args?.fightID ?? request.args?.fight;
  const key = `${request.reportCode}-fight-${fightID}`;
  const source = files.get(key);
  if (!source?.tracked.size) continue;

  const trackedRows = (request.summary?.players ?? [])
    .filter((player) => player.matched === true && source.tracked.has(normalizeName(player.name)))
    .filter((player) => metric !== 'hps' || source.tracked.get(normalizeName(player.name)).profile === 'Kylse');
  if (!trackedRows.length) continue;
  const candidate = candidates.get(key) ?? {
    code: request.reportCode,
    fightID,
    matchedCharacters: [...source.tracked.values()].map((player) => player.name),
    refreshCharactersByMetric: {},
    refreshRankingsOnly: true,
    summary: { completed: true, contentType: 'mythicplus', keyLevel: source.data.fight?.keyLevel },
    rankings: {},
    rankingsCapturedAt: request.timestamp,
  };
  const names = trackedRows.map((player) => player.name);
  candidate.refreshCharactersByMetric[metric] = [...new Set([
    ...(candidate.refreshCharactersByMetric[metric] ?? []),
    ...names,
  ])];
  const rows = trackedRows.map((player) => ({
    playerName: player.name,
    parsePercent: player.parsePercent,
    rankPercent: player.parsePercent,
    keyPercent: player.keyPercent,
    totalParses: player.totalParses,
    rank: player.rank,
  }));
  candidate.rankings[metric] = {
    rankings: {
      rows: [...(candidate.rankings[metric]?.rankings?.rows ?? []), ...rows],
      population: {},
    },
  };
  if (Date.parse(request.timestamp) > Date.parse(candidate.rankingsCapturedAt)) {
    candidate.rankingsCapturedAt = request.timestamp;
  }
  candidates.set(key, candidate);
  usedRecords.push(request);
}

for (const candidate of candidates.values()) {
  candidate.refreshCharacters = [...new Set(Object.values(candidate.refreshCharactersByMetric).flat())];
}
const manifest = {
  generatedAt: candidates.size
    ? [...candidates.values()].map((candidate) => candidate.rankingsCapturedAt).sort().at(-1)
    : new Date().toISOString(),
  scanHealthy: true,
  candidates: [...candidates.values()],
};
const temporaryRoot = mkdtempSync(join(tmpdir(), 'wow-wcl-ranking-apply-'));
const manifestPath = join(temporaryRoot, 'manifest.json');
writeFileSync(manifestPath, JSON.stringify(manifest), 'utf8');
const assembler = join(repoRoot, 'scripts', 'wow-logs-sync', 'assemble-report.mjs');
const result = spawnSync(process.execPath, [assembler, '--input', manifestPath, '--reports-root', reportsRoot], { encoding: 'utf8' });
rmSync(temporaryRoot, { recursive: true, force: true });
if (result.status !== 0) throw new Error(result.stderr || result.stdout || 'Application des rankings échouée.');

process.stdout.write(`${JSON.stringify({
  requestsApplied: usedRecords.length,
  fightsUpdated: candidates.size,
  byMetric: [...candidates.values()].flatMap((candidate) => Object.keys(candidate.rankings)).reduce((counts, metric) => {
    counts[metric] = (counts[metric] ?? 0) + 1;
    return counts;
  }, {}),
  result: result.stdout.trim(),
})}\n`);
