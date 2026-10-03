import { existsSync, readFileSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((items, value, index, all) => {
    if (value.startsWith('--')) items.push([value.slice(2), all[index + 1]]);
    return items;
  }, []),
);
const inputPath = resolve(args.input ?? '');
const reportsRoot = resolve(args['reports-root'] ?? 'logs/reports');
const forceOverwrite = process.argv.includes('--force');

const TRACKED = new Map([
  ['azaelle', 'azaelle'],
  ['kalteew', 'kalteew'],
  ['kylse', 'kylse'],
]);

function normalizeName(value) {
  return String(value ?? '')
    .normalize('NFKD')
    .replace(/\p{Diacritic}/gu, '')
    .replace(/[^a-z0-9]/giu, '')
    .toLocaleLowerCase('en-US');
}

function numberOrNull(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() !== '' && Number.isFinite(Number(value))) return Number(value);
  return null;
}

function parseSpec(player) {
  const specs = player?.specs;
  const first = Array.isArray(specs) ? specs[0] : specs;
  return typeof first === 'string' ? first : first?.name ?? first?.spec ?? null;
}

function readReports() {
  return readdirSync(reportsRoot)
    .filter((name) => name.endsWith('.json'))
    .map((name) => {
      try {
        return JSON.parse(readFileSync(join(reportsRoot, name), 'utf8'));
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

const existingReports = readReports();
const template = [...existingReports].sort((left, right) =>
  String(right.capturedAt ?? '').localeCompare(String(left.capturedAt ?? '')),
)[0];

function previousMetrics(profileId, spec) {
  return existingReports
    .map((report) => report.playerMetrics?.[profileId])
    .filter((entry) => entry && (!spec || entry.spec === spec))
    .sort((left, right) => String(right.capturedAt ?? '').localeCompare(String(left.capturedAt ?? '')))[0];
}

function combatantEvent(context) {
  const events = context?.evidence?.combatantInfo?.events;
  return Array.isArray(events) ? events.find((event) => event && typeof event === 'object') ?? null : null;
}

function spellStat(event, stem, spec) {
  const casterSpecs = new Set([
    'Arcane', 'Balance', 'Demonology', 'Destruction', 'Devastation', 'Elemental',
    'Fire', 'Frost', 'Holy', 'Mistweaver', 'Preservation', 'Restoration', 'Shadow',
    'Subtlety', 'Unholy', 'Affliction', 'Augmentation',
  ]);
  const rangedSpecs = new Set(['Beast Mastery', 'Marksmanship']);
  const field = casterSpecs.has(spec)
    ? `${stem}Spell`
    : rangedSpecs.has(spec)
      ? `${stem}Ranged`
      : `${stem}Melee`;
  return numberOrNull(event?.[field]) ?? numberOrNull(event?.[`${stem}Spell`]) ?? numberOrNull(event?.[`${stem}Melee`]);
}

function statBlock(event, spec) {
  return {
    strength: numberOrNull(event?.strength),
    agility: numberOrNull(event?.agility),
    stamina: numberOrNull(event?.stamina),
    intellect: numberOrNull(event?.intellect),
    crit: spellStat(event, 'crit', spec),
    haste: spellStat(event, 'haste', spec),
    mastery: numberOrNull(event?.mastery),
    versatility: numberOrNull(event?.versatilityDamageDone),
    armor: numberOrNull(event?.armor),
    leech: numberOrNull(event?.leech),
    avoidance: numberOrNull(event?.avoidance),
    speed: numberOrNull(event?.speed),
    dodge: numberOrNull(event?.dodge),
    parry: numberOrNull(event?.parry),
    block: numberOrNull(event?.block),
  };
}

function gearBlock(event, player) {
  const gear = Array.isArray(event?.gear) ? event.gear : [];
  const levels = gear.map((item) => numberOrNull(item?.itemLevel)).filter((value) => value !== null);
  return {
    itemLevelAverage: levels.length ? levels.reduce((total, value) => total + value, 0) / levels.length : null,
    itemLevelMax: levels.length ? Math.max(...levels) : null,
    equippedSlots: gear.length,
    gems: gear.reduce((total, item) => total + (Array.isArray(item?.gems) ? item.gems.length : 0), 0),
    setPieces: gear.filter((item) => item?.setID !== null && item?.setID !== undefined).length,
    itemLevels: Array.isArray(player?.itemLevels) ? player.itemLevels : [],
    equipment: gear,
  };
}

function tableData(context, name) {
  const table = context?.evidence?.[name];
  const payload = table?.data;
  const first = Array.isArray(payload) ? payload[0] : payload;
  return first?.data?.data ?? first?.data ?? null;
}

function castBlock(context, templateMetric, durationSeconds) {
  const table = tableData(context, 'casts');
  const entries = Array.isArray(table?.entries) ? table.entries : [];
  const abilities = entries.map((entry) => ({
    name: entry.name,
    casts: numberOrNull(entry.total) ?? 0,
    id: numberOrNull(entry.guid),
  }));
  const total = abilities.reduce((sum, ability) => sum + ability.casts, 0);
  const minutes = durationSeconds > 0 ? durationSeconds / 60 : null;
  const trackedCooldownNames = templateMetric?.casts?.trackedCooldownNames ?? [];
  const trackedAbilityNames = templateMetric?.casts?.trackedAbilityNames ?? [];
  const trackedCooldowns = abilities.filter((ability) => trackedCooldownNames.includes(ability.name));
  const cooldownTotal = trackedCooldowns.reduce((sum, ability) => sum + ability.casts, 0);
  return {
    total,
    perMinute: minutes ? total / minutes : null,
    abilities,
    cooldowns: trackedCooldowns,
    cooldownTotal,
    cooldownsPerMinute: minutes ? cooldownTotal / minutes : null,
    trackedCooldownNames,
    trackedAbilityNames,
    sourceEntries: entries,
    truncated: Boolean(context?.evidence?.casts?.data?.[0]?.meta?.truncated),
  };
}

function buildValue(row, metric, population, keyLevel) {
  const totalParses = numberOrNull(row?.totalParses) ?? numberOrNull(population?.totalParses);
  const totalKeys = numberOrNull(row?.totalKeys) ?? numberOrNull(population?.totalKeys);
  const parsePercent = numberOrNull(row?.parsePercent)
    ?? numberOrNull(row?.rankPercent)
    ?? numberOrNull(row?.raw?.parsePercent)
    ?? numberOrNull(row?.raw?.parsePercentile)
    ?? numberOrNull(row?.raw?.rankPercent)
    ?? numberOrNull(row?.raw?.percentile);
  const rawKeyPercent = numberOrNull(row?.keyPercent)
    ?? numberOrNull(row?.keyPercentile)
    ?? numberOrNull(row?.bracketPercent)
    ?? numberOrNull(row?.raw?.keyPercent)
    ?? numberOrNull(row?.raw?.keyPercentile)
    ?? numberOrNull(row?.raw?.bracketPercent);
  const rank = row?.rank ?? row?.raw?.rank ?? null;
  const keyPercentPending = rawKeyPercent === 0 && totalParses === 0 && rank === '-';
  const keyPercent = keyPercentPending ? null : rawKeyPercent;
  return {
    parsePercent,
    parsePercentSource: parsePercent === null ? 'unavailable' : 'mcp.reportRankings',
    keyPercent,
    keyPercentRaw: keyPercentPending ? rawKeyPercent : null,
    keyPercentStatus: keyPercentPending ? 'pending' : keyPercent === null ? 'unavailable' : 'available',
    keyPercentSource: keyPercentPending ? 'mcp.reportRankings.pending' : keyPercent === null ? 'unavailable' : `mcp.reportRankings.${metric}`,
    keyPercentTotalParses: totalParses,
    totalParses,
    totalKeys,
    sampleSize: numberOrNull(row?.sampleSize) ?? numberOrNull(population?.sampleSize),
    displayedSampleSize: numberOrNull(row?.displayedSampleSize) ?? numberOrNull(population?.displayedSampleSize),
    keyLevel: numberOrNull(row?.keyLevel) ?? keyLevel,
    metric,
    source: 'mcp',
    rank,
    outOf: numberOrNull(row?.outOf),
  };
}

function rankingBlock(candidate, capturedAt) {
  const valuesByMetric = {};
  const primaryValues = {};
  const scoreRankingData = candidate.rankings?.playerscore?.rankings;
  const scoreRows = Array.isArray(scoreRankingData?.rows) ? scoreRankingData.rows : [];
  for (const metric of ['dps', 'hps', 'playerscore']) {
    const result = candidate.rankings?.[metric];
    const rankingData = result?.rankings;
    const rows = Array.isArray(rankingData?.rows) ? rankingData.rows : [];
    const values = {};
    for (const name of candidate.matchedCharacters ?? []) {
      const row = rows.find((entry) => normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name));
      const value = buildValue(row, metric, rankingData?.population, candidate.summary?.keyLevel);
      if (metric !== 'playerscore' && value.keyPercent === null) {
        const scoreRow = scoreRows.find((entry) => normalizeName(entry.playerName ?? entry.raw?.name) === normalizeName(name));
        const score = buildValue(scoreRow, 'playerscore', scoreRankingData?.population, candidate.summary?.keyLevel);
        if (score.keyPercent !== null) {
          value.keyPercent = score.keyPercent;
          value.keyPercentRaw = score.keyPercentRaw;
          value.keyPercentStatus = score.keyPercentStatus;
          value.keyPercentSource = score.keyPercentSource;
          value.keyPercentTotalParses = score.keyPercentTotalParses;
        } else if (score.keyPercentStatus === 'pending') {
          value.keyPercentRaw = score.keyPercentRaw;
          value.keyPercentStatus = 'pending';
          value.keyPercentSource = score.keyPercentSource;
          value.keyPercentTotalParses = score.keyPercentTotalParses;
        }
      }
      values[name] = value;
      if (metric === 'dps') primaryValues[name] = value;
    }
    valuesByMetric[metric] = { source: 'mcp', capturedAt, values };
  }
  return {
    queried: true,
    source: 'mcp',
    capturedAt,
    values: primaryValues,
    reportSpecific: {
      source: 'mcp',
      capturedAt,
      values: primaryValues,
      byMetric: valuesByMetric,
    },
  };
}

function mergeRankingValue(previous, incoming) {
  if (!previous) return incoming;
  const merged = { ...previous, ...incoming };
  if (incoming.parsePercent === null && numberOrNull(previous.parsePercent) !== null) {
    merged.parsePercent = previous.parsePercent;
    merged.parsePercentSource = previous.parsePercentSource;
  }
  if (incoming.keyPercent === null && numberOrNull(previous.keyPercent) !== null) {
    merged.keyPercent = previous.keyPercent;
    merged.keyPercentStatus = previous.keyPercentStatus ?? 'available';
    merged.keyPercentSource = previous.keyPercentSource;
    merged.keyPercentRaw = previous.keyPercentRaw ?? null;
    merged.keyPercentTotalParses = previous.keyPercentTotalParses ?? previous.totalParses ?? null;
  }
  for (const field of ['totalParses', 'totalKeys', 'sampleSize', 'displayedSampleSize', 'keyLevel', 'rank', 'outOf']) {
    if (incoming[field] === null && previous[field] !== null && previous[field] !== undefined) {
      merged[field] = previous[field];
    }
  }
  return merged;
}

function mergeRefreshedRankings(existing, candidate, capturedAt) {
  const rankingCapturedAt = candidate.rankingsCapturedAt ?? capturedAt;
  const refreshed = rankingBlock(candidate, rankingCapturedAt);
  const rankings = existing.rankings ?? {};
  const reportSpecific = rankings.reportSpecific ?? {};
  const values = { ...(rankings.values ?? {}) };
  const reportValues = { ...(reportSpecific.values ?? {}) };
  const byMetric = { ...(reportSpecific.byMetric ?? {}) };
  for (const metric of ['dps', 'hps', 'playerscore']) {
    if (!candidate.rankings?.[metric]) continue;
    const names = candidate.refreshCharactersByMetric?.[metric]
      ?? candidate.refreshCharacters
      ?? candidate.matchedCharacters
      ?? [];
    for (const name of names) {
      const incoming = refreshed.reportSpecific.byMetric[metric].values[name];
      if (!incoming) continue;
      if (metric === 'dps') {
        const merged = mergeRankingValue(values[name] ?? reportValues[name], incoming);
        values[name] = merged;
        reportValues[name] = merged;
      }
      const current = byMetric[metric] ?? { source: 'mcp', capturedAt, values: {} };
      byMetric[metric] = {
        ...current,
        source: 'mcp',
        capturedAt: rankingCapturedAt,
        values: {
          ...(current.values ?? {}),
          [name]: mergeRankingValue(current.values?.[name], incoming),
        },
      };
    }
  }
  existing.rankings = {
    ...rankings,
    source: 'mcp',
    capturedAt: rankingCapturedAt,
    values,
    reportSpecific: {
      ...reportSpecific,
      source: 'mcp',
      capturedAt: rankingCapturedAt,
      values: reportValues,
      byMetric,
    },
  };
  existing.lastRankingsRefreshAt = capturedAt;

  const qualityFlags = (existing.qualityFlags ?? []).filter(
    (flag) => !['RANKINGS_UNAVAILABLE', 'RANKINGS_PENDING'].includes(flag.code),
  );
  const rankingValues = [
    ...Object.values(values),
    ...Object.values(byMetric).flatMap((metric) => Object.values(metric?.values ?? {})),
  ];
  const hasPending = rankingValues.some((value) => value.keyPercentStatus === 'pending');
  const hasUsable = rankingValues.some((value) => value.parsePercent !== null || value.keyPercent !== null);
  if (hasPending) {
    qualityFlags.push({
      code: 'RANKINGS_PENDING',
      message: 'Warcraft Logs n’a pas encore publié le classement de cette clé ; le Key % sera retenté automatiquement.',
    });
  } else if (!hasUsable && rankingValues.length) {
    qualityFlags.push({
      code: 'RANKINGS_UNAVAILABLE',
      message: 'Warcraft Logs ne fournit pas de parse/percentile exploitable pour cette clé ; ces valeurs restent nulles, pas zéro.',
    });
  }
  existing.qualityFlags = qualityFlags;
  return existing;
}

function buildPlayerMetric(candidate, player, capturedAt, durationSeconds) {
  const profileId = TRACKED.get(normalizeName(player.name));
  if (!profileId) return null;
  const context = candidate.playerAnalysis?.[player.name];
  const event = combatantEvent(context);
  const spec = parseSpec(player) ?? context?.player?.specs?.[0] ?? null;
  const prior = previousMetrics(profileId, spec);
  const analysisEvidence = context?.evidence ?? {};
  const analysis = {
    source: 'mcp',
    capturedAt,
    fightID: candidate.fightID,
    damageDone: analysisEvidence.damageDone ?? null,
    damageTaken: analysisEvidence.damageTaken ?? null,
    interrupts: analysisEvidence.interrupts ?? null,
    resources: analysisEvidence.resources ?? null,
    combatantInfoEvent: analysisEvidence.combatantInfo ?? null,
    buffs: analysisEvidence.buffs ?? null,
    casts: analysisEvidence.casts ?? null,
    deaths: analysisEvidence.deaths ?? null,
    sourceTargetSemantics: context?.sourceTargetSemantics ?? null,
    warnings: [...(context?.warnings ?? []), ...(candidate.dataWarnings ?? [])],
  };
  return {
    stats: statBlock(event, spec),
    gear: gearBlock(event, player),
    casts: castBlock(context, prior, durationSeconds),
    build: event
      ? {
          specID: event.specID ?? null,
          talentTree: event.talentTree ?? [],
          talents: event.talents ?? [],
          pvpTalents: event.pvpTalents ?? [],
          customPowerSet: event.customPowerSet ?? null,
          secondaryCustomPowerSet: event.secondaryCustomPowerSet ?? null,
          tertiaryCustomPowerSet: event.tertiaryCustomPowerSet ?? null,
        }
      : null,
    sourceName: player.name,
    actorID: player.id ?? null,
    spec,
    capturedAt,
    source: 'mcp',
    deathAnalysis: {
      source: 'mcp',
      capturedAt,
      fightID: candidate.fightID,
      deaths: analysisEvidence.deaths ?? null,
    },
    analysis,
    statsSource: event ? 'mcp.combatantInfo' : 'unavailable',
  };
}

function buildFightMetrics(candidate, players) {
  const byMetric = { dps: {}, hps: {}, deathsByPlayer: {}, interrupts: {} };
  for (const player of players) {
    byMetric.dps[player.name] = player.roleMetrics.dps;
    byMetric.hps[player.name] = player.roleMetrics.hps;
    byMetric.deathsByPlayer[player.name] = player.roleMetrics.deaths;
    byMetric.interrupts[player.name] = player.roleMetrics.interrupts;
  }
  return { ...byMetric, deathsTotal: players.reduce((sum, player) => sum + (player.roleMetrics.deaths ?? 0), 0) };
}

function makeReport(candidate, capturedAt) {
  const summary = candidate.summary;
  const summaryFight = summary.fight ?? {};
  const players = summary.players.map((player) => {
    const roleMetrics = {
      dps: numberOrNull(player.dps),
      hps: numberOrNull(player.hps),
      deaths: numberOrNull(player.deaths),
      interrupts: numberOrNull(player.interrupts),
      totalDamage: numberOrNull(player.totalDamage),
      totalHealing: numberOrNull(player.totalHealing),
    };
    const spec = parseSpec(player);
    return {
      id: player.id ?? null,
      name: player.name,
      server: player.server ?? null,
      class: player.class ?? null,
      spec,
      itemLevel: Array.isArray(player.itemLevels) ? player.itemLevels[0] ?? null : null,
      itemLevels: player.itemLevels ?? [],
      roleMetrics,
    };
  });
  const metrics = buildFightMetrics(candidate, players);
  const playerMetrics = {};
  for (const name of candidate.matchedCharacters ?? []) {
    const player = players.find((entry) => normalizeName(entry.name) === normalizeName(name));
    if (player) {
      const profileId = TRACKED.get(normalizeName(player.name));
      const value = buildPlayerMetric(candidate, player, capturedAt, summary.durationSeconds);
      if (profileId && value) playerMetrics[profileId] = value;
    }
  }

  const qualityFlags = [];
  if (summary.enemyForces?.percent !== null && summary.enemyForces?.percent < 100) {
    qualityFlags.push({
      code: 'ENEMY_FORCES_BELOW_REQUIRED',
      message: `WCL marque la clé terminée alors que les forces sont à ${summary.enemyForces.percent} % ; valeur conservée telle quelle.`,
    });
  }
  const rankingValues = Object.values(rankingBlock(candidate, capturedAt).values);
  if (rankingValues.some((value) => value.keyPercentStatus === 'pending')) {
    qualityFlags.push({
      code: 'RANKINGS_PENDING',
      message: 'Warcraft Logs n’a pas encore publié le classement de cette clé ; le Key % sera retenté automatiquement.',
    });
  } else if (rankingValues.length && rankingValues.every((value) => value.parsePercent === null && value.keyPercent === null)) {
    qualityFlags.push({
      code: 'RANKINGS_UNAVAILABLE',
      message: 'Warcraft Logs ne fournit pas de parse/percentile exploitable pour cette clé ; ces valeurs restent nulles, pas zéro.',
    });
  }
  for (const warning of candidate.dataWarnings ?? []) {
    qualityFlags.push({ code: 'OPTIONAL_WCL_DATA_UNAVAILABLE', message: warning });
  }

  const durationMs = numberOrNull(summary.durationMs);
  const fight = {
    id: candidate.fightID,
    dungeon: summary.dungeon ?? candidate.fightName,
    keyLevel: summary.keyLevel ?? candidate.keystoneLevel,
    durationMs,
    keystoneTimeMs: numberOrNull(summaryFight.keystoneTime),
    completed: true,
    keystoneBonus: summary.keystoneBonus ?? null,
    rating: numberOrNull(summary.rating),
    deathsTotal: metrics.deathsTotal,
    enemyForces: summary.enemyForces ?? { reached: null, required: null, percent: null },
    encounterID: numberOrNull(summaryFight.encounterID),
    startTime: numberOrNull(summaryFight.startTime),
    endTime: numberOrNull(summaryFight.endTime),
    keystoneAffixes: summaryFight.keystoneAffixes ?? [],
    averageItemLevel: numberOrNull(summaryFight.averageItemLevel),
    startedAt: Number.isFinite(candidate.reportStartTime + (summaryFight.startTime ?? 0))
      ? new Date(candidate.reportStartTime + (summaryFight.startTime ?? 0)).toISOString()
      : null,
  };

  return {
    reportCode: candidate.code,
    canonicalUrl: `https://www.warcraftlogs.com/reports/${candidate.code}?fight=${candidate.fightID}`,
    capturedAt,
    source: 'mcp',
    season: template?.season ?? null,
    patch: template?.patch ?? null,
    contentType: 'mythicplus',
    buildContext: 'mythic_plus',
    fightID: candidate.fightID,
    report: {
      owner: candidate.owner?.name ?? null,
      title: candidate.title ?? null,
      startTime: candidate.reportStartTime ?? null,
      endTime: candidate.reportEndTime ?? null,
      zone: candidate.zone ?? null,
      visibility: candidate.visibility ?? null,
    },
    sourceReports: [candidate.code],
    fight,
    players,
    metrics,
    rankings: rankingBlock(candidate, capturedAt),
    playerMetrics,
    focus: { tracked: candidate.matchedCharacters ?? [] },
    qualityFlags,
  };
}

function main() {
  if (!existsSync(inputPath)) throw new Error(`Manifest introuvable: ${inputPath}`);
  const input = JSON.parse(readFileSync(inputPath, 'utf8'));
  if (input.scanHealthy !== true) throw new Error('Le contrôle des personnages n’est pas complet.');
  const created = [];
  const updatedRankings = [];
  const capturedAt = input.generatedAt ?? new Date().toISOString();
  for (const candidate of input.candidates ?? []) {
    if (candidate.summary?.completed !== true || candidate.summary?.contentType !== 'mythicplus') continue;
    const filename = `${candidate.code}-fight-${candidate.fightID}.json`;
    const path = join(reportsRoot, filename);
    if (candidate.refreshRankingsOnly === true) {
      if (!existsSync(path)) continue;
      const existing = JSON.parse(readFileSync(path, 'utf8'));
      const report = mergeRefreshedRankings(existing, candidate, capturedAt);
      const temporary = `${path}.tmp`;
      writeFileSync(temporary, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
      renameSync(temporary, path);
      updatedRankings.push(filename);
      continue;
    }
    if (existsSync(path) && !forceOverwrite) continue;
    const report = makeReport(candidate, capturedAt);
    const temporary = `${path}.tmp`;
    writeFileSync(temporary, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
    renameSync(temporary, path);
    created.push(filename);
  }
  process.stdout.write(JSON.stringify({ created, updatedRankings }));
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
