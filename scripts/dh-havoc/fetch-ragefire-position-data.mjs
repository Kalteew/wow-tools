import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { WclService, loadConfig } from 'file:///C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork/dist/index.mjs';

const root = 'C:/Users/Yaya/source/tools/wow-tools';
const outputDir = path.join(root, 'logs', 'comparisons', 'ragefire-position');
fs.mkdirSync(outputDir, { recursive: true });

const runs = [
  { slug: 'den-15', report: '1hPRWD6AfTQFBazV', fight: 2, sourceID: 79 },
  { slug: 'kings-rest-12', report: '1hPRWD6AfTQFBazV', fight: 3, sourceID: 79 },
  { slug: 'temple-15', report: '6dHGQ8PjDVq4Wtwa', fight: 2, sourceID: 1 },
  { slug: 'murder-row-15', report: '6dHGQ8PjDVq4Wtwa', fight: 3, sourceID: 1 },
  { slug: 'murder-row-16', report: 'RdkTpmDVrJ9KNG7A', fight: 1, sourceID: 1 },
];

const auraIDs = [258922, 427908, 427910, 427911, 258921, 427904, 427905, 427906];
const service = WclService.fromConfig(loadConfig());

function recordRequest(run, tool, args, status, summary, errorCode = '') {
  const argv = [
    '-NoProfile',
    '-File',
    'C:/Users/Yaya/.codex/skills/warcraftlogs-core/scripts/record_wcl_request.ps1',
    '-ReportCode', run.report,
    '-Tool', tool,
    '-ArgsJson', JSON.stringify(args),
    '-Status', status,
    '-SummaryJson', JSON.stringify(summary),
    '-LogsRoot', `${root}/logs`,
  ];
  if (errorCode) argv.push('-ErrorCode', errorCode);
  const result = spawnSync('powershell', argv, { encoding: 'utf8', windowsHide: true });
  if (result.status !== 0) throw new Error(`Request history failed: ${result.stderr}`);
}

async function cached(run, fileName, tool, args, fn) {
  const file = path.join(outputDir, fileName);
  if (fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  try {
    const result = await fn();
    fs.writeFileSync(file, JSON.stringify(result, null, 2));
    recordRequest(run, tool, args, 'success', { file, bytes: fs.statSync(file).size });
    return result;
  } catch (error) {
    recordRequest(run, tool, args, 'error', { message: error.message }, error.code ?? 'UNKNOWN');
    throw error;
  }
}

function eventField(alias, dataType, run, startTime, endTime, extra = '') {
  return `${alias}:events(dataType:${dataType}, fightIDs:[${run.fight}], startTime:${startTime}, endTime:${endTime}, limit:10000, useAbilityIDs:true, useActorIDs:true${extra}) { data nextPageTimestamp }`;
}

async function fetchRun(run) {
  const pulls = await cached(
    run,
    `${run.slug}-pulls.json`,
    'list_dungeon_pulls',
    { report: run.report, fightID: run.fight },
    () => service.listDungeonPulls(run.report, { fight: run.fight, accessMode: 'public' }),
  );
  const startTime = pulls.fight.startTime;
  const endTime = pulls.fight.endTime;
  const eventSpecs = [
    ['ragefire', 'DamageDone', `, sourceID:${run.sourceID}, abilityID:390197`],
    ...auraIDs.map((id) => [`a${id}`, 'DamageDone', `, sourceID:${run.sourceID}, abilityID:${id}`]),
    ['deaths', 'Deaths', ''],
  ];
  const events = {};
  for (const [alias, dataType, extra] of eventSpecs) {
    const query = `query RagefirePosition($code:String!){reportData{report(code:$code){${eventField(alias, dataType, run, startTime, endTime, extra)}}}}`;
    events[alias] = await cached(
      run,
      `${run.slug}-${alias}.json`,
      'get_events',
      { report: run.report, fightID: run.fight, sourceID: run.sourceID, abilityID: alias, dataType, startTime, endTime },
      () => service.client.query('https://www.warcraftlogs.com', query, { code: run.report }, { mode: 'public' }),
    );
  }
  const buffs = await cached(
    run,
    `${run.slug}-buffs.json`,
    'get_buffs',
    { report: run.report, fightID: run.fight, targetID: run.sourceID },
    () => service.getTable(run.report, 'Buffs', { fight: run.fight, accessMode: 'public', filter: { targetID: run.sourceID }, maxEntries: 250, maxPayloadBytes: 1000000 }),
  );
  return { run, pulls, events, buffs };
}

const results = [];
for (const run of runs) results.push(await fetchRun(run));
console.log(JSON.stringify(results.map(({ run, pulls, events, buffs }) => ({
  slug: run.slug,
  report: run.report,
  fight: run.fight,
  startTime: pulls.fight.startTime,
  endTime: pulls.fight.endTime,
  eventKeys: Object.keys(events),
  auraCount: Object.values(events).length,
  buffBytes: JSON.stringify(buffs).length,
})), null, 2));
