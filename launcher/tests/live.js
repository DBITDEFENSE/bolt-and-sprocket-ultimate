'use strict';
// End-to-end without Electron: node tests/live.js <scratch dir> [channel]
// install -> status -> update (no-op) -> patch notes -> headless boot of the main menu (no window).
const fs = require('fs');
const path = require('path');
const { GameManager } = require('../src/manager');
const { run } = require('../src/proc');

const root = path.resolve(process.argv[2] || 'live_test');
const settings = { installDir: path.join(root, 'game'), channel: process.argv[3] || 'stable' };
const config = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config.json'), 'utf8'));
let lastShown = '';
const m = new GameManager({
  dataDir: path.join(root, 'data'), config, getSettings: () => settings,
  emit: (e, p) => {
    if (e !== 'progress' || !p) return;
    const line = `${p.label} ${p.pct == null ? '' : Math.floor(p.pct) + '%'} ${p.detail || ''}`;
    const key = p.label + (p.pct == null ? '' : Math.floor(p.pct / 10));
    if (key !== lastShown) { lastShown = key; console.log(new Date().toISOString().slice(11, 19), line); }
  },
});
(async () => {
  const t0 = Date.now();
  console.log('requirements', JSON.stringify(await m.requirements()));
  await m.install();
  console.log(`install done in ${((Date.now() - t0) / 60000).toFixed(1)} min`);
  console.log('status', JSON.stringify(await m.status()));
  const t1 = Date.now();
  await m.checkForUpdate();
  await m.update();
  console.log(`update (no-op) in ${((Date.now() - t1) / 1000).toFixed(0)} s`);
  const notes = await m.patchNotes(5);
  console.log('recent commits:', notes.recent.map((c) => c.sha.slice(0, 7) + ' ' + c.subject.slice(0, 60)).join('\n  '));
  console.log('feed source:', m.feed && m.feed._source, 'items:', m.feed && m.feed.news && m.feed.news.length);
  const exe = m.godotConsoleExe();
  const r = await run(exe, ['--headless', '--audio-driver', 'Dummy', '--path', settings.installDir, '--quit-after', '300', m.mainScene()]);
  const errs = (r.stdout + r.stderr).split(/\r?\n/).filter((l) => /SCRIPT ERROR|ERROR:/.test(l));
  console.log(`headless boot exit ${r.code}, ${errs.length} error lines`);
  errs.slice(0, 15).forEach((l) => console.log('  ' + l));
  console.log('LIVE RESULT', r.code === 0 ? 'PASS' : 'FAIL');
})().catch((e) => { console.log('LIVE RESULT FAIL', e.stack || e.message); process.exit(1); });
