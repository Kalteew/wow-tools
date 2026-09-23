const APPLICATION_STATUS_NAMES = new Map([
  [0, 'unknown'],
  [1, 'active'],
  [2, 'invited'],
  [3, 'failed'],
  [4, 'cancelled'],
  [5, 'declined'],
  [6, 'declined_full'],
  [7, 'declined_delist'],
  [8, 'timedout'],
  [9, 'invited_declined'],
  [10, 'invite_accepted'],
]);

const TERMINAL_STATUSES = new Set([
  'declined', 'declined_full', 'declined_delist', 'invited', 'invited_declined',
  'invite_accepted', 'cancelled', 'canceled', 'failed', 'joined', 'removed', 'timedout',
]);

function normalizeStatus(value) {
  const numeric = Number(value);
  if (Number.isInteger(numeric) && APPLICATION_STATUS_NAMES.has(numeric)) return APPLICATION_STATUS_NAMES.get(numeric);
  const status = String(value ?? 'unknown').trim().toLowerCase().replace(/[ -]+/g, '_');
  return status === 'applied' ? 'active' : status;
}

function normalizeApplicant(raw = {}) {
  const applicantId = String(raw.applicant_id ?? raw.applicantId ?? raw.id ?? '').trim();
  return {
    applicant_id: applicantId,
    name: String(raw.name ?? raw.player_name ?? raw.character_name ?? raw.characterName ?? '').trim(),
    realm: String(raw.realm ?? raw.server_name ?? raw.realm_name ?? raw.realmName ?? '').trim(),
    region: String(raw.region ?? 'EU').trim().toUpperCase(),
    status: normalizeStatus(raw.application_status ?? raw.applicationStatus ?? raw.status),
    role: raw.role ?? null,
    classId: numberOrNull(raw.classId ?? raw.class),
    itemLevel: numberOrNull(raw.itemLevel ?? raw.item_level),
    rating: numberOrNull(raw.rating),
    raw,
  };
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function parseGroupApplicantsUpdate(update) {
  const rawValue = update?.info?.game_info?.group_applicants
    ?? update?.data?.group_applicants
    ?? update?.group_applicants
    ?? update;
  let value = rawValue;
  if (typeof value === 'string') {
    try { value = JSON.parse(value); } catch { return []; }
  }
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== 'object') return [];
  return Object.entries(value).map(([key, applicant]) => ({
    ...(applicant && typeof applicant === 'object' ? applicant : {}),
    player_name: applicant?.player_name ?? applicant?.name ?? key,
  }));
}

function publicApplicant(applicant) {
  const { raw, ...safe } = applicant;
  return safe;
}

function diffApplicants(previous, current) {
  const seen = new Set(previous.keys());
  return current.map(normalizeApplicant).filter(applicant => {
    if (!applicant.applicant_id || seen.has(applicant.applicant_id)) return false;
    return !TERMINAL_STATUSES.has(applicant.status);
  });
}

function createCompanion({ workerUrl = 'http://127.0.0.1:28777/v1/applicants/snapshot', fetchImpl = globalThis.fetch } = {}) {
  const applicants = new Map();
  let lastSnapshotKey = null;
  return {
    applicants,
    onGroupApplicants(rawApplicants = []) {
      const normalized = rawApplicants.map(normalizeApplicant).filter(applicant => applicant.applicant_id && !TERMINAL_STATUSES.has(applicant.status));
      const incoming = diffApplicants(applicants, normalized);
      const currentIds = new Set(normalized.map(applicant => applicant.applicant_id));
      for (const applicantId of applicants.keys()) if (!currentIds.has(applicantId)) applicants.delete(applicantId);
      for (const applicant of normalized) applicants.set(applicant.applicant_id, applicant);
      const current = [...applicants.values()].map(publicApplicant);
      const snapshotKey = JSON.stringify([...current].sort((left, right) => left.applicant_id.localeCompare(right.applicant_id)));
      if (snapshotKey === lastSnapshotKey) return Promise.resolve({ posted: 0, applicants: [], result: null });
      return fetchImpl(workerUrl, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ applicants: current, newApplicants: incoming.map(publicApplicant) }),
      })
        .then(response => { if (!response.ok) throw new Error(`worker HTTP ${response.status}`); return response.json(); })
        .then(result => {
          lastSnapshotKey = snapshotKey;
          return { posted: incoming.length, applicants: incoming, result };
        });
    },
    onInfoUpdate(update) { return this.onGroupApplicants(parseGroupApplicantsUpdate(update)); },
  };
}

async function setRequiredFeatures(events, features, gameId) {
  if (gameId !== undefined && gameId !== null) return events.setRequiredFeatures(gameId, features);
  return new Promise((resolve, reject) => {
    try {
      events.setRequiredFeatures(features, result => {
        if (result && result.success === false) reject(new Error(result.error || 'Overwolf feature registration failed'));
        else resolve(result);
      });
    } catch (error) { reject(error); }
  });
}

async function attachOverwolf(overwolf, { companion = createCompanion(), features = ['game_info'], gameId } = {}) {
  const events = overwolf?.games?.events;
  if (!events?.onInfoUpdates2 || typeof events.setRequiredFeatures !== 'function') throw new Error('Overwolf GEP events API is unavailable');
  const listener = update => { void companion.onInfoUpdate(update); };
  events.onInfoUpdates2.removeListener?.(listener);
  events.onInfoUpdates2.addListener(listener);
  try {
    await setRequiredFeatures(events, features, gameId);
  } catch (error) {
    events.onInfoUpdates2.removeListener?.(listener);
    throw error;
  }
  return { companion, stop() { events.onInfoUpdates2.removeListener?.(listener); } };
}

module.exports = {
  APPLICATION_STATUS_NAMES,
  TERMINAL_STATUSES,
  normalizeApplicant,
  parseGroupApplicantsUpdate,
  diffApplicants,
  createCompanion,
  attachOverwolf,
};
