(function () {
  const state = document.querySelector('#state');
  const message = document.querySelector('#message');
  const list = document.querySelector('#applicants');
  const workerUrl = 'http://127.0.0.1:28777/v1/applicants/snapshot';
  const latestUrl = 'http://127.0.0.1:28777/v1/applicants/latest';
  function setState(value, text) { state.className = 'state ' + value; state.textContent = text || value; }
  function fmt(value) { const n = Number(value); return Number.isFinite(n) ? n.toFixed(n % 1 ? 1 : 0) : String(value); }
  function render(snapshot) {
    const results = Array.isArray(snapshot && snapshot.results) ? snapshot.results : [];
    setState(snapshot && snapshot.status || 'idle');
    message.textContent = results.length + ' candidature(s).';
    list.replaceChildren.apply(list, results.map(function (entry) {
      const applicant = entry.applicant || entry;
      const mplus = (entry.data && entry.data.mplus) || {};
      const details = [];
      if (mplus.score != null) details.push('score ' + fmt(mplus.score));
      if (mplus.averageParse != null) details.push('parse moyen ' + fmt(mplus.averageParse) + '%');
      else if (mplus.parsePercent != null) details.push('parse ' + fmt(mplus.parsePercent) + '%');
      if (mplus.keyPercentile != null) details.push('clé ' + fmt(mplus.keyPercentile) + '%');
      const el = document.createElement('div'); el.className = 'applicant';
      el.textContent = (applicant.name || 'Inconnu') + ' — ' + (applicant.realm || 'royaume inconnu') + (details.length ? ' · ' + details.join(' · ') : '');
      return el;
    }));
  }
  async function poll() { try { const r = await fetch(latestUrl, { cache: 'no-store' }); if (!r.ok) throw Error(); render(await r.json()); } catch (_) { setState('offline'); message.textContent = 'Worker local indisponible.'; } setTimeout(poll, 1500); }
  function parseUpdate(update) {
    let value = update && update.info && update.info.game_info && update.info.game_info.group_applicants;
    if (typeof value === 'string') { try { value = JSON.parse(value); } catch (_) { return []; } }
    return value && typeof value === 'object' ? Object.keys(value).map(function (key) { const a = value[key] || {}; a.name = a.name || a.player_name || key; return a; }) : [];
  }
  function attach() {
    if (!window.overwolf || !overwolf.games || !overwolf.games.events) return;
    const events = overwolf.games.events;
    const onUpdate = function (update) {
      const applicants = parseUpdate(update);
      fetch(workerUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ applicants: applicants }) }).catch(function () {});
    };
    events.onInfoUpdates2.addListener(onUpdate);
    events.setRequiredFeatures(['game_info'], function (result) { if (result && result.success === false) setState('offline'); });
  }
  attach(); poll();
}());
