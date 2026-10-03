import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((items, value, index, all) => {
    if (value.startsWith('--')) items.push([value.slice(2), all[index + 1]]);
    return items;
  }, []),
);

const since = args.since;
const reportsRoot = resolve(args['reports-root'] ?? 'logs/reports');
const mcpRoot = resolve(
  process.env.WOW_WCL_MCP_ROOT ?? 'C:/Users/Yaya/source/tools/warcraftlogs-mcp-fork',
);
const tracked = [
  { name: 'Kalteew', server: 'Hyjal', serverRegion: 'eu' },
  { name: 'Kylse', server: 'Hyjal', serverRegion: 'eu' },
  { name: 'Azåelle', server: 'Hyjal', serverRegion: 'eu' },
];
const RANKING_RETRY_DAYS = 7;

function normalizeName(value) {
  return String(value ?? '')
    .normalize('NFKD')
    .replace(/\p{Diacritic}/gu, '')
    .replace(/[^a-z0-9]/giu, '')
    .toLocaleLowerCase('en-US');
}

function errorInfo(error) {
  return {
    code: typeof error?.code === 'string' ? error.code : 'WCL_REQUEST_FAILED',
    message: String(error?.message ?? error).slice(0, 500),
    ...(error?.details ? { details: error.details } : {}),
  };
}

function rankingNumber(row, keys) {
  for (const key of keys) {
    const value = row?.[key] ?? row?.raw?.[key];
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string' && value.trim() !== '' && Number.isFinite(Number(value))) {
      return Number(value);
    }
  }
  return null;
}

function summarizeRankings(result, playerNames = []) {
  const rows = Array.isArray(result?.rankings?.rows)
    ? result.rankings.rows
    : Array.isArray(result?.rankings?.data)
      ? result.rankings.data
      : Array.isArray(result?.rankings)
        ? result.rankings
        : [];
  return {
    rowCount: rows.length,
    hasPayload: result?.rankings !== undefined && result?.rankings !== null,
    players: playerNames.map((name) => {
      const row = rows.find((entry) => normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name));
      return {
        name,
        matched: Boolean(row),
        parsePercent: rankingNumber(row, ['parsePercent', 'rankPercent', 'percentile']),
        keyPercent: rankingNumber(row, ['keyPercent', 'keyPercentile', 'bracketPercent']),
        totalParses: rankingNumber(row, ['totalParses', 'total_parses']),
        rank: row?.rank ?? null,
      };
    }),
    warnings: result?.warnings ?? [],
  };
}

function reportHasUsableKeyPercent(report, characterName) {
  const candidates = [
    report?.rankings?.values?.[characterName],
    ...Object.values(report?.rankings?.reportSpecific?.byMetric ?? {}).map(
      (metric) => metric?.values?.[characterName],
    ),
  ].filter(Boolean);
  return candidates.some((value) => {
    const legacyPlaceholder = value.keyPercent === 0
      && (value.keyPercentTotalParses ?? value.totalParses) === 0
      && value.rank === '-';
    return Number.isFinite(value.keyPercent) && value.keyPercentStatus !== 'pending' && !legacyPlaceholder;
  });
}

function makeRefreshCandidate(report, characterName) {
  const candidate = {
    key: `${report.reportCode}-fight-${report.fightID}`,
    code: report.reportCode,
    title: report.report?.title,
    owner: report.report?.owner ? { name: report.report.owner } : null,
    reportStartTime: report.report?.startTime,
    reportEndTime: report.report?.endTime,
    zone: report.report?.zone,
    visibility: report.report?.visibility,
    fightID: report.fightID,
    fightName: report.fight?.dungeon,
    keystoneLevel: report.fight?.keyLevel,
    discoveredFor: [],
    refreshRankingsOnly: true,
    refreshCharacters: [],
    summary: {
      completed: true,
      contentType: 'mythicplus',
      dungeon: report.fight?.dungeon,
      keyLevel: report.fight?.keyLevel,
      durationMs: report.fight?.durationMs,
      rating: report.fight?.rating,
      enemyForces: report.fight?.enemyForces,
      players: report.players ?? [],
      fight: {
        startTime: report.fight?.startTime,
        endTime: report.fight?.endTime,
        keystoneTime: report.fight?.keystoneTimeMs,
        encounterID: report.fight?.encounterID,
        keystoneAffixes: report.fight?.keystoneAffixes ?? [],
      },
    },
  };
  candidate.matchedCharacters = [characterName];
  candidate.refreshCharacters = [characterName];
  return candidate;
}

function addQuery(queries, query) {
  queries.push(query);
}

function writeJson(value) {
  const asciiJson = JSON.stringify(value).replace(/[^\x00-\x7F]/g, (character) =>
    `\\u${character.charCodeAt(0).toString(16).padStart(4, '0')}`,
  );
  process.stdout.write(asciiJson);
}

async function main() {
  const result = {
    generatedAt: new Date().toISOString(),
    since,
    rankingRetryWindowDays: RANKING_RETRY_DAYS,
    scanHealthy: Boolean(since),
    scans: [],
    candidates: [],
    queries: [],
    warnings: [],
  };
  if (!since || Number.isNaN(Date.parse(since))) {
    result.scanHealthy = false;
    result.warnings.push('Date de reprise invalide.');
    writeJson(result);
    return;
  }

  try {
    const { loadConfig, WclService } = await import(
      pathToFileURL(join(mcpRoot, 'src', 'index.ts')).href
    );
    const service = WclService.fromConfig(loadConfig());
    const reportCandidates = new Map();
    const scanSince = new Date(Math.min(
      Date.parse(since),
      Date.now() - RANKING_RETRY_DAYS * 24 * 60 * 60 * 1000,
    )).toISOString();

    for (const character of tracked) {
      const queryArgs = {
        ...character,
        since: scanSince,
        accessMode: 'user',
        limit: 20,
        maxPages: 10,
        contentType: 'mythicplus',
      };
      try {
        const scan = await service.getCharacterReportsSince(
          character,
          queryArgs,
        );
        const scanSummary = {
          complete: scan.scan.complete,
          pagesFetched: scan.scan.pagesFetched,
          maxPages: scan.scan.maxPages,
          matchedReportCount: scan.matchedReportCount,
          reportCodes: scan.reports.map((report) => report.code),
          warnings: scan.warnings,
        };
        addQuery(result.queries, {
          reportCode: 'character-sync',
          tool: 'mcp__warcraftlogs__get_character_reports_since',
          status: 'success',
          args: queryArgs,
          summary: scanSummary,
        });
        result.scans.push({ character: character.name, ...scanSummary });
        if (!scan.scan.complete) {
          result.scanHealthy = false;
          result.warnings.push(`Historique incomplet pour ${character.name}.`);
          continue;
        }

        for (const report of scan.reports) {
          if (!/^[A-Za-z0-9]+$/.test(report.code)) continue;
          for (const fight of report.fights) {
            if (
              fight.kill !== true ||
              fight.keystoneLevel === null ||
              !Number.isFinite(fight.startTime) ||
              !Number.isFinite(fight.endTime) ||
              fight.endTime <= fight.startTime
            ) {
              continue;
            }
            const key = `${report.code}-fight-${fight.id}`;
            const existingPath = join(reportsRoot, `${key}.json`);
            if (existsSync(existingPath)) {
              let existing;
              try {
                existing = JSON.parse(readFileSync(existingPath, 'utf8'));
              } catch {
                continue;
              }
              const trackedName = tracked.find((entry) =>
                normalizeName(entry.name) === normalizeName(character.name),
              )?.name;
              if (!trackedName || reportHasUsableKeyPercent(existing, trackedName)) continue;
              const pending = makeRefreshCandidate(existing, trackedName);
              const previous = reportCandidates.get(key);
              if (previous) {
                if (!previous.refreshCharacters.includes(trackedName)) previous.refreshCharacters.push(trackedName);
                if (!previous.matchedCharacters.includes(trackedName)) previous.matchedCharacters.push(trackedName);
              } else {
                reportCandidates.set(key, pending);
              }
              continue;
            }
            const previousCandidate = reportCandidates.get(key);
            if (previousCandidate?.refreshRankingsOnly) continue;
            const candidate = reportCandidates.get(key) ?? {
              key,
              code: report.code,
              title: report.title,
              owner: report.owner,
              reportStartTime: report.startTime,
              reportEndTime: report.endTime,
              zone: report.zone,
              visibility: report.visibility,
              fightID: fight.id,
              fightName: fight.name,
              keystoneLevel: fight.keystoneLevel,
              discoveredFor: [],
            };
            if (!candidate.discoveredFor.includes(character.name)) {
              candidate.discoveredFor.push(character.name);
            }
            reportCandidates.set(key, candidate);
          }
        }
      } catch (error) {
        result.scanHealthy = false;
        const detail = errorInfo(error);
        result.scans.push({ character: character.name, error: detail });
        result.warnings.push(`Échec de la recherche pour ${character.name}: ${detail.code}.`);
        addQuery(result.queries, {
          reportCode: 'character-sync',
          tool: 'mcp__warcraftlogs__get_character_reports_since',
          status: 'error',
          errorCode: detail.code,
          args: queryArgs,
          summary: {
            error: detail.message,
            ...(detail.details ? { details: detail.details } : {}),
          },
        });
      }
    }

    if (result.scanHealthy) {
      for (const candidate of reportCandidates.values()) {
        const baseArgs = {
          report: candidate.code,
          region: 'global',
          fightID: candidate.fightID,
          translate: true,
          accessMode: 'user',
        };
        let summary = candidate.summary;
        if (!candidate.refreshRankingsOnly) try {
          summary = await service.getMythicPlusSummary(candidate.code, {
            region: 'global',
            fight: candidate.fightID,
            translate: true,
            accessMode: 'user',
          });
          addQuery(result.queries, {
            reportCode: candidate.code,
            tool: 'mcp__warcraftlogs__get_mythic_plus_summary',
            status: 'success',
            args: baseArgs,
            summary: {
              completed: summary.completed,
              contentType: summary.contentType,
              keyLevel: summary.keyLevel,
              dungeon: summary.dungeon,
              playerCount: summary.players.length,
              warningCount: summary.warnings.length,
            },
          });
        } catch (error) {
          const detail = errorInfo(error);
          addQuery(result.queries, {
            reportCode: candidate.code,
            tool: 'mcp__warcraftlogs__get_mythic_plus_summary',
            status: 'error',
            errorCode: detail.code,
            args: baseArgs,
            summary: {
              error: detail.message,
              fightID: candidate.fightID,
              ...(detail.details ? { details: detail.details } : {}),
            },
          });
          result.warnings.push(`${candidate.key}: résumé WCL indisponible (${detail.code}).`);
          continue;
        }

        if (summary.completed !== true || summary.contentType !== 'mythicplus') continue;
        const matchingCharacters = candidate.refreshRankingsOnly
          ? tracked.filter((character) => candidate.refreshCharacters.some((name) => normalizeName(name) === normalizeName(character.name)))
          : tracked.filter((character) =>
              summary.players.some((player) => normalizeName(player.name) === normalizeName(character.name)),
            );
        if (matchingCharacters.length === 0) continue;

        const candidateData = {
          ...candidate,
          matchedCharacters: matchingCharacters.map((character) => character.name),
          summary,
          rankings: {},
          playerAnalysis: {},
          dataWarnings: [],
        };

        for (const metric of ['dps', 'hps', 'playerscore']) {
          const queryArgs = { ...baseArgs, compare: 'rankings', playerMetric: metric, timeframe: 'historical' };
          try {
            const rankingResult = await service.getReportRankings(candidate.code, {
              region: 'global',
              fight: candidate.fightID,
              translate: true,
              accessMode: 'user',
              compare: 'rankings',
              playerMetric: metric,
              timeframe: 'historical',
            });
            candidateData.rankings[metric] = rankingResult;
            addQuery(result.queries, {
              reportCode: candidate.code,
              tool: 'mcp__warcraftlogs__get_report_rankings',
              status: 'success',
              args: queryArgs,
              summary: summarizeRankings(rankingResult, candidateData.matchedCharacters),
            });
          } catch (error) {
            const detail = errorInfo(error);
            candidateData.dataWarnings.push(`${metric} rankings indisponibles: ${detail.code}.`);
            addQuery(result.queries, {
              reportCode: candidate.code,
              tool: 'mcp__warcraftlogs__get_report_rankings',
              status: 'error',
              errorCode: detail.code,
              args: queryArgs,
              summary: {
                error: detail.message,
                ...(detail.details ? { details: detail.details } : {}),
              },
            });
          }
        }

        const trackedPlayers = summary.players.filter((player) =>
          matchingCharacters.some((character) => normalizeName(player.name) === normalizeName(character.name)),
        );
        for (const player of candidate.refreshRankingsOnly ? [] : trackedPlayers) {
          if (!Number.isInteger(player.id) || player.id < 1) continue;
          const queryArgs = {
            ...baseArgs,
            player: player.id,
            maxEntries: 60,
            maxPayloadBytes: 300_000,
          };
          try {
            const context = await service.getPlayerAnalysisContext(candidate.code, player.id, {
              region: 'global',
              fight: candidate.fightID,
              translate: true,
              accessMode: 'user',
              maxEntries: 60,
              maxPayloadBytes: 300_000,
            });
            candidateData.playerAnalysis[player.name] = context;
            addQuery(result.queries, {
              reportCode: candidate.code,
              tool: 'mcp__warcraftlogs__get_player_analysis_context',
              status: 'success',
              args: queryArgs,
              summary: {
                player: player.name,
                actorID: player.id,
                warningCount: context.warnings?.length ?? 0,
                components: Object.keys(context.components ?? {}),
              },
            });
          } catch (error) {
            const detail = errorInfo(error);
            candidateData.dataWarnings.push(`${player.name} analysis indisponible: ${detail.code}.`);
            addQuery(result.queries, {
              reportCode: candidate.code,
              tool: 'mcp__warcraftlogs__get_player_analysis_context',
              status: 'error',
              errorCode: detail.code,
              args: queryArgs,
              summary: {
                player: player.name,
                error: detail.message,
                ...(detail.details ? { details: detail.details } : {}),
              },
            });
          }
        }
        result.candidates.push(candidateData);
      }
    }
  } catch (error) {
    result.scanHealthy = false;
    const detail = errorInfo(error);
    result.warnings.push(`Initialisation du connecteur Warcraft Logs impossible: ${detail.code}.`);
    result.fatalError = detail;
  }

  writeJson(result);
}

main().catch((error) => {
  writeJson({
      generatedAt: new Date().toISOString(),
      since,
      scanHealthy: false,
      scans: [],
      candidates: [],
      queries: [],
      warnings: [errorInfo(error).message],
      fatalError: errorInfo(error),
    });
  process.exitCode = 1;
});
