'use strict';
/* global launcher */
// Renderer: draws the launcher and talks to the main process through window.launcher (preload.js).
const $ = (id) => document.getElementById(id);
const api = window.launcher;
const S = { config: {}, settings: {}, status: {}, feed: null, progress: null, notes: { incoming: [], recent: [] }, hero: [], heroIdx: 0, demo: null, game: null };

// ---------- helpers ----------
function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
function fmtDate(d) {
  // a bare YYYY-MM-DD is a calendar day, not UTC midnight (which shows as the day before west of Greenwich)
  const t = /^\d{4}-\d{2}-\d{2}$/.test(String(d)) ? new Date(d + 'T12:00:00') : new Date(d);
  return isNaN(t) ? '' : t.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}
function ago(d) {
  const s = (Date.now() - new Date(d).getTime()) / 1000;
  if (!isFinite(s)) return '';
  if (s < 3600) return `${Math.max(1, Math.round(s / 60))} min ago`;
  if (s < 86400) return `${Math.round(s / 3600)} h ago`;
  if (s < 86400 * 14) return `${Math.round(s / 86400)} days ago`;
  return fmtDate(d);
}
function fmtBytes(n) { if (!n) return '0 B'; const u = ['B', 'KB', 'MB', 'GB']; let i = 0; while (n >= 1024 && i < 3) { n /= 1024; i++; } return `${n.toFixed(i >= 2 ? 1 : 0)} ${u[i]}`; }
function fmtEta(s) { if (!isFinite(s) || s <= 0) return ''; if (s < 60) return `${Math.ceil(s)} s left`; if (s < 3600) return `${Math.ceil(s / 60)} min left`; return `${(s / 3600).toFixed(1)} h left`; }
// A picture from the feed, with fallbacks: each candidate is probed off-screen and the first that loads is shown, so a
// missing file never leaves a hole (the boxes have fixed sizes; nothing moves when a picture arrives).
const imgOk = new Map(); // src|installed -> url that loaded
function setBg(node, src) {
  const key = `${src}|${S.status.installed ? 1 : 0}`;
  const ticket = (node._bg = (node._bg || 0) + 1);
  const show = (url) => { if (node._bg === ticket) node.style.backgroundImage = `url("${url}")`; };
  if (imgOk.has(key)) return show(imgOk.get(key));
  const list = Feed.candidates(src, !!S.status.installed);
  let i = 0;
  const next = () => {
    if (i >= list.length) return;
    const url = list[i++];
    const im = new Image();
    im.onload = () => { imgOk.set(key, url); show(url); };
    im.onerror = next;
    im.src = url;
  };
  next();
}
function toast(title, msg, kind = '') {
  const t = el('div', 'toast ' + kind);
  t.append(el('b', null, title), el('span', null, msg));
  $('toasts').append(t);
  setTimeout(() => { t.style.transition = 'opacity .4s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 450); }, kind === 'err' ? 9000 : 4500);
}
async function call(name, ...args) {
  const r = await api[name](...args);
  if (!r.ok) { if (!r.cancelled) toast('Something went wrong', r.error, 'err'); else toast('Cancelled', 'Nothing was broken; press the button again to resume.'); return undefined; }
  return r.value;
}
function shortSubject(s) {
  // commit subjects here run long: lead with the first sentence (a colon is not a sentence end)
  const m = /^(.{20,200}?[.;])\s/.exec(s);
  if (m) return { head: m[1].replace(/;$/, ''), rest: s.slice(m[1].length).trim() };
  if (s.length <= 200) return { head: s, rest: '' };
  const cut = s.lastIndexOf(' ', 190);
  return { head: s.slice(0, cut > 80 ? cut : 190) + '…', rest: s.slice(cut > 80 ? cut : 190).trim() };
}

// ---------- channels ----------
function channelDot(ch) { const d = el('i', 'dot'); if (ch && ch.id !== 'stable') d.classList.add('preview'); return d; }
function renderChannels() {
  const ch = S.status.channel || {};
  $('channelName').textContent = (ch.name || '').toUpperCase();
  const btnDot = $('channelBtn').querySelector('.dot');
  btnDot.className = 'dot' + (ch.id && ch.id !== 'stable' ? ' preview' : '');
  const menu = $('channelMenu');
  menu.replaceChildren();
  const sel = $('setChannel');
  sel.replaceChildren();
  for (const c of S.status.channels || []) {
    const b = el('button', c.id === ch.id ? 'sel' : '');
    b.append(channelDot(c), el('b', null, c.name.toUpperCase()), el('small', null, c.description || c.branch));
    b.onclick = () => { menu.classList.remove('open'); setChannel(c.id); };
    menu.append(b);
    const o = el('option', null, `${c.name} — ${c.description || c.branch}`);
    o.value = c.id; if (c.id === ch.id) o.selected = true;
    sel.append(o);
  }
  $('setChannelNote').textContent = `Branch: ${ch.branch || ''}`;
}
async function setChannel(id) {
  if (id === (S.status.channel || {}).id) return;
  const r = await call('setSettings', { channel: id });
  if (!r) return;
  S.settings = r.settings; S.status = r.status;
  renderAll();
  if (S.status.installed) toast('Channel changed', `Press UPDATE to switch the game to ${S.status.channel.name}.`);
  refreshFeed(); checkUpdates(true);
}

// ---------- news ----------
function visibleNews() { return Feed.visibleNews(S.feed, (S.status.channel || {}).id); }
function renderNews() {
  const items = visibleNews();
  S.hero = items.filter((n) => n.hero);
  if (!S.hero.length) S.hero = items.slice(0, 3);
  if (S.heroIdx >= S.hero.length) S.heroIdx = 0;
  const dots = $('heroDots');
  dots.replaceChildren(...S.hero.map((n, i) => { const b = el('button'); b.title = n.title; b.setAttribute('aria-label', n.title); b.onclick = () => showHero(i, true); return b; }));
  showHero(S.heroIdx, false);
  const list = $('newsList');
  list.replaceChildren();
  for (const n of items) {
    const b = el('button', 'news-item');
    const th = el('div', 'thumb'); setBg(th, n.image);
    const pics = Feed.gallery(n).length;
    if (Feed.video(n)) th.append(el('span', 'play-badge'));
    else if (pics > 1) th.append(el('span', 'pics', `${pics} pictures`));
    const right = el('div');
    const m = el('div', 'm'); m.append(el('b', null, n.tag || 'NEWS'), el('span', null, fmtDate(n.date)));
    right.append(m, el('div', 't', n.title));
    b.append(th, right);
    b.onclick = () => openArticle(n);
    list.append(b);
  }
  if (!items.length) list.append(el('div', 'empty-state', 'No news yet.'));
  const links = $('links');
  links.replaceChildren(...((S.feed && S.feed.links) || []).map((l) => { const b = el('button', null, l.label); b.onclick = () => api.openExternal(l.url); return b; }));
  renderUpcoming();
  renderTrailerButton();
}
// ---------- trailers (feed.json items with "type": "video") ----------
function trailerUrl(n) { const v = Feed.video(n); return v ? Feed.videoCandidates(v.src, !!S.status.installed)[0] || null : null; }
function renderTrailerButton() {
  const list = Feed.trailers(S.feed, (S.status.channel || {}).id);
  const b = $('trailerBtn');
  b.hidden = !list.length;
  if (!list.length) return;
  const n = list.find((x) => trailerUrl(x)) || list[0];
  const v = Feed.video(n);
  const url = trailerUrl(n);
  $('trailerBtnText').textContent = url ? v.label + (v.duration ? `  ·  ${v.duration}` : '') : 'Trailer: after install';
  b.disabled = !url;
  b.title = url ? n.title : 'The trailer comes with the game files: it plays once the game is installed.';
  b.onclick = () => openPlayer(n);
}
function openPlayer(n) {
  const url = trailerUrl(n);
  if (!url) return;
  const bgv = $('bgVideo'); if (!bgv.paused) bgv.pause();
  const v = $('playerVideo');
  v.src = url; v.muted = false; v.currentTime = 0;
  const p = v.play(); if (p && p.catch) p.catch(() => {});
  $('playerTitle').textContent = n.title;
  $('player').hidden = false;
}
function closePlayer() {
  const v = $('playerVideo'); v.pause(); v.removeAttribute('src'); v.load();
  const bgv = $('bgVideo'); if (bgv.getAttribute('src') && $('bgVideo').classList.contains('show')) { const p = bgv.play(); if (p && p.catch) p.catch(() => {}); }
}
/** The hero background plays the slide's trailer muted (when it can play); other slides stop it. */
function heroVideo(n) {
  const bgv = $('bgVideo');
  const url = n && trailerUrl(n);
  if (!url || !$('player').hidden) {
    bgv.classList.remove('show'); bgv.pause();
    if (!url && bgv.getAttribute('src')) { bgv.removeAttribute('src'); bgv.load(); }
    return;
  }
  if (bgv.getAttribute('src') !== url) { bgv.src = url; }
  bgv.muted = true;
  const p = bgv.play();
  if (p && p.then) p.then(() => bgv.classList.add('show')).catch(() => bgv.classList.remove('show'));
}
// ---------- upcoming (feed.json "upcoming": proposals, no dates) ----------
function renderUpcoming() {
  const up = Feed.upcoming(S.feed, (S.status.channel || {}).id);
  $('upTitle').textContent = up.title;
  $('upNote').textContent = up.note;
  const list = $('upList');
  list.replaceChildren();
  up.items.forEach((it, i) => {
    const li = el('li', 'up-item');
    const head = el('div', 'up-head');
    head.append(el('span', 'up-n', String(i + 1).padStart(2, '0')));
    if (it.area) head.append(el('span', 'tag violet', it.area));
    head.append(el('span', 'up-state', 'Proposed'));
    li.append(head, el('h3', null, it.title));
    if (it.summary) li.append(el('p', null, it.summary));
    list.append(li);
  });
  if (!up.items.length) list.append(el('li', 'empty-state', 'Nothing proposed yet.'));
  $('upTeaser').hidden = !up.items.length;
  $('upTeaserText').textContent = up.items.length ? `${up.items.length} proposed change${up.items.length === 1 ? '' : 's'}: ${up.items[0].title}` : '';
  document.querySelector('.tab[data-view="upcoming"]').hidden = !up.items.length;
}
let heroTimer = null; let heroT0 = 0; const HERO_MS = 8000; let bgFlip = false;
function showHero(i, user) {
  if (!S.hero.length) return;
  S.heroIdx = (i + S.hero.length) % S.hero.length;
  const n = S.hero[S.heroIdx];
  const hero = $('hero');
  hero.classList.remove('swap'); void hero.offsetWidth; hero.classList.add('swap');
  $('heroTag').textContent = n.tag || 'NEWS';
  $('heroDate').textContent = fmtDate(n.date);
  $('heroTitle').textContent = n.title;
  $('heroSummary').textContent = n.summary || '';
  $('heroMore').onclick = () => openArticle(n);
  const vid = Feed.video(n);
  const vurl = vid && trailerUrl(n);
  $('heroWatch').hidden = !vid;
  if (vid) {
    $('heroWatchText').textContent = vurl ? vid.label : 'Trailer: after install';
    $('heroWatch').title = vid.duration ? `${n.title} (${vid.duration})` : n.title;
    $('heroWatch').disabled = !vurl;
    $('heroWatch').onclick = () => openPlayer(n);
  }
  heroVideo(n);
  $('trailerBtn').classList.toggle('dup', !!vid); // the slide has its own button
  [...$('heroDots').children].forEach((d, k) => d.classList.toggle('on', k === S.heroIdx));
  // the item's pictures as a strip (fixed-size boxes; hidden when the item has one picture or none)
  const strip = $('heroStrip');
  const pics = Feed.gallery(n);
  strip.replaceChildren(...(pics.length > 1 ? pics.slice(0, 5) : []).map((g, k) => {
    const b = el('button', 'strip-thumb');
    b.title = g.caption || `Picture ${k + 1}`; b.setAttribute('aria-label', b.title);
    setBg(b, g.src);
    b.onclick = () => openArticle(n, k);
    return b;
  }));
  strip.classList.toggle('empty', pics.length < 2);
  if (pics.length > 5) { const more = el('button', 'strip-more', `+${pics.length - 5}`); more.setAttribute('aria-label', 'More pictures'); more.onclick = () => openArticle(n, 5); strip.append(more); }
  // crossfade the background
  bgFlip = !bgFlip;
  const a = $(bgFlip ? 'bgA' : 'bgB'); const b = $(bgFlip ? 'bgB' : 'bgA');
  setBg(a, n.image);
  a.classList.add('show'); b.classList.remove('show');
  heroT0 = performance.now();
  if (user) heroT0 += 4000; // linger a little after a click
}
function heroTick(now) {
  if (S.hero.length > 1 && !document.hidden && $('article').hidden && $('player').hidden) {
    const t = (now - heroT0) / (Feed.video(S.hero[S.heroIdx]) ? HERO_MS * 2.5 : HERO_MS);
    $('heroTimer').style.height = `${Math.max(0, Math.min(1, t)) * 100}%`;
    if (t >= 1) showHero(S.heroIdx + 1, false);
  }
  requestAnimationFrame(heroTick);
}
const ART = { pics: [], idx: 0 };
function showArticlePic(i) {
  if (!ART.pics.length) return;
  ART.idx = (i + ART.pics.length) % ART.pics.length;
  const g = ART.pics[ART.idx];
  setBg($('articleImg'), g.src);
  const many = ART.pics.length > 1;
  $('articleCaption').textContent = g.caption ? (many ? `${ART.idx + 1} / ${ART.pics.length}  ·  ${g.caption}` : g.caption) : (many ? `${ART.idx + 1} / ${ART.pics.length}` : '');
  [...$('articleStrip').children].forEach((b, k) => { b.classList.toggle('on', k === ART.idx); b.setAttribute('aria-current', k === ART.idx ? 'true' : 'false'); });
}
function openArticle(n, picIdx) {
  ART.pics = Feed.gallery(n);
  if (!ART.pics.length) ART.pics = [{ src: n.image, caption: '' }];
  const many = ART.pics.length > 1;
  $('articlePrev').hidden = $('articleNext').hidden = $('articleStrip').hidden = !many;
  $('articleStrip').replaceChildren(...(many ? ART.pics : []).map((g, k) => {
    const b = el('button', 'strip-thumb');
    b.title = g.caption || `Picture ${k + 1}`; b.setAttribute('aria-label', b.title);
    setBg(b, g.src);
    b.onclick = () => showArticlePic(k);
    return b;
  }));
  $('articleImg').style.backgroundImage = '';
  showArticlePic(picIdx || 0);
  $('articleTag').textContent = n.tag || 'NEWS';
  $('articleDate').textContent = fmtDate(n.date);
  $('articleTitle').textContent = n.title;
  const body = $('articleText'); body.replaceChildren();
  for (const p of String(n.body || n.summary || '').split(/\n{2,}/)) body.append(el('p', null, p));
  const vid = Feed.video(n);
  if (vid) {
    const url = trailerUrl(n);
    const b = el('button', 'ghost watch', url ? vid.label : 'The trailer plays once the game is installed');
    b.disabled = !url;
    b.onclick = () => { $('article').hidden = true; openPlayer(n); };
    body.append(b);
  }
  $('article').hidden = false;
  $('article').querySelector('.article-body').scrollTop = 0;
  $('article').querySelector('.modal-x').focus();
}

// ---------- patch notes ----------
async function refreshNotes() {
  if (S.demo) return renderNotes();
  const r = await api.patchNotes();
  if (r.ok) S.notes = r.value;
  renderNotes();
}
function commitRow(c) {
  const row = el('div', 'commit');
  const d = el('div', 'c-date', fmtDate(c.date)); d.append(el('code', null, c.sha.slice(0, 7)));
  const t = el('div', 'c-text');
  const { head, rest } = shortSubject(c.subject);
  t.append(el('span', null, head));
  if (rest) {
    const more = el('button', 'more', 'MORE');
    const restEl = el('span', 'c-rest', ' ' + rest); restEl.hidden = true;
    more.onclick = () => { restEl.hidden = !restEl.hidden; more.textContent = restEl.hidden ? 'MORE' : 'LESS'; };
    t.append(restEl, more);
  }
  row.append(d, t);
  return row;
}
function renderNotes() {
  const { incoming, recent } = S.notes;
  const box = $('notesScroll'); box.replaceChildren();
  const ch = S.status.channel || {};
  $('notesSub').textContent = S.status.installed ? `${ch.name} channel · branch ${ch.branch} · straight from the commit history` : 'Install the game to see what changed in each build.';
  if (incoming.length) {
    const g = el('div', 'notes-group'); g.append(el('h3', null, `In the next update (${incoming.length})`));
    incoming.forEach((c) => g.append(commitRow(c))); box.append(g);
  }
  if (recent.length) {
    const g = el('div', 'notes-group recent'); g.append(el('h3', null, 'Installed'));
    recent.forEach((c) => g.append(commitRow(c))); box.append(g);
  }
  if (!incoming.length && !recent.length) box.append(el('div', 'empty-state', S.status.installed ? 'No history found.' : 'Nothing here until the game is installed.'));
  // the mini list on the home page
  const mini = $('miniNotes'); mini.replaceChildren();
  $('miniNotesTitle').textContent = incoming.length ? 'Coming in this update' : 'Patch notes';
  const top = (incoming.length ? incoming.map((c) => [c, true]) : recent.map((c) => [c, false])).slice(0, 6);
  for (const [c, isNew] of top) {
    const li = el('li', isNew ? 'new' : '');
    li.append(el('span', null, shortSubject(c.subject).head), el('span', 'when', ago(c.date)));
    mini.append(li);
  }
  if (!top.length) mini.append(el('li', 'empty', S.status.installed ? 'You are up to date.' : 'Install to see the latest changes.'));
}

// ---------- status, progress, the big button ----------
function readyToPlay(st) {
  return st.installed && st.onChannel && !st.updateAvailable && !st.needsImport && !st.needsFiles && st.engineReady;
}
function primaryAction() {
  const st = S.status;
  // T-289: the update check that runs when the launcher opens no longer blocks PLAY (it only reads from GitHub)
  const working = (st.busy && st.busy !== 'check') || (S.progress && !st.busy);
  if (working || (st.busy === 'check' && !readyToPlay(st))) {
    const words = { check: 'CHECKING', install: 'INSTALLING', update: 'UPDATING', repair: 'REPAIRING', prepare: 'PREPARING' };
    return { text: words[st.busy] || 'WORKING', sub: st.busy === 'check' ? 'one moment' : 'keep the launcher open', cls: 'busy', disabled: true };
  }
  if (S.game) {
    if (S.game.state === 'launching') return { text: 'STARTING', sub: 'one moment', cls: 'busy', disabled: true };
    if (S.game.state === 'starting') return { text: 'STARTING', sub: S.game.safe ? 'safe mode · the window is opening' : 'the window is opening', cls: 'busy', disabled: true };
    return { text: 'RUNNING', sub: 'close the game to update', cls: 'busy', disabled: true };
  }
  if (!st.installed) return { text: 'INSTALL', sub: `about ${S.config.installSizeGB || 5} GB`, cls: 'violet', run: startInstall };
  if (!st.onChannel) return { text: 'UPDATE', sub: `switch to ${st.channel.name}`, cls: 'violet', run: () => runOp('update') };
  if (st.updateAvailable) {
    const n = S.notes.incoming.length;
    return { text: 'UPDATE', sub: n ? `${n} new change${n === 1 ? '' : 's'}` : 'new version', cls: 'violet', run: () => runOp('update') };
  }
  if (st.needsFiles || st.needsImport || !st.engineReady) return { text: 'PREPARE', sub: st.needsFiles ? 'finish the download' : 'prepare the assets', cls: 'violet', run: () => runOp('prepare') };
  return { text: 'PLAY', sub: '', cls: '', run: play };
}
function renderButton() {
  const a = primaryAction();
  const b = $('playBtn');
  b.className = 'play ' + (a.cls || '');
  b.disabled = !!a.disabled;
  $('playText').textContent = a.text;
  $('playSub').textContent = a.sub || '';
  b.onclick = a.run || null;
  $('cancelBtn').hidden = !(S.status.busy && S.status.busy !== 'check');
}
function renderBuild() {
  const st = S.status;
  const ch = st.channel || {};
  if (!st.installed) { $('build1').textContent = 'Not installed'; $('build2').textContent = `${ch.name || ''} channel`; return; }
  $('build1').textContent = `${ch.name} build`;
  $('build2').textContent = `${(st.head || '').slice(0, 7)}${st.updated ? ' · ' + fmtDate(st.updated) : ''} · Godot ${st.godotVersion}`;
}
function renderProgress() {
  const p = S.progress;
  const bar = $('bar');
  bar.className = 'bar';
  if (!p) {
    const st = S.status;
    if (st.lastError) { bar.classList.add('err'); $('progLabel').textContent = 'Stopped'; $('progDetail').textContent = st.lastError; }
    else if (!st.installed) { bar.classList.add('idle'); $('progLabel').textContent = 'Ready to install'; $('progDetail').textContent = 'Git, the engine and the game are set up for you.'; }
    else if (st.updateAvailable || !st.onChannel) { bar.classList.add('idle'); $('progLabel').textContent = 'Update available'; $('progDetail').textContent = 'Press UPDATE to download the newest build.'; }
    else if (st.needsFiles || st.needsImport || !st.engineReady) { bar.classList.add('idle'); $('progLabel').textContent = 'Setup not finished'; $('progDetail').textContent = st.needsFiles ? 'Some game files did not finish downloading. Press PREPARE.' : 'The assets for this version are not prepared yet. Press PREPARE (a progress bar, a minute or two).'; }
    else if (S.game) { bar.classList.add('full'); $('barFill').style.width = '100%'; $('progLabel').textContent = S.game.state === 'running' ? 'The game is running' : 'Starting the game'; $('progDetail').textContent = S.game.state === 'running' ? 'Close it to update or repair.' : 'Waiting for the game window.'; }
    else { bar.classList.add('full'); $('barFill').style.width = '100%'; $('progLabel').textContent = 'Ready to play'; $('progDetail').textContent = 'You have the newest build.'; }
    $('progPct').textContent = ''; $('progSpeed').textContent = '';
    if (!bar.classList.contains('full')) $('barFill').style.width = '0';
    return;
  }
  $('progLabel').textContent = p.label;
  $('progDetail').textContent = p.detail || '';
  if (p.pct == null) { bar.classList.add('indet'); $('progPct').textContent = ''; } else {
    $('barFill').style.width = `${Math.max(1, Math.min(100, p.pct)).toFixed(1)}%`;
    $('progPct').textContent = `${Math.floor(p.pct)}%`;
  }
  const sp = p.speedText ? p.speedText : p.speed ? `${fmtBytes(p.speed)}/s` : '';
  $('progSpeed').textContent = [sp, p.eta ? fmtEta(p.eta) : ''].filter(Boolean).join(' · ');
}
function renderSettings() {
  const s = S.settings;
  $('setDir').value = s.installDir || ''; $('welcomeDir').value = s.installDir || '';
  $('setDirNote').textContent = S.status.installed ? 'To move the game, uninstall first.' : 'Needs about ' + (S.config.installSizeGB || 5) + ' GB free.';
  $('setDirPick').disabled = !!S.status.installed;
  $('setDriver').value = s.renderingDriver || 'auto';
  $('setFull').checked = !!s.fullscreen;
  $('setAfter').value = s.afterLaunch || 'minimize';
  $('setArgs').value = s.extraArgs || '';
  $('setSafe').checked = !!s.safeMode;
  $('setAuto').checked = s.autoCheck !== false;
  const inst = !!S.status.installed;
  for (const id of ['actRepair', 'actFolder', 'actGameLogs', 'actUninstall']) $(id).disabled = !inst || !!S.status.busy;
  $('about').textContent = `Launcher ${S.version || ''}\nGame folder: ${s.installDir}\n`;
}
function renderAll() { renderChannels(); renderBuild(); renderProgress(); renderButton(); renderSettings(); }

// ---------- actions ----------
async function runOp(name) {
  const r = await api[name]();
  if (r.ok) {
    const title = { install: 'Installed', repair: 'Repaired', prepare: 'Ready' }[name] || 'Up to date';
    toast(title, name === 'install' ? 'Welcome to Silesia. Press PLAY.' : name === 'prepare' ? 'Press PLAY.' : 'The newest build is ready.', 'ok');
  } else if (r.code === 'running') showProblem({ code: 'running', message: r.error, pids: r.pids });
  else if (!r.cancelled) toast('Could not finish', r.error, 'err');
  else toast('Cancelled', 'Press the button again to resume where it stopped.');
  await refreshStatus(); refreshNotes();
}
async function startInstall() {
  $('welcome').hidden = true;
  await runOp('install');
  refreshFeed();
}
// ---------- play (T-289) ----------
async function play(opts) {
  if (S.game) return;
  S.game = { state: 'launching' }; renderButton();
  const r = await api.play(opts || {});
  if (!r.ok) { S.game = null; renderAll(); showProblem({ code: r.code, message: r.error, action: r.action, pids: r.pids }); return; }
  if (S.game && S.game.state === 'launching') S.game = { state: 'starting', pid: r.value.pid, safe: r.value.safeMode };
  renderAll();
  toast('Launching', r.value.safeMode ? 'Starting in safe mode. The window opens in a moment.' : 'The game window opens in a moment. Good hunting.', 'ok');
}
function errDialog(title, msg, lines, note, actions) {
  $('gameErrTitle').textContent = title;
  $('gameErrMsg').textContent = msg;
  $('gameErrLines').hidden = !(lines && lines.length);
  $('gameErrLines').textContent = (lines || []).join('\n');
  $('gameErrNote').textContent = note || '';
  const box = $('gameErrActions'); box.replaceChildren();
  for (const a of actions) {
    const b = el('button', 'ghost' + (a.primary ? ' primary' : ''), a.label);
    b.onclick = () => { $('gameErr').hidden = true; if (a.run) a.run(); };
    box.append(b);
  }
  $('gameErr').hidden = false;
  const first = box.querySelector('.primary') || box.firstChild; if (first) first.focus();
}
const closeAction = { label: 'Close' };
/** PLAY (or an update) was refused: say why, offer the fix. */
function showProblem(p) {
  if (p.code === 'busy') return toast('One moment', p.message, 'err');
  if (p.code === 'running') {
    return errDialog('The game is already running', p.message, null, 'If you cannot find its window, end it and start again.', [
      { label: 'End it and start again', run: async () => { await api.gameAction('end', p.pids); setTimeout(() => { refreshStatus(); play(); }, 1500); } },
      { label: 'Switch to it', primary: true, run: async () => { const r = await api.gameAction('focus', p.pids); if (!r.ok || !r.value) toast('Not found', 'Look for the game on the taskbar.'); } },
      closeAction,
    ]);
  }
  if (p.action === 'prepare') return errDialog('Setup not finished', p.message, null, '', [{ label: 'Prepare now', primary: true, run: () => runOp('prepare') }, closeAction]);
  if (p.code === 'spawn') {
    return errDialog('The game did not start', p.message, null, 'The start log: Settings > Show the start log.', [
      { label: 'Repair files', primary: true, run: () => { go('home'); runOp('repair'); } },
      { label: 'Open launcher logs', run: () => api.openFolder('logs') }, closeAction,
    ]);
  }
  toast('Could not start the game', p.message, 'err');
}
/** The game ended within seconds of PLAY: the reason, the last lines of its log, and what to try. */
function gameFailed(p) {
  const code = p.code == null ? '' : (p.code >>> 0) >= 0xC0000000 ? '0x' + (p.code >>> 0).toString(16).toUpperCase() : String(p.code);
  const msg = `The game ${p.reason || 'closed'} ${p.seconds} s after starting${code ? ` (exit code ${code})` : ''}.`;
  const actions = [];
  if (p.offerSafe) actions.push({ label: 'Start in safe mode', primary: true, run: () => play({ safe: true }) });
  actions.push({ label: 'Repair files', primary: !p.offerSafe, run: () => { go('home'); runOp('repair'); } });
  actions.push({ label: 'Open the game log', run: () => api.openFolder('gameLogs') });
  actions.push(closeAction);
  const note = p.offerSafe
    ? 'Safe mode starts it without the separate render thread (slower, steadier). If that works, keep it on in Settings > Launch > Safe mode. Repair re-downloads and re-checks every file.'
    : 'Repair re-downloads and re-checks every file and prepares the assets again.';
  errDialog('The game closed right after starting', msg, p.lines, note, actions);
}
async function refreshStatus() { const r = await api.status(); if (r.ok) { S.status = r.value; syncGame(); } renderAll(); }
/** The main process knows whether the game it started still runs (status.game). */
function syncGame() {
  const g = S.status.game;
  if (g && !S.game) S.game = { state: g.windowSeen ? 'running' : 'starting', pid: g.pid };
  else if (!g && S.game && S.game.state !== 'launching') S.game = null;
}
async function refreshFeed() { const r = await api.feed(); if (r.ok && r.value) { S.feed = r.value; renderNews(); } }
async function checkUpdates(quiet) {
  if (S.demo) return;
  const r = await api.check();
  if (r.ok) { if (r.value.feed) { S.feed = r.value.feed; renderNews(); } }
  else if (!quiet && !r.cancelled) toast('Update check failed', r.error, 'err');
  await refreshStatus(); refreshNotes();
}
async function showWelcome() {
  $('welcome').hidden = false;
  const list = $('reqList'); list.replaceChildren(el('li', null, 'Checking this PC…'));
  const r = await api.requirements(); if (!r.ok) return;
  const q = r.value;
  const row = (state, text, note) => { const li = el('li'); li.append(el('span', state, state === 'ok' ? '✔' : state === 'bad' ? '✖' : '➜'), el('span', null, text), el('small', null, note)); return li; };
  list.replaceChildren(
    row(q.git ? 'ok' : 'todo', q.git ? 'Git for Windows' : 'Install Git for Windows', q.git ? (q.gitVersion || '').replace('git version ', '') : (q.winget ? 'via winget' : 'official installer')),
    row(q.git ? (q.lfs ? 'ok' : 'bad') : 'todo', 'Git LFS (game assets)', q.git ? (q.lfs ? 'found' : 'missing: reinstall Git') : 'comes with Git'),
    row(q.godot ? 'ok' : 'todo', `Godot ${q.godotVersion} engine`, q.godot ? 'found' : 'download, ~70 MB'),
    row('todo', 'Download the game from GitHub', 'sign-in window on first use'),
    row(q.freeGB == null ? 'todo' : q.freeGB >= q.needGB ? 'ok' : 'bad', `Disk space (needs ~${q.needGB} GB)`, q.freeGB == null ? 'unknown' : `${q.freeGB.toFixed(0)} GB free`),
  );
}

// ---------- wiring ----------
function wire() {
  document.querySelectorAll('.tab').forEach((t) => t.onclick = () => go(t.dataset.view));
  document.querySelectorAll('[data-goto]').forEach((t) => t.onclick = () => go(t.dataset.goto));
  document.querySelectorAll('[data-win]').forEach((b) => b.onclick = () => api.win(b.dataset.win));
  const hideModal = (m) => { if (m.hidden) return; m.hidden = true; if (m.id === 'player') closePlayer(); };
  document.querySelectorAll('[data-close]').forEach((b) => b.onclick = () => hideModal(b.closest('.modal')));
  document.querySelectorAll('.modal').forEach((m) => m.addEventListener('mousedown', (e) => { if (e.target === m) hideModal(m); }));
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') document.querySelectorAll('.modal').forEach(hideModal);
    if (!$('article').hidden && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) showArticlePic(ART.idx + (e.key === 'ArrowLeft' ? -1 : 1));
  });
  $('articlePrev').onclick = () => showArticlePic(ART.idx - 1);
  $('articleNext').onclick = () => showArticlePic(ART.idx + 1);
  $('channelBtn').onclick = (e) => { e.stopPropagation(); $('channelMenu').classList.toggle('open'); };
  document.addEventListener('click', () => $('channelMenu').classList.remove('open'));
  $('heroPrev').onclick = () => showHero(S.heroIdx - 1, true);
  $('heroNext').onclick = () => showHero(S.heroIdx + 1, true);
  $('cancelBtn').onclick = () => api.cancel();
  $('welcomeInstall').onclick = startInstall;
  const pick = async () => { const d = await call('pickDir'); if (d) { const r = await call('setSettings', { installDir: d }); if (r) { S.settings = r.settings; S.status = r.status; renderAll(); showWelcomeIfOpen(); } } };
  $('setDirPick').onclick = pick; $('welcomeDirPick').onclick = pick;
  $('setChannel').onchange = (e) => setChannel(e.target.value);
  const save = async (patch) => { const r = await call('setSettings', patch); if (r) { S.settings = r.settings; S.status = r.status; renderSettings(); } };
  $('setDriver').onchange = (e) => save({ renderingDriver: e.target.value });
  $('setFull').onchange = (e) => save({ fullscreen: e.target.checked });
  $('setAfter').onchange = (e) => save({ afterLaunch: e.target.value });
  $('setArgs').onchange = (e) => save({ extraArgs: e.target.value.trim() });
  $('setAuto').onchange = (e) => save({ autoCheck: e.target.checked });
  $('setSafe').onchange = (e) => save({ safeMode: e.target.checked });
  $('actPlayLog').onclick = () => api.openFolder('playLog');
  $('actRepair').onclick = () => { go('home'); runOp('repair'); };
  $('actFolder').onclick = () => api.openFolder('game');
  $('actGameLogs').onclick = () => api.openFolder('gameLogs');
  $('actLogs').onclick = () => api.openFolder('logs');
  $('actSignOut').onclick = async () => { const r = await api.signOut(); toast(r.ok ? 'Signed out of GitHub' : 'Could not sign out', r.ok ? 'The next download asks you to sign in again.' : r.error, r.ok ? 'ok' : 'err'); };
  $('actUninstall').onclick = async () => { const r = await call('uninstall'); if (r) { toast('Uninstalled', 'The game files are gone.', 'ok'); S.notes = { incoming: [], recent: [] }; await refreshStatus(); renderNotes(); } };

  api.on('progress', (p) => { S.progress = p; renderProgress(); renderButton(); });
  api.on('state', (st) => { if (st && st.channel) { S.status = st; syncGame(); renderAll(); } });
  api.on('game', (g) => {
    if (!g) return;
    if (g.state === 'starting') S.game = { state: 'starting', pid: g.pid, safe: g.safeMode };
    else if (g.state === 'running') S.game = { ...(S.game || {}), state: 'running', pid: g.pid };
    else if (g.state === 'failed') { S.game = null; gameFailed(g); }
    else if (g.state === 'exited') S.game = null;
    renderAll();
  });
}
function showWelcomeIfOpen() { if (!$('welcome').hidden) showWelcome(); }
function go(view) {
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.view === view));
  document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.id === 'view-' + view));
  if (view === 'notes') refreshNotes();
}

// ---------- snow ----------
function snow() {
  const c = $('snow'); const ctx = c.getContext('2d');
  let w = 0; let h = 0; let flakes = [];
  const resize = () => {
    w = c.width = innerWidth * devicePixelRatio; h = c.height = innerHeight * devicePixelRatio;
    flakes = Array.from({ length: 150 }, () => ({ x: Math.random() * w, y: Math.random() * h, z: Math.random(), s: Math.random() * 6.28 }));
  };
  resize(); addEventListener('resize', resize);
  let last = performance.now();
  const frame = (now) => {
    const dt = Math.min(0.05, (now - last) / 1000); last = now;
    ctx.clearRect(0, 0, w, h);
    for (const f of flakes) {
      const sp = (18 + f.z * 50) * devicePixelRatio;
      f.y += sp * dt; f.s += dt * (0.6 + f.z);
      f.x += (Math.sin(f.s) * 10 + 14) * dt * devicePixelRatio * (0.4 + f.z);
      if (f.y > h + 4) { f.y = -4; f.x = Math.random() * w; }
      if (f.x > w + 4) f.x = -4;
      const r = (0.6 + f.z * 1.8) * devicePixelRatio;
      ctx.globalAlpha = 0.25 + f.z * 0.55;
      ctx.fillStyle = '#e9e4ff';
      ctx.beginPath(); ctx.arc(f.x, f.y, r, 0, 6.283); ctx.fill();
    }
    if (!document.hidden) requestAnimationFrame(frame); else setTimeout(() => requestAnimationFrame(frame), 500);
  };
  requestAnimationFrame(frame);
}

// ---------- demo states (screenshots: electron . --capture=out.png --demo=download) ----------
function applyDemo(kind) {
  const ch = (S.status.channels || [])[0] || { id: 'stable', name: 'Stable', branch: 'master' };
  const now = Date.now();
  const fake = (i, s) => ({ sha: (Math.random().toString(16).slice(2) + '0000000000').slice(0, 40), date: new Date(now - i * 7.2e6).toISOString(), subject: s });
  const subjects = [
    'Update 15: a rideable horse in the Carters\' Yard, das Totenross on round 20 and der Fuhrmann on 30. The Inn and Kaltenbrunn passes.',
    'fix(zombies): retain planted contacts through brief stops',
    'Movement: step assist, coyote time and a jump buffer.',
    'Bots: fewer hitches when the whole squad is busy.',
    'assets(zombies): the purchased mocap pack and its 30 converted clips',
    'A Screamer that falls out of the world is put down below y -30.',
  ];
  S.notes = { incoming: kind === 'update' ? subjects.slice(0, 4).map((s, i) => fake(i, s)) : [], recent: subjects.map((s, i) => fake(i + 4, s)) };
  if (kind === 'fresh') S.status = { ...S.status, installed: false, busy: null, lastError: null, channel: ch };
  if (kind === 'play' || kind === 'update' || kind === 'download') S.status = { ...S.status, installed: true, onChannel: true, engineReady: true, needsImport: false, updateAvailable: kind === 'update', busy: kind === 'download' ? 'update' : null, head: 'a83f7441c0ffee', updated: new Date().toISOString(), lastError: null, channel: ch };
  if (kind === 'download') S.progress = { step: 'lfs', label: 'Downloading game assets', pct: 63.4, detail: '5,041 / 7,952 files · 942.7 MB', speed: 14.2 * 1048576, eta: 214 };
  if (kind === 'notes') { S.status = { ...S.status, installed: true, onChannel: true, engineReady: true, head: 'a83f7441c0ffee', channel: ch, updateAvailable: true }; S.notes.incoming = subjects.slice(0, 3).map((s, i) => fake(i, s)); }
  renderAll(); renderNotes();
  if (kind === 'notes') go('notes');
  if (kind === 'settings') go('settings');
  if (kind === 'upcoming') go('upcoming');
  if (kind.startsWith('article')) { // article, article:<news id>, article:<news id>:<picture>
    const [, id, pic] = kind.split(':');
    const n = visibleNews().find((x) => x.id === id) || S.hero[0];
    if (n) openArticle(n, Number(pic) || 0);
  }
  if (kind.startsWith('hero:')) { const i = S.hero.findIndex((x) => x.id === kind.slice(5)); if (i >= 0) showHero(i, true); }
  if (kind === 'fresh') showWelcome();
  // T-289 states: the start failed / already running / a trailer slide (trailer:play opens the player)
  if (kind === 'gamefail') {
    gameFailed({ reason: 'crashed (access violation)', seconds: 3.4, code: 3221225477, offerSafe: true, lines: [
      'Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org',
      'Vulkan 1.4.357 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5090',
      'ERROR: finalize can only be called from the render thread.',
      '   at: finalize (servers/rendering/rendering_server_default.cpp:261)'] });
  }
  if (kind === 'running') showProblem({ code: 'running', message: 'The game is already running (started earlier). Switch to it, or end it and start again.', pids: [1] });
  if (kind.startsWith('trailer')) {
    const item = { id: 'demo-trailer', type: 'video', date: new Date().toISOString().slice(0, 10), tag: 'TRAILER', hero: true,
      title: 'The first trailer', summary: 'A minute of Silesia in winter: the Inn, the mine, the harbour, and what keeps count of the dead.',
      image: 'repo:launcher/assets/news/u19_snow.jpg', video: { src: 'repo:launcher/media/teaser_720p.mp4', label: 'Watch the teaser', duration: '1:07' } };
    S.feed = { ...(S.feed || {}), news: [item, ...((S.feed && S.feed.news) || [])] };
    S.status = { ...S.status, installed: true, onChannel: true, engineReady: true, needsImport: false, updateAvailable: false, busy: null, head: 'a83f7441c0ffee', channel: ch };
    renderAll(); renderNews(); showHero(0, true);
    if (kind === 'trailer:play') openPlayer(item);
  }
}

// ---------- boot ----------
(async function boot() {
  wire(); snow();
  const r = await api.boot();
  if (!r.ok) { toast('Launcher error', r.error, 'err'); return; }
  const b = r.value;
  Object.assign(S, { config: b.config, settings: b.settings, status: b.status, feed: b.feed, version: b.version, demo: b.demo });
  syncGame();
  $('tagline').textContent = b.config.tagline || '';
  $('subtitle').textContent = b.config.subtitle || '';
  renderAll(); renderNews(); requestAnimationFrame(heroTick);
  if (S.demo) { applyDemo(S.demo); return; }
  if (!S.status.installed) { showWelcome(); renderNotes(); }
  else { refreshNotes(); if (S.settings.autoCheck !== false) checkUpdates(true); }
})();
