import fs from 'node:fs';
import path from 'node:path';

const root = 'C:/Users/Yaya/source/tools/wow-tools';
const dataDir = path.join(root, 'logs', 'comparisons', 'ragefire-position');
const outputFile = path.join(dataDir, 'analysis.json');
const slugs = ['den-15', 'kings-rest-12', 'temple-15', 'murder-row-15', 'murder-row-16'];

function read(file) {
  return JSON.parse(fs.readFileSync(path.join(dataDir, file), 'utf8').replace(/^\uFEFF/, ''));
}

function eventsFor(slug, alias) {
  const json = read(`${slug}-${alias}.json`);
  return json.reportData?.report?.[alias]?.data ?? [];
}

function targetKey(event) {
  return `${event.targetID}:${event.targetInstance ?? ''}`;
}

function hasBuff(event, guid) {
  return typeof event.buffs === 'string' && event.buffs.split('.').includes(String(guid));
}

function groupByTime(events, tolerance = 10) {
  const sorted = [...events].sort((a, b) => a.timestamp - b.timestamp);
  const groups = [];
  for (const event of sorted) {
    const group = groups.at(-1);
    if (!group || event.timestamp - group.lastTimestamp > tolerance) {
      groups.push({ startTime: event.timestamp, lastTimestamp: event.timestamp, events: [event] });
    } else {
      group.lastTimestamp = event.timestamp;
      group.events.push(event);
    }
  }
  return groups;
}

function deathBefore(deaths, event, timestamp) {
  return deaths.some((death) => {
    if (death.timestamp > timestamp || death.targetID !== event.targetID) return false;
    if (death.targetInstance === undefined || event.targetInstance === undefined) return true;
    return death.targetInstance === event.targetInstance;
  });
}

function analyzeRun(slug) {
  const pulls = read(`${slug}-pulls.json`);
  const buffs = read(`${slug}-buffs.json`);
  const deaths = eventsFor(slug, 'deaths');
  const ragefireEvents = eventsFor(slug, 'ragefire');
  const auraEvents = ['a258922', 'a427908', 'a427910', 'a427911', 'a258921', 'a427904', 'a427905', 'a427906']
    .flatMap((alias) => eventsFor(slug, alias));
  const fightEnd = pulls.fight.endTime;
  const ragefireBands = (buffs.data?.data?.auras ?? [])
    .filter((aura) => aura.name === 'Ragefire')
    .flatMap((aura) => aura.bands.map((band) => ({ ...band, ragefireGuid: aura.guid })))
    .sort((a, b) => a.endTime - b.endTime);

  const records = ragefireBands.map((band) => {
    const terminal = band.endTime >= fightEnd - 20;
    const damageEvents = ragefireEvents.filter((event) => Math.abs(event.timestamp - band.endTime) <= 100);
    const damageTargets = new Set(damageEvents.map(targetKey));
    const taggedAura = auraEvents.filter((event) => hasBuff(event, band.ragefireGuid));
    const recentTaggedAura = taggedAura.filter((event) => event.timestamp >= band.endTime - 1500 && event.timestamp <= band.endTime + 50);
    const recentAura = auraEvents.filter((event) => event.timestamp >= band.endTime - 1500 && event.timestamp <= band.endTime + 50);
    const latestAuraTimestamp = recentAura.length ? Math.max(...recentAura.map((event) => event.timestamp)) : null;
    const latestAuraEvents = latestAuraTimestamp === null
      ? []
      : recentAura.filter((event) => Math.abs(event.timestamp - latestAuraTimestamp) <= 10);
    const latestTaggedAuraEvents = latestAuraEvents.filter((event) => hasBuff(event, band.ragefireGuid));
    const candidateTargets = new Set(latestAuraEvents.map(targetKey));
    const liveCandidateTargets = new Set(latestAuraEvents
      .filter((event) => !deathBefore(deaths, event, band.endTime))
      .map(targetKey));
    const missingTargets = [...liveCandidateTargets].filter((key) => !damageTargets.has(key));
    const allCandidatesDead = candidateTargets.size > 0 && liveCandidateTargets.size === 0;

    const activePull = pulls.pulls.find((pull) => band.endTime >= pull.startTime && band.endTime <= pull.endTime);
    let classification = 'full_against_recent_aura_targets';
    if (terminal) classification = 'fight_end_or_truncated';
    else if (damageEvents.length === 0 && !activePull) classification = 'zero_outside_active_pull_normal';
    else if (damageEvents.length === 0 && allCandidatesDead) classification = 'zero_inside_pull_all_recent_targets_dead';
    else if (damageEvents.length === 0 && liveCandidateTargets.size > 0) classification = 'zero_inside_pull_with_live_recent_aura_targets_possible_range_or_pool_issue';
    else if (damageEvents.length === 0) classification = 'zero_inside_pull_without_recent_aura_evidence';
    else if (missingTargets.length > 0) classification = 'partial_with_live_recent_aura_targets_possible_range_or_target_state';

    return {
      ragefireGuid: band.ragefireGuid,
      startTime: band.startTime,
      endTime: band.endTime,
      terminal,
      hitCount: damageEvents.length,
      damageTargetCount: damageTargets.size,
      activePullID: activePull?.id ?? null,
      activePullName: activePull?.name ?? null,
      recentTaggedAuraTargetCount: new Set(recentTaggedAura.map(targetKey)).size,
      recentAuraTimestamp: latestAuraTimestamp,
      recentAuraTargetCount: candidateTargets.size,
      liveRecentAuraTargetCount: liveCandidateTargets.size,
      latestAuraCritCount: latestAuraEvents.filter((event) => event.hitType === 2).length,
      latestTaggedAuraCritCount: latestTaggedAuraEvents.filter((event) => event.hitType === 2).length,
      missingLiveTargets: missingTargets,
      classification,
    };
  });

  const usable = records.filter((record) => !record.terminal);
  const summary = {
    slug,
    fight: pulls.fight,
    ragefireBuffBands: records.length,
    truncatedBands: records.filter((record) => record.terminal).length,
    usableExplosions: usable.length,
    damageExplosions: usable.filter((record) => record.hitCount > 0).length,
    zeroExplosions: usable.filter((record) => record.hitCount === 0).length,
    zeroOutsideActivePull: usable.filter((record) => record.classification === 'zero_outside_active_pull_normal').length,
    zeroInsidePullWithoutRecentTargets: usable.filter((record) => record.classification === 'zero_inside_pull_without_recent_aura_evidence' || record.classification === 'zero_inside_pull_all_recent_targets_dead').length,
    zeroWithLiveRecentAuraTargets: usable.filter((record) => record.classification === 'zero_inside_pull_with_live_recent_aura_targets_possible_range_or_pool_issue').length,
    zeroWithLiveRecentAuraAndCrit: usable.filter((record) => record.classification === 'zero_inside_pull_with_live_recent_aura_targets_possible_range_or_pool_issue' && record.latestAuraCritCount > 0).length,
    zeroWithTaggedRecentAuraAndCrit: usable.filter((record) => record.classification === 'zero_inside_pull_with_live_recent_aura_targets_possible_range_or_pool_issue' && record.latestTaggedAuraCritCount > 0).length,
    partialExplosionsWithMissingLiveTargets: usable.filter((record) => record.classification === 'partial_with_live_recent_aura_targets_possible_range_or_target_state').length,
    likelyPositionCandidates: usable.filter((record) => record.classification.includes('possible_range_or')).length,
  };
  return { summary, records };
}

const runs = slugs.map(analyzeRun);
fs.writeFileSync(outputFile, JSON.stringify({ capturedAt: new Date().toISOString(), method: {
  explosionSource: 'Ragefire buff-band expirations from Warcraft Logs Buffs table',
  damageSource: 'Ragefire DamageDone events',
  liveTargetProxy: 'targets hit by the latest Immolation Aura damage event near the Ragefire expiration, excluding targets already dead; the same-buff-tagged target count is retained as an audit field',
  limitation: 'Warcraft Logs exposes damage events but not actor coordinates here; a live recent Aura target missing from Ragefire is a positioning/target-state candidate, not definitive proof of distance.',
}, runs }, null, 2));
console.log(JSON.stringify(runs.map((run) => run.summary), null, 2));
