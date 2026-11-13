'use strict';
// Screenshots of the launcher's states without showing a window: node tests/shots.js <out dir>
const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');
const out = path.resolve(process.argv[2] || 'shots');
fs.mkdirSync(out, { recursive: true });
const electron = require('electron'); // the path to electron.exe when required from Node
const data = fs.mkdtempSync(path.join(os.tmpdir(), 'czl-shots-'));
for (const demo of ['play', 'fresh', 'download', 'update', 'notes', 'settings']) {
  const file = path.join(out, `launcher_${demo}.png`);
  const r = spawnSync(electron, ['.', `--capture=${file}`, `--demo=${demo}`], { cwd: path.join(__dirname, '..'), env: { ...process.env, CZ_LAUNCHER_DATA: data }, timeout: 60000 });
  console.log(demo, r.status, fs.existsSync(file) ? 'saved ' + file : 'MISSING', String(r.stderr || '').trim().slice(0, 300));
}
fs.rmSync(data, { recursive: true, force: true });
