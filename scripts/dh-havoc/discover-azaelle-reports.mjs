import fs from 'node:fs/promises';
import path from 'node:path';
import { WclClient, WclTokenProvider } from '../../wcl_mplus/api/index.mjs';

const repoRoot = path.resolve(import.meta.dirname, '../..');
const outputPath = path.join(repoRoot, 'data', 'dh-havoc', 'azaelle-discovery.json');
const logsPath = path.join(repoRoot, 'logs', 'reports');
const character = { name: 'Azåelle', realm: 'Hyjal', region: 'EU', spec: 'Havoc' };
const pageSize = 100;
const concurrency = 5;

const client = new WclClient({
  tokenProvider: new WclTokenProvider({
    clientId: process.env.WCL_CLIENT_ID,
    clientSecret: process.env.WCL_CLIENT_SECRET,
  }),
});

const reportsQuery = `query CharacterReports($name:String!,$server:String!,$region:String!,$limit:Int!,$page:Int!){
  characterData { character(name:$name,serverSlug:$server,serverRegion:$region) {
    canonicalID name server{name slug region{name slug}}
    recentReports(limit:$limit,page:$page) {
      data { code title startTime endTime visibility zone{name id} }
      total per_page current_page last_page has_more_pages
    }
  }}
}`;

const reportQuery = `query ReportDetails($code:String!){ reportData { report(code:$code) {
  code title startTime endTime visibility zone{name id}
  fights { id name startTime endTime kill difficulty keystoneLevel keystoneTime keystoneBonus countReached countRequired
    dungeonPulls { id name startTime endTime kill }
  }
}}}`;

async function readLocalReportCodes() {
  const files = await fs.readdir(logsPath, { withFileTypes: true });
  const codes = new Set();
  for (const file of files) {
    if (!file.isFile() || !file.name.endsWith('.json')) continue;
    const baseName = file.name.replace(/-fight-\d+\.json$/i, '.json');
    codes.add(baseName.replace(/\.json$/i, ''));
  }
  return codes;
}

async function fetchAllReports() {
  const reports = [];
  for (let page = 1; page <= 100; page += 1) {
    const data = await client.query(reportsQuery, {
      name: character.name,
      server: character.realm.toLowerCase(),
      region: character.region,
      limit: pageSize,
      page,
    });
    const pagination = data.characterData?.character?.recentReports;
    if (!pagination) throw new Error('Warcraft Logs returned no recentReports for Azåelle.');
    reports.push(...(pagination.data ?? []));
    if (!pagination.has_more_pages) return { character: data.characterData.character, reports, pagination };
  }
  throw new Error('Stopped after 100 Warcraft Logs report pages.');
}

async function mapWithConcurrency(items, worker) {
  const results = new Array(items.length);
  let cursor = 0;
  async function run() {
    while (true) {
      const index = cursor;
      cursor += 1;
      if (index >= items.length) return;
      results[index] = await worker(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, run));
  return results;
}

const { character: resolvedCharacter, reports: discoveredReports, pagination } = await fetchAllReports();
const localCodes = await readLocalReportCodes();
const details = await mapWithConcurrency(discoveredReports, async (report) => {
  const data = await client.query(reportQuery, { code: report.code });
  return data.reportData?.report ?? null;
});

const normalizedReports = discoveredReports.map((report, index) => {
  const detail = details[index];
  const fights = (detail?.fights ?? []).map((fight) => ({
    fightID: fight.id,
    name: fight.name,
    startTime: fight.startTime,
    endTime: fight.endTime,
    kill: fight.kill,
    keyLevel: fight.keystoneLevel,
    keyTimeMs: fight.keystoneTime,
    keyBonus: fight.keystoneBonus,
    countReached: fight.countReached,
    countRequired: fight.countRequired,
    dungeonPullCount: fight.dungeonPulls?.length ?? 0,
  }));
  return {
    code: report.code,
    title: detail?.title ?? report.title,
    zone: detail?.zone ?? report.zone ?? null,
    startTime: detail?.startTime ?? report.startTime,
    endTime: detail?.endTime ?? report.endTime,
    visibility: detail?.visibility ?? report.visibility,
    hasLocalRawReport: localCodes.has(report.code),
    fights,
  };
});

const runs = normalizedReports.flatMap((report) => report.fights
  .filter((fight) => fight.keyLevel !== null && fight.keyLevel !== undefined)
  .map((fight) => ({ reportCode: report.code, ...fight })));

const result = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  source: {
    provider: 'Warcraft Logs GraphQL API',
    endpoint: 'https://www.warcraftlogs.com/api/v2/client',
    method: 'characterData.character.recentReports',
    exactCharacterLookup: character,
  },
  character: {
    ...character,
    canonicalID: resolvedCharacter?.canonicalID ?? null,
    resolvedName: resolvedCharacter?.name ?? character.name,
    resolvedServer: resolvedCharacter?.server ?? null,
  },
  pagination: {
    totalReports: pagination.total,
    pagesFetched: pagination.last_page,
    pageSize: pagination.per_page,
  },
  counts: {
    discoveredReports: normalizedReports.length,
    localRawReportCodes: localCodes.size,
    discoveredReportsWithLocalRaw: normalizedReports.filter((report) => report.hasLocalRawReport).length,
    missingLocalRawReports: normalizedReports.filter((report) => !report.hasLocalRawReport).length,
    discoveredKeyFights: runs.length,
    completedKeyFights: runs.filter((run) => run.kill === true).length,
    failedOrIncompleteKeyFights: runs.filter((run) => run.kill !== true).length,
  },
  reports: normalizedReports,
  runs,
};

await fs.mkdir(path.dirname(outputPath), { recursive: true });
await fs.writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`, 'utf8');
console.log(JSON.stringify({
  outputPath,
  counts: result.counts,
  missingCodes: normalizedReports.filter((report) => !report.hasLocalRawReport).map((report) => report.code),
}, null, 2));
