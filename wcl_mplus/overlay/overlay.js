const state = document.querySelector('#state');
const message = document.querySelector('#message');
const list = document.querySelector('#applicants');
function render(status, text, applicants = []) {
  state.className = `state ${status}`; state.textContent = status;
  message.textContent = text;
  list.replaceChildren(...applicants.map(renderApplicant));
}

function renderApplicant(entry) {
  const applicant = entry.applicant ?? entry;
  const data = entry.data ?? {};
  const mplus = data.mplus ?? data.character?.mplus ?? {};
  const el = document.createElement('div');
  el.className = `applicant ${entry.status || ''}`;
  const details = [];
  if (mplus.score !== null && mplus.score !== undefined) details.push(`score ${formatNumber(mplus.score)}`);
  if (mplus.averageParse !== null && mplus.averageParse !== undefined) details.push(`parse moyen ${formatNumber(mplus.averageParse)}%`);
  else if (mplus.parsePercent !== null && mplus.parsePercent !== undefined) details.push(`parse ${formatNumber(mplus.parsePercent)}%`);
  if (mplus.keyPercentile !== null && mplus.keyPercentile !== undefined) details.push(`clé ${formatNumber(mplus.keyPercentile)}%`);
  const suffix = details.length ? ` · ${details.join(' · ')}` : ` · ${entry.status || 'inconnu'}`;
  el.textContent = `${applicant.name || 'Inconnu'} — ${applicant.realm || 'royaume inconnu'}${suffix}`;
  return el;
}

function formatNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number.toFixed(number % 1 ? 1 : 0) : String(value);
}

function renderSnapshot(snapshot) {
  const results = Array.isArray(snapshot?.results) ? snapshot.results : [];
  const status = snapshot?.status || (results.length ? 'ready' : 'idle');
  const text = status === 'ready'
    ? `${results.length} candidature(s).`
    : status === 'loading'
      ? 'Récupération des données WCL…'
      : status === 'partial'
        ? 'Certaines données WCL sont indisponibles.'
        : 'Aucune candidature.';
  render(status, text, results);
}

function connectWorker({ url = 'http://127.0.0.1:28777/v1/applicants/latest', fetchImpl = globalThis.fetch, intervalMs = 1500 } = {}) {
  let stopped = false;
  let timer;
  const poll = async () => {
    try {
      const response = await fetchImpl(url, { cache: 'no-store' });
      if (!response.ok) throw new Error(`worker HTTP ${response.status}`);
      renderSnapshot(await response.json());
    } catch {
      render('offline', 'Worker local indisponible.', []);
    } finally {
      if (!stopped) timer = setTimeout(poll, intervalMs);
    }
  };
  void poll();
  return () => { stopped = true; clearTimeout(timer); };
}

function simulate() { try { const applicants = JSON.parse(document.querySelector('#json').value); render('ready', `${applicants.length} candidature(s) simulée(s).`, applicants); } catch { render('error', 'JSON invalide.'); } }
document.querySelector('#simulate').addEventListener('click', simulate);
render('loading', 'Chargement des candidatures…');
const workerParam = new URLSearchParams(window.location.search).get('worker');
const stopWorker = connectWorker({ url: workerParam || undefined });
window.wclMplusOverlay = { render, renderSnapshot, connectWorker, stopWorker };
