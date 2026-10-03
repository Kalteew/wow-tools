import { existsSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((items, value, index, all) => {
    if (value.startsWith('--')) items.push([value.slice(2), all[index + 1]]);
    return items;
  }, []),
);
const repoRoot = resolve(args.root ?? process.cwd());
const reportsRoot = resolve(args['reports-root'] ?? join(repoRoot, 'logs', 'reports'));
const logsRoot = resolve(args['logs-root'] ?? join(repoRoot, 'logs'));
const mcpRoot = resolve(
  process.env.WOW_WCL_MCP_ROOT ?? 'C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork',
);
const since = args.since ?? '2026-07-01T00:00:00.000Z';
const concurrency = Math.max(1, Math.min(4, Number(args.concurrency ?? 2)));
const recorder = 'C:/Users/Yaya/.codex/skills/warcraftlogs-core/scripts/record_wcl_request.ps1';
const assembler = join(repoRoot, 'scripts', 'wow-logs-sync', 'assemble-report.mjs');
const characters = [
  { name: 'Kalteew', server: 'Hyjal', serverRegion: 'eu' },
  { name: 'Kylse', server: 'Hyjal', serverRegion: 'eu' },
  { name: 'Azåelle', server: 'Hyjal', serverRegion: 'eu' },
];
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

function asNumber(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() && Number.isFinite(Number(value))) return Number(value);
  return null;
}

function recordRequest({ code, tool, queryArgs, status, summary, errorCode }) {
  const recorderArgs = [
    '-NoLogo', '-NoProfile', '-File', recorder,
    '-ReportCode', code,
    '-Tool', tool,
    '-ArgsJson', JSON.stringify(queryArgs),
    '-Status', status,
    '-SummaryJson', JSON.stringify(summary),
    '-LogsRoot', logsRoot,
  ];
  if (errorCode) recorderArgs.push('-ErrorCode', errorCode);
  execFileSync(process.env.POWERSHELL_EXE ?? 'pwsh.exe', recorderArgs, { encoding: 'utf8' });
}

function reportPlayerNames(report) {
  const found = new Map();
  for (const player of report.players ?? []) {
    const profile = aliases.get(normalizeName(player.name));
    if (profile) found.set(profile, player.name);
  }
  return [...found.entries()].map(([profile, name]) => ({ profile, name }));
}

function existingMetric(report, metric, name) {
  const metricValues = report.rankings?.reportSpecific?.byMetric?.[metric]?.values;
  const direct = metricValues && Object.entries(metricValues)
    .find(([key]) => normalizeName(key) === normalizeName(name))?.[1];
  if (direct) return direct;
  if (metric !== 'dps') return null;
  const primary = report.rankings?.reportSpecific?.values ?? report.rankings?.values ?? {};
  return Object.entries(primary)
    .find(([key]) => normalizeName(key) === normalizeName(name))?.[1] ?? null;
}

function keyPercentPresent(value) {
  const keyPercent = asNumber(value?.keyPercent);
  const totalParses = asNumber(value?.keyPercentTotalParses) ?? asNumber(value?.totalParses);
  const legacyPlaceholder = keyPercent === 0 && totalParses === 0 && value?.rank === '-';
  return keyPercent !== null && value?.keyPercentStatus !== 'pending' && !legacyPlaceholder;
}

function targetMetrics(report, players) {
  const refreshCharactersByMetric = { dps: players.map(({ name }) => name) };
  const healer = players.find(({ profile }) => profile === 'Kylse');
  if (healer) refreshCharactersByMetric.hps = [healer.name];
  return {
    refreshCharactersByMetric,
    refreshCharacters: [...new Set(Object.values(refreshCharactersByMetric).flat())],
    metrics: Object.keys(refreshCharactersByMetric),
  };
}

function keyPercentInResult(result, name) {
  const rows = result?.rankings?.rows ?? [];
  const row = rows.find((entry) =>
    normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name),
  );
  const keyPercent = asNumber(row?.keyPercent)
    ?? asNumber(row?.keyPercentile)
    ?? asNumber(row?.bracketPercent)
    ?? asNumber(row?.raw?.keyPercent)
    ?? asNumber(row?.raw?.keyPercentile)
    ?? asNumber(row?.raw?.bracketPercent);
  const totalParses = asNumber(row?.totalParses)
    ?? asNumber(row?.raw?.totalParses)
    ?? asNumber(result?.rankings?.population?.totalParses);
  return keyPercent !== null && !(keyPercent === 0 && totalParses === 0 && row?.rank === '-');
}

function compactRankingSummary(result, names) {
  const rows = result?.rankings?.rows ?? [];
  return {
    rowCount: rows.length,
    players: names.map((name) => {
      const row = rows.find((entry) =>
        normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name),
      );
      return {
        name,
        matched: Boolean(row),
        parsePercent: asNumber(row?.parsePercent) ?? asNumber(row?.rankPercent) ?? asNumber(row?.raw?.parsePercent) ?? asNumber(row?.raw?.rankPercent),
        keyPercent: asNumber(row?.keyPercent) ?? asNumber(row?.keyPercentile) ?? asNumber(row?.bracketPercent) ?? asNumber(row?.raw?.keyPercent) ?? asNumber(row?.raw?.keyPercentile) ?? asNumber(row?.raw?.bracketPercent),
        totalParses: asNumber(row?.totalParses) ?? asNumber(row?.raw?.totalParses),
        rank: row?.rank ?? null,
      };
    }),
    warnings: result?.warnings ?? [],
  };
}

function atomicJson(path, value) {
  const temporary = `${path}.backfill.tmp`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
  renameSync(temporary, path);
}

async function mapLimit(items, limit, fn) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      await fn(items[index], index);
    }
  });
  await Promise.all(workers);
}

async function main() {
  if (!existsSync(recorder)) throw new Error(`Journal MCP introuvable : ${recorder}`);
  const { loadConfig, WclService } = await import(pathToFileURL(join(mcpRoot, 'src', 'index.ts')).href);
  const service = WclService.fromConfig(loadConfig());
  const reportFiles = readdirSync(reportsRoot)
    .filter((name) => name.toLowerCase().endsWith('.json'))
    .map((name) => ({ name, path: join(reportsRoot, name), data: JSON.parse(readFileSync(join(reportsRoot, name), 'utf8')) }));
  const trackedFiles = reportFiles
    .map((entry) => ({ ...entry, trackedPlayers: reportPlayerNames(entry.data) }))
    .filter((entry) => entry.trackedPlayers.length > 0);
  const fightTimes = new Map();
  const callErrors = [];

  const scans = await Promise.all(characters.map(async (character) => {
    const queryArgs = { ...character, since, accessMode: 'user', limit: 100, maxPages: 100, contentType: 'mythicplus' };
    try {
      const scan = await service.getCharacterReportsSince(character, queryArgs);
      const summary = {
        complete: scan.scan.complete,
        pagesFetched: scan.scan.pagesFetched,
        matchedReportCount: scan.matchedReportCount,
        reportCodes: scan.reports.map((report) => report.code),
        warnings: scan.warnings,
      };
      recordRequest({
        code: 'character-sync',
        tool: 'mcp__warcraftlogs__get_character_reports_since',
        queryArgs,
        status: 'success',
        summary,
      });
      for (const report of scan.reports) {
        for (const fight of report.fights ?? []) {
          fightTimes.set(`${report.code}-fight-${fight.id}`, { report, fight });
        }
      }
      if (!scan.scan.complete) callErrors.push(`${character.name}: scan partiel`);
      return { character: character.name, ...summary };
    } catch (error) {
      const detail = { message: String(error?.message ?? error).slice(0, 500), code: error?.code ?? 'WCL_REQUEST_FAILED' };
      recordRequest({
        code: 'character-sync',
        tool: 'mcp__warcraftlogs__get_character_reports_since',
        queryArgs,
        status: 'error',
        summary: detail,
        errorCode: detail.code,
      });
      callErrors.push(`${character.name}: ${detail.code}`);
      return { character: character.name, error: detail };
    }
  }));

  const unresolvedCodes = [...new Set(trackedFiles
    .filter(({ data }) => !fightTimes.has(`${data.reportCode}-fight-${data.fightID}`))
    .map(({ data }) => data.reportCode))];
  await mapLimit(unresolvedCodes, concurrency, async (code) => {
    const metadataArgs = { report: code, region: 'global', accessMode: 'user' };
    const fightsArgs = { report: code, region: 'global', translate: true, accessMode: 'user' };
    const [metadataResult, fightsResult] = await Promise.allSettled([
      service.getReport(code, metadataArgs),
      service.listFights(code, fightsArgs),
    ]);
    let reportMetadata = null;
    let fights = [];
    for (const [result, tool, queryArgs] of [
      [metadataResult, 'mcp__warcraftlogs__get_report', metadataArgs],
      [fightsResult, 'mcp__warcraftlogs__list_fights', fightsArgs],
    ]) {
      if (result.status === 'fulfilled') {
        if (tool.endsWith('get_report')) reportMetadata = result.value.report;
        else fights = result.value.fights;
        recordRequest({
          code,
          tool,
          queryArgs,
          status: 'success',
          summary: tool.endsWith('get_report')
            ? { title: result.value.report.title, startTime: result.value.report.startTime, endTime: result.value.report.endTime }
            : { fightCount: result.value.fights.length, fightIDs: result.value.fights.map((fight) => fight.id) },
        });
      } else {
        const detail = { message: String(result.reason?.message ?? result.reason).slice(0, 500), code: result.reason?.code ?? 'WCL_REQUEST_FAILED' };
        recordRequest({ code, tool, queryArgs, status: 'error', summary: detail, errorCode: detail.code });
        callErrors.push(`${code}: ${tool} ${detail.code}`);
      }
    }
    if (!reportMetadata) return;
    for (const fight of fights) {
      fightTimes.set(`${code}-fight-${fight.id}`, {
        report: { code, startTime: reportMetadata.startTime, endTime: reportMetadata.endTime },
        fight,
      });
    }
  });

  let datesUpdated = 0;
  let dateUnavailable = 0;
  for (const entry of trackedFiles) {
    const key = `${entry.data.reportCode}-fight-${entry.data.fightID}`;
    const match = fightTimes.get(key);
    const reportStart = asNumber(match?.report?.startTime);
    const fightStart = asNumber(match?.fight?.startTime);
    if (reportStart === null || fightStart === null) {
      dateUnavailable++;
      continue;
    }
    const startedAt = new Date(reportStart + fightStart).toISOString();
    const reportEnd = asNumber(match.report.endTime);
    const fightEnd = asNumber(match.fight.endTime);
    const report = entry.data;
    report.report = {
      ...(report.report ?? {}),
      startTime: reportStart,
      ...(reportEnd === null ? {} : { endTime: reportEnd }),
    };
    report.fight = {
      ...(report.fight ?? {}),
      startTime: fightStart,
      ...(fightEnd === null ? {} : { endTime: fightEnd }),
      startedAt,
      ...(reportEnd !== null && fightEnd !== null
        ? { endedAt: new Date(reportEnd + fightEnd).toISOString() }
        : {}),
      startedAtSource: 'mcp.reportMetadata+fight',
    };
    atomicJson(entry.path, report);
    datesUpdated++;
  }

  const rankingCandidates = [];
  for (const entry of trackedFiles) {
    const report = entry.data;
    const targets = targetMetrics(report, entry.trackedPlayers);
    if (Object.keys(targets.refreshCharactersByMetric).length) {
      rankingCandidates.push({ entry, ...targets, rankings: {} });
    }
  }

  const rankingTasks = rankingCandidates.flatMap((candidate) => candidate.metrics.map((metric) => ({ candidate, metric })));
  let completedRankingCalls = 0;
  await mapLimit(rankingCandidates, concurrency, async (candidate) => {
    await Promise.all(candidate.metrics.map(async (metric) => {
      const code = candidate.entry.data.reportCode;
      const fightID = candidate.entry.data.fightID;
      const queryArgs = {
        report: code,
        region: 'global',
        fightID,
        compare: 'rankings',
        playerMetric: metric,
        timeframe: 'historical',
        translate: true,
        accessMode: 'user',
      };
      try {
        const result = await service.getReportRankings(code, {
          region: 'global',
          fight: fightID,
          compare: 'rankings',
          playerMetric: metric,
          timeframe: 'historical',
          translate: true,
          accessMode: 'user',
        });
        candidate.rankings[metric] = result;
        recordRequest({
          code,
          tool: 'mcp__warcraftlogs__get_report_rankings',
          queryArgs,
          status: 'success',
          summary: compactRankingSummary(result, candidate.entry.trackedPlayers.map((player) => player.name)),
        });
      } catch (error) {
        const detail = { message: String(error?.message ?? error).slice(0, 500), code: error?.code ?? 'WCL_REQUEST_FAILED' };
        recordRequest({
          code,
          tool: 'mcp__warcraftlogs__get_report_rankings',
          queryArgs,
          status: 'error',
          summary: detail,
          errorCode: detail.code,
        });
        callErrors.push(`${code} fight ${fightID} ${metric}: ${detail.code}`);
      }
      completedRankingCalls++;
    }));
  });

  const playerScoreCandidates = rankingCandidates.map((candidate) => {
    const names = candidate.entry.trackedPlayers.filter(({ name, profile }) => {
      const keyMetrics = profile === 'Kylse' ? ['dps', 'hps'] : ['dps'];
      const missingKey = keyMetrics.some((metric) => !keyPercentInResult(candidate.rankings[metric], name));
      return missingKey && !keyPercentPresent(existingMetric(candidate.entry.data, 'playerscore', name));
    }).map(({ name }) => name);
    if (names.length) {
      candidate.playerscoreCharacters = names;
      candidate.refreshCharactersByMetric.playerscore = names;
    }
    return names.length ? candidate : null;
  }).filter(Boolean);

  await mapLimit(playerScoreCandidates, concurrency, async (candidate) => {
    const code = candidate.entry.data.reportCode;
    const fightID = candidate.entry.data.fightID;
    const queryArgs = {
      report: code,
      region: 'global',
      fightID,
      compare: 'rankings',
      playerMetric: 'playerscore',
      timeframe: 'historical',
      translate: true,
      accessMode: 'user',
    };
    try {
      const result = await service.getReportRankings(code, {
        region: 'global',
        fight: fightID,
        compare: 'rankings',
        playerMetric: 'playerscore',
        timeframe: 'historical',
        translate: true,
        accessMode: 'user',
      });
      candidate.rankings.playerscore = result;
      recordRequest({
        code,
        tool: 'mcp__warcraftlogs__get_report_rankings',
        queryArgs,
        status: 'success',
        summary: compactRankingSummary(result, candidate.playerscoreCharacters),
      });
    } catch (error) {
      const detail = { message: String(error?.message ?? error).slice(0, 500), code: error?.code ?? 'WCL_REQUEST_FAILED' };
      recordRequest({
        code,
        tool: 'mcp__warcraftlogs__get_report_rankings',
        queryArgs,
        status: 'error',
        summary: detail,
        errorCode: detail.code,
      });
      callErrors.push(`${code} fight ${fightID} playerscore: ${detail.code}`);
    }
    completedRankingCalls++;
  });

  const generatedAt = new Date().toISOString();
  const manifest = {
    generatedAt,
    scanHealthy: true,
    scans,
    warnings: callErrors,
    candidates: rankingCandidates.map(({ entry, rankings, refreshCharacters, refreshCharactersByMetric }) => ({
      code: entry.data.reportCode,
      fightID: entry.data.fightID,
      matchedCharacters: entry.trackedPlayers.map((player) => player.name),
      refreshCharacters,
      refreshCharactersByMetric,
      refreshRankingsOnly: true,
      summary: { completed: true, contentType: 'mythicplus', keyLevel: entry.data.fight?.keyLevel },
      rankings,
    })),
  };
  const tempRoot = mkdtempSync(join(tmpdir(), 'wow-wcl-backfill-'));
  const manifestPath = join(tempRoot, 'manifest.json');
  writeFileSync(manifestPath, JSON.stringify(manifest), 'utf8');
  const result = spawnSync(process.execPath, [assembler, '--input', manifestPath, '--reports-root', reportsRoot], { encoding: 'utf8' });
  rmSync(tempRoot, { recursive: true, force: true });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || 'Assemblage des classements échoué.');

  process.stdout.write(`${JSON.stringify({
    scans: scans.map(({ character, complete, pagesFetched, matchedReportCount, error }) => ({ character, complete, pagesFetched, matchedReportCount, error })),
    trackedFights: trackedFiles.length,
    uniqueTrackedReports: new Set(trackedFiles.map(({ data }) => data.reportCode)).size,
    datesUpdated,
    dateUnavailable,
    rankingFightsRefreshed: rankingCandidates.length,
    rankingTasks: rankingTasks.length + playerScoreCandidates.length,
    completedRankingCalls,
    unresolvedErrors: callErrors,
    assembler: result.stdout.trim(),
  })}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
  process.exitCode = 1;
});
