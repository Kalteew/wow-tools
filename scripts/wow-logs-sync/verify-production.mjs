import { readFile } from 'node:fs/promises';
import path from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((items, value, index, all) => {
    if (value.startsWith('--')) items.push([value.slice(2), all[index + 1]]);
    return items;
  }, []),
);

const numberOrNull = (value) =>
  value === null || value === undefined || value === ''
    ? null
    : Number.isFinite(Number(value))
      ? Number(value)
      : null;

async function main() {
  const candidateInput = JSON.parse(await readFile(args.candidates, 'utf8'));
  const candidates = Array.isArray(candidateInput) ? candidateInput : candidateInput.candidates;
  if (!Array.isArray(candidates)) throw new Error('Candidate file has no array.');
  const response = await fetch('https://wow.erenor.fr/data/kpis.json', {
    headers: { 'cache-control': 'no-cache' },
  });
  if (!response.ok) throw new Error(`Production KPI endpoint returned HTTP ${response.status}.`);
  const data = await response.json();
  if (!Array.isArray(data.runs)) throw new Error('Production KPI data has no runs array.');

  const runsById = new Set(data.runs.map((run) => run.id));
  const fingerprints = new Set(data.runs.map((run) => run.fingerprint).filter(Boolean));
  let matchedById = 0;
  let matchedByFingerprint = 0;
  const missing = [];

  for (const candidate of candidates) {
    const id = `${candidate.code}-${candidate.fightID}`;
    if (runsById.has(id)) {
      matchedById += 1;
      continue;
    }

    const reportPath = path.join(
      args['reports-root'],
      `${candidate.code}-fight-${candidate.fightID}.json`,
    );
    const report = JSON.parse(await readFile(reportPath, 'utf8'));
    const fight = report.fight ?? {};
    const fingerprint = [
      report.capturedAt ?? null,
      fight.dungeon ?? 'Donjon non renseigné',
      numberOrNull(fight.keyLevel),
      numberOrNull(fight.durationMs),
      numberOrNull(fight.rating),
      fight.enemyForces?.reached ?? null,
    ].join('|');
    if (fingerprints.has(fingerprint)) matchedByFingerprint += 1;
    else missing.push(id);
  }

  process.stdout.write(
    JSON.stringify({
      productionRuns: data.runs.length,
      checked: candidates.length,
      matchedById,
      matchedByFingerprint,
      missing,
    }),
  );
  if (missing.length) process.exitCode = 1;
}

main().catch((error) => {
  process.stdout.write(JSON.stringify({ error: String(error?.message ?? error) }));
  process.exitCode = 1;
});
