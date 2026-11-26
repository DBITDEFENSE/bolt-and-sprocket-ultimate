'use strict';
// The real PLAY path with the real engine, headless (no window): node tests/play_headless.js <scratch dir> [game dir] [engine exe]
// Runs GameManager.play() exactly as the launcher does (detached spawn, launcher_play.log, the exit watch) with
// --headless --audio-driver Dummy --quit-after added through "extra launch arguments", against an installed game
// (default: the launcher's own install). Its logs go to the scratch dir; the game folder is only read.
const fs = require('fs');
const path = require('path');
const { GameManager } = require('../src/manager');

const scratch = path.resolve(process.argv[2] || 'play_headless');
const local = process.env.LOCALAPPDATA || '';
const gameDir = path.resolve(process.argv[3] || path.join(local, 'ClaudeZombies', 'game'));
const config = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config.json'), 'utf8'));
const exe = path.resolve(process.argv[4] || path.join(local, 'ClaudeZombies', 'launcher', 'godot', config.godot.version, `Godot_v${config.godot.version}-stable_win64.exe`));
const frames = Number(process.env.CZ_QUIT_AFTER || 300);
const dataDir = path.join(scratch, 'launcher data'); // a space on purpose
const settings = { installDir: gameDir, channel: 'stable', renderingDriver: 'auto', fullscreen: false, safeMode: process.env.CZ_SAFE === '1',
  extraArgs: `--headless --audio-driver Dummy --quit-after ${frames}` };
const events = [];
const m = new GameManager({
  dataDir, config, getSettings: () => settings, gameLogDir: path.join(scratch, 'game logs'), earlyExitMs: 0,
  emit: (e, p) => { if (e === 'game') { events.push(p); console.log('event game', JSON.stringify({ ...p, lines: undefined, output: undefined })); } },
});
m.godotExe = () => exe; // the engine copy the launcher already downloaded (or the one given)
(async () => {
  await m.detectGit();
  console.log('engine', exe, fs.existsSync(exe));
  console.log('game  ', gameDir);
  const t0 = Date.now();
  const r = await m.play();
  console.log('started pid', r.pid, 'renderThread', r.renderThread, 'args', JSON.stringify(m.game.args));
  const keepAlive = setInterval(() => {}, 1000); // the game is unref'd (detached): keep this script alive until it exits
  const g = await m.game.exitPromise;
  clearInterval(keepAlive);
  const secs = ((Date.now() - t0) / 1000).toFixed(1);
  const gameLog = fs.existsSync(g.gameLog) ? fs.readFileSync(g.gameLog, 'utf8') : '';
  const playLog = fs.readFileSync(m.playLogPath(), 'utf8');
  const menu = /\[menu_scene\] (built|first frame)/.test(gameLog);
  const thread = /render thread (separate|safe)/.exec(gameLog);
  console.log(`exit ${g.code} after ${secs} s; game log ${gameLog.length} bytes, main menu built: ${menu}${thread ? ', ' + thread[0] : ''}`);
  console.log('launcher_play.log tail:\n  ' + playLog.trim().split(/\r?\n/).slice(-6).join('\n  '));
  const errs = gameLog.split(/\r?\n/).filter((l) => /SCRIPT ERROR|^ERROR:/.test(l));
  console.log(`${errs.length} error lines`); errs.slice(0, 10).forEach((l) => console.log('  ' + l));
  console.log('PLAY HEADLESS RESULT', g.code === 0 && menu ? 'PASS' : 'FAIL');
  process.exit(g.code === 0 && menu ? 0 : 1);
})().catch((e) => { console.log('PLAY HEADLESS RESULT FAIL', e.code || '', e.message); process.exit(1); });
