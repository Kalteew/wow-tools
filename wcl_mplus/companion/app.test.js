const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeApplicant, parseGroupApplicantsUpdate, diffApplicants, createCompanion, attachOverwolf } = require('./app');

test('normalizes Overwolf applicant fields and ignores terminal statuses', () => {
  const previous = new Map([['old', {}]]);
  const result = diffApplicants(previous, [{ applicantId: 'new', characterName: 'Azaelle', realmName: 'Hyjal', status: 'ACTIVE' }, { id: 'done', name: 'Done', status: 'invited' }]);
  assert.deepEqual(result.map(({ raw, ...applicant }) => applicant), [{ applicant_id: 'new', name: 'Azaelle', realm: 'Hyjal', region: 'EU', status: 'active', role: null, classId: null, itemLevel: null, rating: null }]);
  assert.equal(normalizeApplicant({ id: 'x' }).applicant_id, 'x');
});

test('posts only new applicant ids', async () => {
  const calls = [];
  const companion = createCompanion({ workerUrl: 'http://127.0.0.1:9999/v1/applicants/snapshot', fetchImpl: async (_url, options) => { calls.push(JSON.parse(options.body)); return { ok: true, json: async () => ({ ok: true }) }; } });
  await companion.onGroupApplicants([{ id: '1', name: 'One', status: 'active' }]);
  await companion.onGroupApplicants([{ id: '1', name: 'One', status: 'active' }, { id: '2', name: 'Two', status: 'active' }]);
  assert.deepEqual(calls.map(call => call.applicants.map(applicant => applicant.applicant_id)), [['1'], ['1', '2']]);
  assert.equal(calls[0].applicants[0].raw, undefined);
  assert.deepEqual(calls[1].newApplicants.map(applicant => applicant.applicant_id), ['2']);
});

test('parses the native Overwolf group_applicants payload', () => {
  const payload = JSON.stringify({ Noupak: { player_name: 'Noupak', server_name: "Drak'thul", applicant_id: '1', application_status: '1', rating: '2037' } });
  const applicants = parseGroupApplicantsUpdate({ info: { game_info: { group_applicants: payload } } });
  assert.deepEqual(applicants, [{ player_name: 'Noupak', server_name: "Drak'thul", applicant_id: '1', application_status: '1', rating: '2037' }]);
  assert.equal(normalizeApplicant(applicants[0]).status, 'active');
});

test('subscribes to Overwolf info updates after registering game_info', async () => {
  const listeners = new Set();
  const calls = [];
  const overwolf = { games: { events: {
    onInfoUpdates2: { addListener: listener => listeners.add(listener), removeListener: listener => listeners.delete(listener) },
    setRequiredFeatures: (features, callback) => { calls.push(features); callback({ success: true }); },
  } } };
  const posts = [];
  const companion = createCompanion({ fetchImpl: async (_url, options) => { posts.push(JSON.parse(options.body)); return { ok: true, json: async () => ({ status: 'ready' }) }; } });
  const connection = await attachOverwolf(overwolf, { companion });
  assert.deepEqual(calls, [['game_info']]);
  [...listeners][0]({ info: { game_info: { group_applicants: JSON.stringify({ One: { player_name: 'One', server_name: 'Hyjal', applicant_id: '7', application_status: 1 } }) } } });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(posts[0].applicants[0].name, 'One');
  connection.stop();
  assert.equal(listeners.size, 0);
});
