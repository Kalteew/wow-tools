import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const assembler = fileURLToPath(new URL('./assemble-report.mjs', import.meta.url));

async function assemble(candidate, existingReport = null) {
  const tempRoot = await mkdtemp(join(os.tmpdir(), 'wow-logs-ranking-'));
  const reportsRoot = join(tempRoot, 'reports');
  const inputPath = join(tempRoot, 'manifest.json');
  await mkdir(reportsRoot);

  try {
    if (existingReport) {
      await writeFile(join(reportsRoot, 'TestReportCode-fight-1.json'), JSON.stringify(existingReport));
    }
    await writeFile(inputPath, JSON.stringify({ generatedAt: '2026-10-03T00:00:00Z', scanHealthy: true, candidates: [candidate] }));
    const result = spawnSync(process.execPath, [assembler, '--input', inputPath, '--reports-root', reportsRoot], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    const report = JSON.parse(await readFile(join(reportsRoot, 'TestReportCode-fight-1.json'), 'utf8'));
    return report;
  } finally {
    await rm(tempRoot, { recursive: true, force: true });
  }
}

function candidate(rankings) {
  return {
    code: 'TestReportCode',
    fightID: 1,
    reportStartTime: Date.parse('2026-10-02T10:00:00Z'),
    reportEndTime: Date.parse('2026-10-02T10:10:00Z'),
    matchedCharacters: ['Azåelle'],
    summary: {
      completed: true,
      contentType: 'mythicplus',
      dungeon: 'Test Dungeon',
      keyLevel: 12,
      durationMs: 60_000,
      rating: 400,
      enemyForces: { reached: 100, required: 100, percent: 100 },
      players: [{ id: 1, name: 'Azåelle', class: 'DemonHunter', specs: ['Havoc'], itemLevels: [330], dps: 100_000 }],
      fight: { startTime: 0, endTime: 60_000, keystoneTime: 60_000, encounterID: 1, keystoneAffixes: [] },
    },
    rankings,
    playerAnalysis: {},
  };
}

test('keeps WCL Key % when totalParses is absent and the raw row carries bracketPercent', async () => {
  const report = await assemble(candidate({
    dps: { rankings: { rows: [{ playerName: 'Azaelle', raw: { bracketPercent: 84 } }], population: { totalParses: null } } },
    hps: { rankings: { rows: [], population: { totalParses: null } } },
    playerscore: { rankings: { rows: [], population: { totalParses: null } } },
  }));
  assert.equal(report.rankings.values.Azåelle.keyPercent, 84);
  assert.equal(report.rankings.values.Azåelle.parsePercent, null);
  assert.equal(report.rankings.values.Azåelle.keyPercentSource, 'mcp.reportRankings.dps');
  assert.equal(report.qualityFlags.some((flag) => flag.code === 'RANKINGS_UNAVAILABLE'), false);
});

test('does not treat WCL no-sample placeholder zero as a real Key %', async () => {
  const report = await assemble(candidate({
    dps: { rankings: { rows: [], population: { totalParses: null } } },
    hps: { rankings: { rows: [], population: { totalParses: null } } },
    playerscore: { rankings: { rows: [{ playerName: 'Azåelle', keyPercent: 0, totalParses: 0, rank: '-' }], population: { totalParses: 0 } } },
  }));
  assert.equal(report.rankings.values.Azåelle.keyPercent, null);
  assert.equal(report.rankings.values.Azåelle.keyPercentRaw, 0);
  assert.equal(report.rankings.values.Azåelle.keyPercentStatus, 'pending');
  assert.equal(report.rankings.values.Azåelle.keyPercentSource, 'mcp.reportRankings.pending');
  assert.equal(report.rankings.reportSpecific.byMetric.playerscore.values.Azåelle.keyPercent, null);
  assert.equal(report.qualityFlags.some((flag) => flag.code === 'RANKINGS_PENDING'), true);
  assert.equal(report.qualityFlags.some((flag) => flag.code === 'RANKINGS_UNAVAILABLE'), false);
});

test('refreshes pending Key % in place while preserving unrelated report data', async () => {
  const oldCandidate = candidate({
    dps: { rankings: { rows: [{ playerName: 'Azåelle', keyPercent: 0, totalParses: 0, rank: '-' }], population: { totalParses: 0 } } },
    hps: { rankings: { rows: [], population: { totalParses: null } } },
    playerscore: { rankings: { rows: [], population: { totalParses: null } } },
  });
  const oldReport = await assemble(oldCandidate);
  oldReport.customNote = 'preserve';
  oldReport.rankings.reportSpecific.byMetric.hps.values.OtherPlayer = { keyPercent: 61 };

  const refreshed = candidate({
    dps: { rankings: { rows: [{ playerName: 'Azåelle', bracketPercent: 82, totalParses: 190, rank: '82' }], population: { totalParses: 190 } } },
    hps: { rankings: { rows: [], population: { totalParses: null } } },
    playerscore: { rankings: { rows: [], population: { totalParses: null } } },
  });
  refreshed.refreshRankingsOnly = true;
  refreshed.refreshCharacters = ['Azåelle'];

  const report = await assemble(refreshed, oldReport);
  assert.equal(report.rankings.values.Azåelle.keyPercent, 82);
  assert.equal(report.rankings.values.Azåelle.keyPercentStatus, 'available');
  assert.equal(report.customNote, 'preserve');
  assert.deepEqual(report.rankings.reportSpecific.byMetric.hps.values.OtherPlayer, { keyPercent: 61 });
  assert.equal(report.qualityFlags.some((flag) => flag.code === 'RANKINGS_PENDING'), false);
});

test('refreshing HPS rankings does not overwrite existing DPS rankings', async () => {
  const initial = await assemble(candidate({
    dps: { rankings: { rows: [{ playerName: 'Azåelle', parsePercent: 71, keyPercent: 74, totalParses: 100 }], population: { totalParses: 100 } } },
    hps: { rankings: { rows: [{ playerName: 'Azåelle', parsePercent: 62, keyPercent: 66, totalParses: 80 }], population: { totalParses: 80 } } },
    playerscore: { rankings: { rows: [], population: { totalParses: null } } },
  }));
  const refreshed = candidate({
    hps: { rankings: { rows: [{ playerName: 'Azåelle', parsePercent: 85, keyPercent: 89, totalParses: 120 }], population: { totalParses: 120 } } },
  });
  refreshed.refreshRankingsOnly = true;
  refreshed.refreshCharacters = ['Azåelle'];
  refreshed.refreshCharactersByMetric = { hps: ['Azåelle'] };

  const report = await assemble(refreshed, initial);
  assert.equal(report.rankings.values.Azåelle.parsePercent, 71);
  assert.equal(report.rankings.values.Azåelle.keyPercent, 74);
  assert.equal(report.rankings.reportSpecific.byMetric.hps.values.Azåelle.parsePercent, 85);
  assert.equal(report.rankings.reportSpecific.byMetric.hps.values.Azåelle.keyPercent, 89);
});
