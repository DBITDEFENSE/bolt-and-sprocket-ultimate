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
// States can be named after the folder: node tests/shots.js <out dir> upcoming article:u19:2 hero:u18
//   article:<news id>[:<picture index>] opens that article, hero:<news id> shows that carousel slide.
// CZ_CAPTURE_SIZE=1080x660 captures at another window size (adds _1080x660 to the file names).
const demos = process.argv.length > 3 ? process.argv.slice(3) : ['play', 'fresh', 'download', 'update', 'notes', 'settings', 'upcoming', 'article:u19', 'article:u19-fixes:3', 'article:launcher-1', 'hero:u18'];
const suffix = process.env.CZ_CAPTURE_SIZE ? '_' + process.env.CZ_CAPTURE_SIZE : '';
for (const demo of demos) {
  const file = path.join(out, `launcher_${demo.replace(/[^\w-]+/g, '_')}${suffix}.png`);
  const r = spawnSync(electron, ['.', `--capture=${file}`, `--demo=${demo}`], { cwd: path.join(__dirname, '..'), env: { ...process.env, CZ_LAUNCHER_DATA: data }, timeout: 60000 });
  console.log(demo, r.status, fs.existsSync(file) ? 'saved ' + file : 'MISSING', String(r.stderr || '').trim().slice(0, 300));
}
fs.rmSync(data, { recursive: true, force: true });
