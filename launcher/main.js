'use strict';
// Electron main process: the window, settings, IPC to the renderer, and the GameManager that does the work.
const { app, BrowserWindow, ipcMain, dialog, shell, protocol, net } = require('electron');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');
const { Readable } = require('stream');
const { GameManager } = require('./src/manager');

const ROOT = __dirname;
const CONFIG = JSON.parse(fs.readFileSync(path.join(ROOT, 'config.json'), 'utf8'));
const BUNDLED_FEED = (() => { try { return JSON.parse(fs.readFileSync(path.join(ROOT, 'feed.json'), 'utf8')); } catch (_) { return null; } })();
const LOCAL = process.env.LOCALAPPDATA || app.getPath('userData');
const DATA_DIR = process.env.CZ_LAUNCHER_DATA || path.join(LOCAL, 'ClaudeZombies', 'launcher');
const SETTINGS_FILE = path.join(DATA_DIR, 'settings.json');
const argv = process.argv.slice(1);
const CAPTURE = (argv.find((a) => a.startsWith('--capture=')) || '').slice(10);
const DEMO = (argv.find((a) => a.startsWith('--demo=')) || '').slice(7);
if (CAPTURE) app.commandLine.appendSwitch('mute-audio'); // screenshot runs never make a sound (the trailer player has it on)

const DEFAULT_SETTINGS = {
  installDir: path.join(LOCAL, 'ClaudeZombies', 'game'),
  channel: CONFIG.defaultChannel,
  renderingDriver: 'auto',
  fullscreen: false,
  extraArgs: '',
  afterLaunch: 'minimize', // minimize | close | keep
  autoCheck: true,
  safeMode: false, // T-289: leaves out --render-thread separate (the renderer back on the main thread)
};
let settings = loadSettings();
function loadSettings() {
  try { return { ...DEFAULT_SETTINGS, ...JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8')) }; } catch (_) { return { ...DEFAULT_SETTINGS }; }
}
function saveSettings() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
}

let win = null;
const send = (ch, payload) => { if (win && !win.isDestroyed()) win.webContents.send(ch, payload); };
function bringBack() { if (win && !win.isDestroyed()) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); } }
// a game that failed to start brings the launcher back with the reason (it may have minimized itself)
const emit = (ch, payload) => { if (ch === 'game' && payload && payload.state === 'failed') bringBack(); send(ch, payload); };
fs.mkdirSync(DATA_DIR, { recursive: true });
const mgr = new GameManager({ dataDir: DATA_DIR, config: CONFIG, getSettings: () => settings, emit });

// One launcher at a time: a second start focuses the first.
if (!CAPTURE && !app.requestSingleInstanceLock()) { app.quit(); }
app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); } });

// game://img/<repo path> serves images from the installed game (news art that lives in the repo). Images only.
// game://media/<repo path> streams trailers from launcher/media/ (mp4 / webm) with byte ranges, so <video> can seek.
protocol.registerSchemesAsPrivileged([{ scheme: 'game', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }]);

function createWindow() {
  // screenshots only: CZ_CAPTURE_SIZE=1080x660 captures at another window size (the window is never shown)
  const size = /^(\d{3,4})x(\d{3,4})$/.exec((CAPTURE && process.env.CZ_CAPTURE_SIZE) || '');
  win = new BrowserWindow({
    width: size ? Number(size[1]) : 1280, height: size ? Number(size[2]) : 760, minWidth: 1080, minHeight: 660,
    frame: false, backgroundColor: '#08070c', show: false, title: CONFIG.productName,
    icon: path.join(ROOT, 'build', 'icon.png'),
    webPreferences: { preload: path.join(ROOT, 'preload.js'), contextIsolation: true, sandbox: true, nodeIntegration: false, spellcheck: false },
  });
  win.removeMenu();
  win.webContents.setWindowOpenHandler(({ url }) => { openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e) => e.preventDefault());
  win.on('maximize', () => send('window', { maximized: true }));
  win.on('unmaximize', () => send('window', { maximized: false }));
  win.loadFile(path.join(ROOT, 'renderer', 'index.html'), { query: DEMO ? { demo: DEMO } : {} });
  if (CAPTURE) {
    win.webContents.once('did-finish-load', () => setTimeout(async () => {
      const img = await win.webContents.capturePage();
      fs.writeFileSync(CAPTURE, img.toPNG());
      app.exit(0);
    }, Number(process.env.CZ_CAPTURE_DELAY || 2500)));
  } else {
    win.once('ready-to-show', () => win.show());
  }
}

/** A video file as a (ranged) response: 206 for "Range: bytes=a-b", else the whole file. */
function serveVideo(file, range) {
  const size = fs.statSync(file).size;
  const type = /\.webm$/i.test(file) ? 'video/webm' : 'video/mp4';
  const m = /^bytes=(\d*)-(\d*)$/.exec(range || '');
  if (!m || (!m[1] && !m[2])) {
    return new Response(Readable.toWeb(fs.createReadStream(file)), { status: 200, headers: { 'Content-Type': type, 'Content-Length': String(size), 'Accept-Ranges': 'bytes' } });
  }
  const start = m[1] ? Number(m[1]) : Math.max(0, size - Number(m[2]));
  const end = m[1] && m[2] ? Math.min(Number(m[2]), size - 1) : size - 1;
  if (start >= size || start > end) return new Response('', { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
  return new Response(Readable.toWeb(fs.createReadStream(file, { start, end })), {
    status: 206,
    headers: { 'Content-Type': type, 'Content-Length': String(end - start + 1), 'Content-Range': `bytes ${start}-${end}/${size}`, 'Accept-Ranges': 'bytes' },
  });
}

function openExternal(url) {
  if (/^https:\/\//i.test(url)) shell.openExternal(url);
}

app.whenReady().then(async () => {
  protocol.handle('game', (req) => {
    const u = new URL(req.url);
    const rel = decodeURIComponent(u.pathname).replace(/^\/+/, '');
    const base = path.resolve(settings.installDir);
    const file = path.resolve(base, rel);
    const inside = file.startsWith(base + path.sep);
    if (inside && u.host === 'media' && /\.(mp4|webm)$/i.test(file) && file.startsWith(path.join(base, 'launcher', 'media') + path.sep) && fs.existsSync(file)) {
      return serveVideo(file, req.headers.get('range'));
    }
    if (!inside || !/\.(png|jpe?g|webp|gif|svg)$/i.test(file) || !fs.existsSync(file)) {
      return new Response('not found', { status: 404 });
    }
    return net.fetch(pathToFileURL(file).toString());
  });
  await mgr.loadFeed(BUNDLED_FEED).catch(() => {});
  createWindow();
});
app.on('window-all-closed', () => { mgr.cancel(); app.quit(); });

// ---------- IPC ----------
const handle = (ch, fn) => ipcMain.handle(ch, async (_e, ...a) => {
  try { return { ok: true, value: await fn(...a) }; } catch (e) {
    return { ok: false, error: e.message, cancelled: !!e.cancelled, code: e.code || null, action: e.action || null, pids: e.pids || null };
  }
});

handle('boot', async () => ({
  config: { productName: CONFIG.productName, subtitle: CONFIG.subtitle, tagline: CONFIG.tagline, repoWeb: CONFIG.repoWeb, installSizeGB: CONFIG.installSizeGB },
  version: app.getVersion(),
  settings,
  status: await mgr.status(),
  feed: mgr.feed,
  demo: DEMO || null,
}));
handle('status', () => mgr.status());
handle('requirements', () => mgr.requirements());
handle('feed', async () => mgr.feed);
handle('patchNotes', () => mgr.patchNotes());
handle('check', async () => { const r = await mgr.checkForUpdate(); return { ...r, feed: mgr.feed }; });
handle('install', () => mgr.install());
handle('update', () => mgr.update());
handle('repair', () => mgr.repair());
handle('prepare', () => mgr.prepare());
handle('gameAction', (what, pids) => mgr.gameAction(what, pids));
handle('cancel', () => mgr.cancel());
handle('play', async (opts) => {
  const r = await mgr.play({ safe: !!(opts && opts.safe) });
  afterStart(r.pid).catch((e) => mgr.log('after start: ' + e.message));
  return r;
});
// T-289: the launcher steps aside only once the game's window is up (minimizing at once let Windows open the game
// behind other programs), and "close the launcher" waits until the game has outlived its start, so a crash at start
// still finds the launcher there to explain it.
async function afterStart(pid) {
  const seen = await mgr.waitForWindow(pid);
  if (seen === 'exited') return;
  if (settings.afterLaunch === 'minimize' && win && !win.isDestroyed()) win.minimize();
  else if (settings.afterLaunch === 'close') {
    if (win && !win.isDestroyed()) win.minimize();
    if (await mgr.survivesStart(pid)) app.quit();
  }
}
handle('uninstall', async () => {
  const r = await dialog.showMessageBox(win, {
    type: 'warning', buttons: ['Uninstall', 'Cancel'], defaultId: 1, cancelId: 1,
    title: 'Uninstall', message: `Delete the game files in\n${settings.installDir}?`, detail: 'Your settings and saves in the user folder stay. The engine download stays too.',
  });
  if (r.response !== 0) return false;
  await mgr.uninstall();
  return true;
});
handle('signOut', () => mgr.signOut());
handle('getSettings', () => settings);
handle('setSettings', async (patch) => {
  const allowed = Object.keys(DEFAULT_SETTINGS);
  mgr.assertSettingsChange(patch, settings);
  if (patch && 'installDir' in patch && patch.installDir !== settings.installDir && mgr.isInstalled()) {
    throw new Error('Uninstall first, or move the folder yourself and point the launcher at it.');
  }
  for (const k of allowed) if (patch && k in patch) settings[k] = patch[k];
  saveSettings();
  await mgr.loadFeed().catch(() => {});
  return { settings, status: await mgr.status() };
});
handle('pickDir', async () => {
  const r = await dialog.showOpenDialog(win, { title: 'Install folder', properties: ['openDirectory', 'createDirectory'], defaultPath: settings.installDir });
  if (r.canceled || !r.filePaths[0]) return null;
  let dir = r.filePaths[0];
  // a non-empty folder gets a subfolder, so the launcher never mixes its files with others
  try { if (fs.readdirSync(dir).length && !fs.existsSync(path.join(dir, '.launcher-managed'))) dir = path.join(dir, 'ClaudeZombies'); } catch (_) { /* ignore */ }
  return dir;
});
handle('openFolder', (which) => {
  if (which === 'playLog') { const f = mgr.playLogPath(); if (fs.existsSync(f)) shell.showItemInFolder(f); return; }
  const p = which === 'logs' ? path.join(DATA_DIR, 'logs') : which === 'gameLogs' ? path.join(settings.installDir, 'logs') : settings.installDir;
  if (fs.existsSync(p)) shell.openPath(p);
});
handle('openExternal', (url) => openExternal(url));
handle('win', (what) => {
  if (!win) return;
  if (what === 'min') win.minimize();
  else if (what === 'max') { if (win.isMaximized()) win.unmaximize(); else win.maximize(); }
  else if (what === 'close') win.close();
});
