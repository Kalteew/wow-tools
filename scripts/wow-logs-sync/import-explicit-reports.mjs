import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const args = Object.fromEntries(process.argv.slice(2).reduce((result, value, index, all) => {
  if (value.startsWith('--')) result.push([value.slice(2), all[index + 1]]);
  return result;
}, []));
const repoRoot = resolve(args.root ?? process.cwd());
const reportsRoot = resolve(args['reports-root'] ?? join(repoRoot, 'logs', 'reports'));
const logsRoot = resolve(args['logs-root'] ?? join(repoRoot, 'logs'));
const mcpRoot = resolve(process.env.WOW_WCL_MCP_ROOT ?? 'C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork');
const recorder = 'C:/Users/Yaya/.codex/skills/warcraftlogs-core/scripts/record_wcl_request.ps1';
const assembler = join(repoRoot, 'scripts', 'wow-logs-sync', 'assemble-report.mjs');
const requestedCodes = String(args.reports ?? '').split(/[\s,]+/u).filter(Boolean);
const characters = [
  { id: 'azaelle', aliases: ['azaelle', 'azael'] },
  { id: 'kalteew', aliases: ['kalteew', 'kaltou'] },
  { id: 'kylse', aliases: ['kylse', 'kils'] },
];

function normalizeName(value) {
  return String(value ?? '').normalize('NFKD').replace(/\p{Diacritic}/gu, '').replace(/[^a-z0-9]/giu, '').toLowerCase();
}

function profileFor(name) {
  const normalized = normalizeName(name);
  return characters.find((character) => character.aliases.some((alias) => normalizeName(alias) === normalized)) ?? null;
}

function recordRequest(reportCode, tool, queryArgs, status, summary, errorCode = null) {
  const recordArgs = [
    '-NoLogo', '-NoProfile', '-File', recorder,
    '-ReportCode', reportCode,
    '-Tool', tool,
    '-ArgsJson', JSON.stringify(queryArgs),
    '-Status', status,
    '-SummaryJson', JSON.stringify(summary),
    '-LogsRoot', logsRoot,
  ];
  if (errorCode) recordArgs.push('-ErrorCode', errorCode);
  execFileSync(process.env.POWERSHELL_EXE ?? 'pwsh.exe', recordArgs, { encoding: 'utf8' });
}

function errorSummary(error) {
  return { code: error?.code ?? 'WCL_REQUEST_FAILED', message: String(error?.message ?? error).slice(0, 500) };
}

async function loggedRequest({ reportCode, tool, queryArgs, call, summarize }) {
  try {
    const result = await call();
    recordRequest(reportCode, tool, queryArgs, 'success', summarize(result));
    return { result, error: null };
  } catch (error) {
    const detail = errorSummary(error);
    recordRequest(reportCode, tool, queryArgs, 'error', detail, detail.code);
    return { result: null, error: detail };
  }
}

function rankingRows(result) {
  const rows = result?.rankings?.rows;
  return Array.isArray(rows) ? rows : [];
}

function rankingSummary(result, names) {
  const rows = rankingRows(result);
  return {
    rowCount: rows.length,
    players: names.map((name) => {
      const row = rows.find((entry) => normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name));
      const number = (...values) => values.find((value) => typeof value === 'number' && Number.isFinite(value)) ?? null;
      return {
        name,
        matched: Boolean(row),
        parsePercent: number(row?.parsePercent, row?.rankPercent, row?.raw?.parsePercent, row?.raw?.rankPercent),
        keyPercent: number(row?.keyPercent, row?.keyPercentile, row?.bracketPercent, row?.raw?.keyPercent, row?.raw?.keyPercentile, row?.raw?.bracketPercent),
        totalParses: number(row?.totalParses, row?.raw?.totalParses),
        totalKeys: number(row?.totalKeys, row?.raw?.totalKeys),
        sampleSize: number(row?.sampleSize, row?.raw?.sampleSize),
        rank: row?.rank ?? null,
      };
    }),
    warningCount: result?.warnings?.length ?? 0,
  };
}

function usableKeyPercent(result, name) {
  const row = rankingRows(result).find((entry) => normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name));
  const key = row?.keyPercent ?? row?.keyPercentile ?? row?.bracketPercent ?? row?.raw?.keyPercent ?? row?.raw?.keyPercentile ?? row?.raw?.bracketPercent;
  const total = row?.totalParses ?? row?.raw?.totalParses ?? result?.rankings?.population?.totalParses;
  return typeof key === 'number' && Number.isFinite(key) && !(key === 0 && total === 0 && row?.rank === '-');
}

async function mapLimit(items, limit, fn) {
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      await fn(items[index], index);
    }
  }));
}

async function main() {
  if (!requestedCodes.length) throw new Error('Fournir --reports avec une liste de codes Warcraft Logs.');
  if (!existsSync(recorder)) throw new Error(`Journal MCP introuvable : ${recorder}`);
  const { loadConfig, WclService } = await import(pathToFileURL(join(mcpRoot, 'src', 'index.ts')).href);
  const service = WclService.fromConfig(loadConfig());
  const existingFiles = new Set(readdirSync(reportsRoot));
  const reportCandidates = [];
  const discoveryErrors = [];

  for (const reportCode of [...new Set(requestedCodes)]) {
    const metadataArgs = { report: reportCode, region: 'global', accessMode: 'user' };
    const fightsArgs = { report: reportCode, region: 'global', translate: true, accessMode: 'user' };
    const [metadataRequest, fightsRequest] = await Promise.all([
      loggedRequest({
        reportCode,
        tool: 'mcp__warcraftlogs__get_report',
        queryArgs: metadataArgs,
        call: () => service.getReport(reportCode, metadataArgs),
        summarize: (value) => ({ title: value.report.title, startTime: value.report.startTime, endTime: value.report.endTime, visibility: value.report.visibility }),
      }),
      loggedRequest({
        reportCode,
        tool: 'mcp__warcraftlogs__list_fights',
        queryArgs: fightsArgs,
        call: () => service.listFights(reportCode, fightsArgs),
        summarize: (value) => ({ fightCount: value.fights.length, fights: value.fights.map((fight) => ({ id: fight.id, name: fight.name, keystoneLevel: fight.keystoneLevel, completed: fight.kill === true })) }),
      }),
    ]);
    if (metadataRequest.error || fightsRequest.error) {
      discoveryErrors.push({ reportCode, metadata: metadataRequest.error, fights: fightsRequest.error });
      continue;
    }

    const metadata = metadataRequest.result.report;
    const completedKeys = fightsRequest.result.fights.filter((fight) => fight.keystoneLevel !== null && fight.kill === true);
    await mapLimit(completedKeys, 2, async (fight) => {
      const baseArgs = { report: reportCode, region: 'global', fightID: fight.id, translate: true, accessMode: 'user' };
      const summaryRequest = await loggedRequest({
        reportCode,
        tool: 'mcp__warcraftlogs__get_mythic_plus_summary',
        queryArgs: baseArgs,
        call: () => service.getMythicPlusSummary(reportCode, { region: 'global', fight: fight.id, translate: true, accessMode: 'user' }),
        summarize: (value) => ({ completed: value.completed, contentType: value.contentType, dungeon: value.dungeon, keyLevel: value.keyLevel, playerCount: value.players?.length ?? 0, warningCount: value.warnings?.length ?? 0 }),
      });
      const summary = summaryRequest.result;
      if (summaryRequest.error || summary.completed !== true || summary.contentType !== 'mythicplus') return;

      const trackedPlayers = (summary.players ?? []).filter((player) => profileFor(player.name));
      if (!trackedPlayers.length) return;
      const trackedNames = trackedPlayers.map((player) => player.name);
      const candidate = {
        key: `${reportCode}-fight-${fight.id}`,
        code: reportCode,
        title: metadata.title,
        owner: metadata.owner ? { name: typeof metadata.owner === 'string' ? metadata.owner : metadata.owner.name } : null,
        reportStartTime: metadata.startTime,
        reportEndTime: metadata.endTime,
        zone: metadata.zone,
        visibility: metadata.visibility,
        fightID: fight.id,
        fightName: summary.dungeon,
        keystoneLevel: summary.keyLevel,
        discoveredFor: trackedNames,
        matchedCharacters: trackedNames,
        summary,
        rankings: {},
        playerAnalysis: {},
        dataWarnings: [],
      };

      const metrics = ['dps'];
      if (trackedPlayers.some((player) => profileFor(player.name)?.id === 'kylse')) metrics.push('hps');
      await Promise.all([
        ...metrics.map(async (metric) => {
          const queryArgs = { ...baseArgs, compare: 'rankings', playerMetric: metric, timeframe: 'historical' };
          const rankingRequest = await loggedRequest({
            reportCode,
            tool: 'mcp__warcraftlogs__get_report_rankings',
            queryArgs,
            call: () => service.getReportRankings(reportCode, { region: 'global', fight: fight.id, translate: true, accessMode: 'user', compare: 'rankings', playerMetric: metric, timeframe: 'historical' }),
            summarize: (value) => rankingSummary(value, trackedNames),
          });
          if (rankingRequest.error) candidate.dataWarnings.push(`${metric} rankings indisponibles: ${rankingRequest.error.code}.`);
          else candidate.rankings[metric] = rankingRequest.result;
        }),
        ...trackedPlayers.filter((player) => Number.isInteger(player.id) && player.id > 0).map(async (player) => {
          const queryArgs = { ...baseArgs, player: player.id, maxEntries: 60, maxPayloadBytes: 300_000 };
          const analysisRequest = await loggedRequest({
            reportCode,
            tool: 'mcp__warcraftlogs__get_player_analysis_context',
            queryArgs,
            call: () => service.getPlayerAnalysisContext(reportCode, player.id, { region: 'global', fight: fight.id, translate: true, accessMode: 'user', maxEntries: 60, maxPayloadBytes: 300_000 }),
            summarize: (value) => ({ player: player.name, actorID: player.id, warningCount: value.warnings?.length ?? 0, components: Object.keys(value.evidence ?? {}) }),
          });
          if (analysisRequest.error) candidate.dataWarnings.push(`${player.name} analysis indisponible: ${analysisRequest.error.code}.`);
          else candidate.playerAnalysis[player.name] = analysisRequest.result;
        }),
      ]);

      const keyPercentMissing = trackedPlayers.some((player) => {
        const metric = profileFor(player.name)?.id === 'kylse' ? 'hps' : 'dps';
        return !usableKeyPercent(candidate.rankings[metric], player.name);
      });
      if (keyPercentMissing) {
        const queryArgs = { ...baseArgs, compare: 'rankings', playerMetric: 'playerscore', timeframe: 'historical' };
        const scoreRequest = await loggedRequest({
          reportCode,
          tool: 'mcp__warcraftlogs__get_report_rankings',
          queryArgs,
          call: () => service.getReportRankings(reportCode, { region: 'global', fight: fight.id, translate: true, accessMode: 'user', compare: 'rankings', playerMetric: 'playerscore', timeframe: 'historical' }),
          summarize: (value) => rankingSummary(value, trackedNames),
        });
        if (scoreRequest.error) candidate.dataWarnings.push(`playerscore indisponible: ${scoreRequest.error.code}.`);
        else candidate.rankings.playerscore = scoreRequest.result;
      }
      reportCandidates.push(candidate);
    });
  }

  if (discoveryErrors.length) {
    process.stdout.write(`${JSON.stringify({ imported: 0, discoveryErrors })}\n`);
    process.exitCode = 1;
    return;
  }

  const candidatesToImport = reportCandidates.filter((candidate) => !existingFiles.has(`${candidate.code}-fight-${candidate.fightID}.json`));
  const manifest = { generatedAt: new Date().toISOString(), scanHealthy: true, candidates: candidatesToImport };
  const tempRoot = mkdtempSync(join(tmpdir(), 'wow-wcl-explicit-reports-'));
  const manifestPath = join(tempRoot, 'manifest.json');
  writeFileSync(manifestPath, JSON.stringify(manifest), 'utf8');
  const result = spawnSync(process.execPath, [assembler, '--input', manifestPath, '--reports-root', reportsRoot], { encoding: 'utf8' });
  rmSync(tempRoot, { recursive: true, force: true });
  if (result.status !== 0) throw new Error(result.stderr || result.stdout || 'Import des rapports échoué.');
  process.stdout.write(`${JSON.stringify({ requestedCodes: [...new Set(requestedCodes)], completedTrackedFights: reportCandidates.length, imported: candidatesToImport.length, alreadyPresent: reportCandidates.length - candidatesToImport.length, discoveryErrors, assembler: result.stdout.trim() })}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error instanceof Error ? error.stack ?? error.message : String(error)}\n`);
  process.exitCode = 1;
});
