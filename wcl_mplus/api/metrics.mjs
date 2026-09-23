import { WclValidationError } from './errors.mjs';

export function extractMythicPlusMetrics(payload) {
  if (!payload || typeof payload !== 'object') throw new WclValidationError('A WCL M+ payload is required.');
  const source = payload.mythicPlusReport ?? payload.mythicPlus ?? payload.report ?? payload.rankings ?? payload;
  const scoreContainers = [source, source.rankings, source.scores, source.mythicPlusScores].filter(Boolean);
  const parseContainers = [source.throughputRankings, source.throughput, source.parseRankings, source.parsers].filter(Boolean);
  const parseValues = collectNumbers(parseContainers, ['parsePercent', 'damagePercentile', 'damagePercent', 'percentile', 'rankPercent']);
  const damagePercentile = first(scoreContainers, ['damagePercentile', 'damagePercent', 'throughputPercentile'])
    ?? (parseValues.length === 1 ? parseValues[0] : null);
  return {
    score: first(scoreContainers, ['score', 'rating', 'mythicPlusScore', 'points', 'playerScore']),
    keyPercentile: first(scoreContainers, ['keyPercentile', 'keyPercent', 'keyRankingPercent', 'scorePercentile']),
    damagePercentile,
    parsePercent: damagePercentile,
    averageParse: parseValues.length ? average(parseValues) : null,
  };
}

function first(sources, keys) {
  for (const source of sources) {
    if (!source || typeof source !== 'object') continue;
    for (const key of keys) if (source[key] !== undefined && source[key] !== null) return numberOrNull(source[key]);
  }
  return null;
}

function collectNumbers(values, keys) {
  const output = [];
  const visit = value => {
    if (Array.isArray(value)) return value.forEach(visit);
    if (!value || typeof value !== 'object') return;
    for (const key of keys) {
      const number = numberOrNull(value[key]);
      if (number !== null) output.push(number);
    }
    for (const nested of Object.values(value)) if (nested && typeof nested === 'object') visit(nested);
  };
  values.forEach(visit);
  return output;
}

function average(values) { return values.reduce((sum, value) => sum + value, 0) / values.length; }

function numberOrNull(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
