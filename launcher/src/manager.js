'use strict';
// GameManager: everything the launcher does to the machine. Plain Node (no Electron) so it runs from tests/cli.js too.
//   dependencies: Git for Windows (git + Git LFS + Git Credential Manager), Godot (downloaded per version)
//   game:         a launcher-managed partial clone of the GitHub repo (blob:none), LFS files pulled for the checkout
//   import:       godot --headless --import after every install/update (the .godot cache is not in git)
//   play:         godot --path <game> <main scene>
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const childProcess = require('child_process');
const { run, Tracker, Cancelled, lastLines } = require('./proc');

const MARKER = '.launcher-managed';
// T-289: a game that ends within this long after PLAY failed to start (the main menu needs ~7 s to build on the
// owner's PC); the launcher shows why instead of leaving the player to press PLAY again.
const EARLY_EXIT_MS = 20000;
const WINDOW_WAIT_MS = 30000;      // how long PLAY waits for the game window before minimizing the launcher anyway
const IMPORT_IDLE_MS = 10 * 60000; // a headless import that prints nothing for this long is hung: killed, reported
const PLAY_LOG_MAX = 2e6;          // logs/launcher_play.log rotates to .1, .2 past this size
const GAME_LOGS_KEPT = 5;          // <game>/logs/game_last.log + the previous starts as game_<time>.log
const STEP_NAMES = {
  deps: 'Checking requirements',
  git: 'Installing Git',
  auth: 'Connecting to GitHub',
  godot: 'Downloading the game engine',
  clone: 'Downloading game data',
  fetch: 'Checking for updates',
  checkout: 'Unpacking game files',
  lfs: 'Downloading game assets',
  import: 'Preparing assets for first launch',
  repair: 'Verifying files',
  prepare: 'Finishing setup',
};
const OP_WORDS = { install: 'install', update: 'update', repair: 'repair', prepare: 'setup', check: 'update check' };

/** An error PLAY (or an operation) reports with a code the launcher turns into a dialog with the right buttons. */
function codedError(code, message, extra = {}) {
  const e = new Error(message);
  e.code = code;
  Object.assign(e, extra);
  return e;
}

class GameManager {
  /**
   * @param {object} o
   * @param {string} o.dataDir     launcher data root (godot/, logs/)
   * @param {object} o.config      config.json contents
   * @param {function} o.getSettings  () => settings object (installDir, channel, ...)
   * @param {function} o.emit      (event, payload) => void   events: progress, log, state, game
   * Test seams (defaults are the real thing): o.spawn (child_process.spawn for the game), o.run (proc.run for the
   * import), o.findGame (() => pids of a running game), o.platform, o.earlyExitMs, o.gameLogDir.
   */
  constructor(o) {
    this.dataDir = o.dataDir;
    this.config = o.config;
    this.getSettings = o.getSettings;
    this.emit = o.emit || (() => {});
    this.spawn = o.spawn || childProcess.spawn;
    this.runProc = o.run || run;
    this.platform = o.platform || process.platform;
    this.earlyExitMs = o.earlyExitMs != null ? o.earlyExitMs : EARLY_EXIT_MS;
    this.findGameImpl = o.findGame || null;
    this.gameLogDirOverride = o.gameLogDir || null;
    this.game = null; // the game this launcher started and that still runs: { pid, started, args, renderThread, ... }
    this.git = null;
    this.busy = null;
    this.tracker = null;
    this.feed = null;
    this.remoteSha = null;
    this.lastError = null;
    fs.mkdirSync(path.join(this.dataDir, 'logs'), { recursive: true });
    this.logFile = path.join(this.dataDir, 'logs', 'launcher.log');
    try {
      const st = fs.statSync(this.logFile);
      if (st.size > 5e6) fs.renameSync(this.logFile, this.logFile + '.old');
    } catch (_) { /* first run */ }
  }

  // ---------- small helpers ----------
  log(msg) {
    const line = `[${new Date().toISOString()}] ${msg}`;
    try { fs.appendFileSync(this.logFile, line + '\n'); } catch (_) { /* ignore */ }
    this.emit('log', line);
  }

  get gameDir() { return this.getSettings().installDir; }
  get channel() {
    const s = this.getSettings();
    const list = this.channels();
    return list.find((c) => c.id === s.channel) || list.find((c) => c.id === this.config.defaultChannel) || list[0];
  }
  channels() {
    const fromFeed = this.feed && Array.isArray(this.feed.channels) && this.feed.channels.length ? this.feed.channels : null;
    return fromFeed || this.config.channels;
  }
  godotVersion() { return (this.feed && this.feed.godot && this.feed.godot.version) || this.config.godot.version; }
  mainScene() { return (this.feed && this.feed.mainScene) || this.config.mainScene; }
  excludes() { return (this.feed && Array.isArray(this.feed.exclude) ? this.feed.exclude : this.config.exclude) || []; }
  godotExe(ver = this.godotVersion()) {
    return path.join(this.dataDir, 'godot', ver, `Godot_v${ver}-stable_win64.exe`);
  }
  godotConsoleExe(ver = this.godotVersion()) {
    return path.join(this.dataDir, 'godot', ver, `Godot_v${ver}-stable_win64_console.exe`);
  }
  statePath() { return path.join(this.gameDir, MARKER); }
  readState() {
    try { return JSON.parse(fs.readFileSync(this.statePath(), 'utf8')); } catch (_) { return null; }
  }
  writeState(patch) {
    const s = { ...(this.readState() || {}), ...patch };
    fs.writeFileSync(this.statePath(), JSON.stringify(s, null, 2));
    return s;
  }
  isInstalled() {
    return fs.existsSync(path.join(this.gameDir, '.git')) && fs.existsSync(this.statePath());
  }

  progress(step, pct, detail = '', extra = {}) {
    this.emit('progress', { step, label: STEP_NAMES[step] || step, pct, detail, ...extra });
  }

  /** git with the environment every call needs: no terminal prompts (GCM still shows its sign-in window). */
  gitRun(args, opts = {}) {
    if (!this.git) throw new Error('Git is not installed.');
    return run(this.git, args, {
      tracker: this.tracker,
      ...opts,
      env: { GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'auto', LC_ALL: 'C', ...(opts.env || {}) },
    });
  }

  // ---------- requirements ----------
  async detectGit() {
    const candidates = ['git'];
    if (process.platform === 'win32') {
      const pf = [process.env.ProgramFiles, process.env['ProgramFiles(x86)'], path.join(process.env.LOCALAPPDATA || '', 'Programs')];
      for (const p of pf) if (p) candidates.push(path.join(p, 'Git', 'cmd', 'git.exe'));
    }
    for (const c of candidates) {
      try {
        const r = await run(c, ['--version']);
        if (r.code === 0) {
          const lfs = await run(c, ['lfs', 'version']).catch(() => ({ code: 1 }));
          this.git = c;
          return { git: c, version: r.stdout.trim(), lfs: lfs.code === 0, lfsVersion: (lfs.stdout || '').trim() };
        }
      } catch (_) { /* not here */ }
    }
    this.git = null;
    return null;
  }

  async requirements() {
    const g = await this.detectGit();
    const ver = this.godotVersion();
    let freeGB = null;
    try {
      const probe = existingParent(this.gameDir);
      const st = await fsp.statfs(probe);
      freeGB = (st.bavail * st.bsize) / 1e9;
    } catch (_) { /* unknown */ }
    return {
      git: !!g,
      gitVersion: g ? g.version : null,
      lfs: !!(g && g.lfs),
      godot: fs.existsSync(this.godotExe(ver)),
      godotVersion: ver,
      freeGB,
      needGB: this.config.installSizeGB,
      winget: await hasWinget(),
    };
  }

  /** Installs Git for Windows (it brings Git LFS and Git Credential Manager). winget first, else the official installer. */
  async installGit() {
    this.progress('git', null, 'Asking Windows to install Git (approve the prompt if one appears)');
    if (await hasWinget()) {
      this.log('installing Git with winget');
      const r = await run('winget', ['install', '--id', 'Git.Git', '-e', '--source', 'winget', '--silent',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'],
      { tracker: this.tracker, onLine: (l) => this.log('winget: ' + l) });
      this.log(`winget exit ${r.code}`);
      if (await this.detectGit()) return;
    }
    this.log('installing Git from the official installer');
    const rel = await httpJson('https://api.github.com/repos/git-for-windows/git/releases/latest');
    const asset = (rel.assets || []).find((a) => /^Git-[\d.]+(\.windows\.\d+)?-64-bit\.exe$/.test(a.name));
    if (!asset) throw new Error('Could not find the Git for Windows installer. Install Git from https://git-scm.com and try again.');
    const dl = path.join(this.dataDir, 'downloads');
    await fsp.mkdir(dl, { recursive: true });
    const exe = path.join(dl, asset.name);
    await this.download(asset.browser_download_url, exe, 'git', asset.size);
    this.progress('git', null, 'Running the Git installer (approve the prompt if one appears)');
    const ps = `Start-Process -FilePath '${exe.replace(/'/g, "''")}' -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/SUPPRESSMSGBOXES' -Verb RunAs -Wait`;
    await run('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', ps], { tracker: this.tracker });
    if (!(await this.detectGit())) throw new Error('Git did not install. Install it from https://git-scm.com, then press Install again.');
  }

  /** Downloads and verifies Godot <ver> (win64) into dataDir/godot/<ver>/. */
  async ensureGodot(ver = this.godotVersion()) {
    if (fs.existsSync(this.godotExe(ver))) return this.godotExe(ver);
    const dir = path.join(this.dataDir, 'godot', ver);
    await fsp.mkdir(dir, { recursive: true });
    const name = `Godot_v${ver}-stable_win64.exe.zip`;
    const base = `https://github.com/godotengine/godot/releases/download/${ver}-stable/`;
    const zip = path.join(dir, name);
    this.log(`downloading ${base}${name}`);
    await this.download(base + name, zip, 'godot');
    let expected = null;
    try {
      const sums = await httpText(base + 'SHA512-SUMS.txt');
      const m = sums.split(/\r?\n/).map((l) => l.trim().split(/\s+/)).find((p) => p[1] === name);
      if (m) expected = m[0].toLowerCase();
    } catch (e) { this.log('no SHA512-SUMS.txt for this Godot release: ' + e.message); }
    if (expected) {
      this.progress('godot', null, 'Verifying download');
      const got = await sha512(zip);
      if (got !== expected) { await fsp.rm(zip, { force: true }); throw new Error('The engine download was corrupted (checksum mismatch). Try again.'); }
      this.log('godot checksum OK');
    }
    this.progress('godot', null, 'Unpacking the engine');
    const tar = process.platform === 'win32' ? path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe') : 'tar';
    await run(tar, ['-xf', zip, '-C', dir], { tracker: this.tracker, check: true });
    await fsp.rm(zip, { force: true });
    if (!fs.existsSync(this.godotExe(ver))) throw new Error(`The engine archive did not contain ${path.basename(this.godotExe(ver))}.`);
    return this.godotExe(ver);
  }

  /** Streams url to dest with progress (bytes, speed, ETA). */
  async download(url, dest, step, sizeHint) {
    const ctrl = new AbortController();
    const onCancel = setInterval(() => { if (this.tracker && this.tracker.cancelled) ctrl.abort(); }, 250);
    try {
      const res = await fetch(url, { signal: ctrl.signal, redirect: 'follow', headers: { 'User-Agent': 'game-launcher' } });
      if (!res.ok) throw new Error(`Download failed (${res.status}) for ${url}`);
      const total = Number(res.headers.get('content-length')) || sizeHint || 0;
      const tmp = dest + '.part';
      const out = fs.createWriteStream(tmp);
      let got = 0;
      const meter = new Meter();
      for await (const chunk of res.body) {
        got += chunk.length;
        if (!out.write(chunk)) await new Promise((r) => out.once('drain', r));
        const m = meter.tick(got, total);
        if (m) this.progress(step, total ? (got / total) * 100 : null, `${fmtBytes(got)}${total ? ' / ' + fmtBytes(total) : ''}`, m);
      }
      await new Promise((r, j) => out.end((e) => (e ? j(e) : r())));
      await fsp.rename(tmp, dest);
    } catch (e) {
      if (this.tracker && this.tracker.cancelled) throw new Cancelled();
      throw e;
    } finally {
      clearInterval(onCancel);
    }
  }

  // ---------- GitHub access ----------
  /** ls-remote the channel branch: triggers the GCM sign-in window on first use; maps failures to plain words. */
  async checkAccess() {
    this.progress('auth', null, 'If a GitHub sign-in window opens, sign in with the account that was invited');
    const r = await this.gitRun(['ls-remote', '--heads', this.config.repoUrl, this.channel.branch]);
    if (r.code !== 0) throw new Error(explainGitError(r.stderr));
    const line = r.stdout.trim().split(/\r?\n/)[0] || '';
    if (!line) throw new Error(`The "${this.channel.name}" channel (branch ${this.channel.branch}) does not exist on GitHub any more. Pick another channel in Settings.`);
    return line.split(/\s+/)[0];
  }

  /** Forget the stored GitHub login so the next access asks again (switch account). */
  async signOut() {
    await this.detectGit();
    await this.gitRun(['credential', 'reject'], { input: 'protocol=https\nhost=github.com\n\n' });
    this.log('GitHub credentials cleared');
  }

  // ---------- operations ----------
  async op(name, fn) {
    if (this.busy) throw codedError('busy', `Wait until the ${OP_WORDS[this.busy] || this.busy} finishes (or press Cancel).`, { busy: this.busy });
    this.busy = name;
    this.tracker = new Tracker();
    this.lastError = null;
    this.emit('state', await this.status());
    this.log(`== ${name} start`);
    try {
      const r = await fn();
      this.log(`== ${name} done`);
      return r;
    } catch (e) {
      if (e.cancelled) { this.log(`== ${name} cancelled`); this.lastError = null; } else {
        this.log(`== ${name} FAILED: ${e.stack || e.message}`);
        this.lastError = e.message;
      }
      throw e;
    } finally {
      this.busy = null;
      this.tracker = null;
      this.emit('progress', null);
      this.emit('state', await this.status().catch(() => ({})));
    }
  }

  cancel() { if (this.tracker) { this.log('cancel requested'); this.tracker.cancel(); } }

  async ensureDeps() {
    this.progress('deps', null, 'Looking for Git, Git LFS and the engine');
    let g = await this.detectGit();
    if (!g) { await this.installGit(); g = await this.detectGit(); }
    if (!g.lfs) throw new Error('Git is installed but Git LFS is missing. Reinstall Git for Windows (it includes LFS) and try again.');
    this.tracker.check();
  }

  /** First install: clone (no blobs, no checkout) -> checkout -> lfs pull -> engine -> import. */
  install() {
    return this.op('install', async () => {
      const dir = this.gameDir;
      await this.ensureDeps();
      await this.assertInstallDirUsable(dir);
      await this.checkAccess();
      this.tracker.check();
      const ch = this.channel;
      if (!fs.existsSync(path.join(dir, '.git'))) {
        await fsp.mkdir(dir, { recursive: true });
        this.progress('clone', 0, 'Contacting GitHub');
        const r = await this.gitRun(['clone', '--progress', '--filter=blob:none', '--no-checkout', '--branch', ch.branch,
          this.config.repoUrl, dir], { env: { GIT_LFS_SKIP_SMUDGE: '1' }, onLine: (l) => this.gitProgress('clone', l) });
        if (r.code !== 0) throw new Error(explainGitError(r.stderr));
      }
      if (!fs.existsSync(this.statePath())) {
        fs.writeFileSync(this.statePath(), JSON.stringify({ managedBy: 'launcher', created: new Date().toISOString() }, null, 2));
      }
      const exclude = path.join(dir, '.git', 'info', 'exclude');
      try {
        const cur = fs.existsSync(exclude) ? fs.readFileSync(exclude, 'utf8') : '';
        if (!cur.includes(MARKER)) { fs.mkdirSync(path.dirname(exclude), { recursive: true }); fs.appendFileSync(exclude, `\n/${MARKER}\n`); }
      } catch (_) { /* cosmetic */ }
      await this.gitRun(['lfs', 'install', '--local', '--skip-smudge'], { cwd: dir, check: true });
      await this.gitRun(['config', 'core.longpaths', 'true'], { cwd: dir });
      await this.syncTo(ch, { fetched: true });
    });
  }

  /** Update (or switch channel): fetch -> checkout the branch tip -> lfs pull -> import. */
  update() {
    return this.op('update', async () => {
      await this.ensureDeps();
      if (!this.isInstalled()) throw new Error('The game is not installed yet.');
      await this.assertGameClosed();
      await this.syncTo(this.channel, { fetched: false });
    });
  }

  /**
   * PREPARE: finish a setup that stopped part way (cancelled or failed after the checkout): the LFS files if they did
   * not all arrive, the engine, the headless import with progress. Much quicker than Repair (no reset, no full re-pull).
   */
  prepare() {
    return this.op('prepare', async () => {
      await this.ensureDeps(); // git is needed to read HEAD (and for the LFS files)
      if (!this.isInstalled()) throw new Error('The game is not installed yet.');
      await this.assertGameClosed();
      const dir = this.gameDir;
      const head = await this.headSha();
      if (!head) throw new Error('Could not read the installed version. Press Repair.');
      if (this.lfsIncomplete(this.readState() || {}, head)) {
        await this.lfsPull(dir);
        this.writeState({ lfsSha: head });
      }
      await this.ensureGodot();
      await this.importAssets(false);
    });
  }

  /** Repair: discard local changes to tracked files, re-pull every LFS file, re-import. */
  repair() {
    return this.op('repair', async () => {
      await this.ensureDeps();
      if (!this.isInstalled()) throw new Error('The game is not installed yet.');
      await this.assertGameClosed();
      const dir = this.gameDir;
      this.progress('repair', null, 'Checking the repository');
      const fsck = await this.gitRun(['fsck', '--connectivity-only', '--no-progress'], { cwd: dir });
      if (fsck.code !== 0) this.log('fsck reported problems: ' + lastLines(fsck.stderr));
      await this.gitRun(['reset', '--hard', 'HEAD'], { cwd: dir, env: { GIT_LFS_SKIP_SMUDGE: '1' }, check: true });
      this.writeState({ lfsSha: null, importedSha: null });
      await this.lfsPull(dir);
      this.writeState({ lfsSha: await this.headSha() });
      await this.ensureGodot();
      await this.importAssets(true);
    });
  }

  async syncTo(ch, { fetched }) {
    const dir = this.gameDir;
    if (!fetched) {
      this.progress('fetch', null, `Channel: ${ch.name}`);
      const r = await this.gitRun(['fetch', '--progress', 'origin', `+refs/heads/${ch.branch}:refs/remotes/origin/${ch.branch}`],
        { cwd: dir, env: { GIT_LFS_SKIP_SMUDGE: '1' }, onLine: (l) => this.gitProgress('fetch', l) });
      if (r.code !== 0) throw new Error(explainGitError(r.stderr));
    }
    this.tracker.check();
    await this.applyExcludes(dir);
    const target = `origin/${ch.branch}`;
    const before = await this.headSha();
    const r = await this.gitRun(['checkout', '--progress', '-f', '-B', localBranch(ch.branch), target],
      { cwd: dir, env: { GIT_LFS_SKIP_SMUDGE: '1' }, onLine: (l) => this.gitProgress('checkout', l) });
    if (r.code !== 0) throw new Error(explainGitError(r.stderr));
    const after = await this.headSha();
    this.log(`checkout ${before || '(none)'} -> ${after} (${ch.branch})`);
    // lfsSha / importedSha say which checkout finished each step: PLAY refuses a half-finished one (LFS pointer
    // files instead of models and sounds, or no import cache) and the button offers PREPARE instead.
    this.writeState({ channel: ch.id, branch: ch.branch, sha: after, updated: new Date().toISOString(), lfsSha: before === after ? (this.readState() || {}).lfsSha : null });
    await this.lfsPull(dir);
    this.writeState({ lfsSha: after });
    await this.loadFeed();
    await this.ensureGodot();
    await this.importAssets(false);
  }

  /**
   * Leaves the excluded folders out of the install: a no-cone sparse checkout (their blobs are never fetched in the
   * partial clone) plus lfs.fetchexclude. Re-applied when the list changes, which also removes them from old installs.
   */
  async applyExcludes(dir) {
    const ex = this.excludes().map((p) => p.replace(/\\/g, '/').replace(/^\/+/, ''));
    const want = ['/*', ...ex.map((p) => '!/' + p)].join('\n') + '\n';
    const file = path.join(dir, '.git', 'info', 'sparse-checkout');
    let have = null;
    try { have = fs.readFileSync(file, 'utf8'); } catch (_) { /* none yet */ }
    if (have === want) return;
    await fsp.mkdir(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, want);
    await this.gitRun(['config', 'core.sparseCheckout', ex.length ? 'true' : 'false'], { cwd: dir, check: true });
    await this.gitRun(['config', 'core.sparseCheckoutCone', 'false'], { cwd: dir });
    if (ex.length) await this.gitRun(['config', 'lfs.fetchexclude', ex.map((p) => p.replace(/\/$/, '') + '/**').join(',')], { cwd: dir, check: true });
    else await this.gitRun(['config', '--unset', 'lfs.fetchexclude'], { cwd: dir });
    this.log(`excludes: ${ex.join(', ') || '(none)'}`);
    if (await this.headSha()) {
      const r = await this.gitRun(['sparse-checkout', 'reapply'], { cwd: dir, env: { GIT_LFS_SKIP_SMUDGE: '1' } });
      if (r.code !== 0) this.log('sparse-checkout reapply: ' + lastLines(r.stderr));
    }
  }

  async lfsPull(dir) {
    // GIT_LFS_PROGRESS gets one line per file: "<direction> <n>/<total> <bytes>/<file bytes> <name>"
    const progFile = path.join(this.dataDir, 'logs', 'lfs_progress.txt');
    try { fs.writeFileSync(progFile, ''); } catch (_) { /* ignore */ }
    this.progress('lfs', 0, 'Finding the files this version needs');
    const files = new Map();
    let done = 0; let total = 0;
    const meter = new Meter();
    let pos = 0;
    const timer = setInterval(() => {
      let txt = '';
      try {
        const fd = fs.openSync(progFile, 'r');
        const size = fs.fstatSync(fd).size;
        if (size > pos) { const b = Buffer.alloc(size - pos); fs.readSync(fd, b, 0, b.length, pos); pos = size; txt = b.toString('utf8'); }
        fs.closeSync(fd);
      } catch (_) { return; }
      for (const line of txt.split(/\r?\n/)) {
        const m = /^(\w+) (\d+)\/(\d+) (\d+)\/(\d+) (.+)$/.exec(line.trim());
        if (!m) continue;
        total = Math.max(total, +m[3]);
        files.set(m[6], [+m[4], +m[5]]);
        if (+m[4] >= +m[5]) done = Math.max(done, +m[2]);
      }
      let got = 0; let want = 0;
      for (const [a, b] of files.values()) { got += a; want += b; }
      if (total) {
        const sp = meter.tick(got, 0) || {};
        this.progress('lfs', (done / total) * 100, `${done.toLocaleString()} / ${total.toLocaleString()} files · ${fmtBytes(got)}`, { speed: sp.speed });
      }
    }, 400);
    try {
      const r = await this.gitRun(['lfs', 'pull'], { cwd: dir, env: { GIT_LFS_PROGRESS: progFile }, onLine: (l) => this.log('lfs: ' + l) });
      if (r.code !== 0) throw new Error('Downloading game assets failed: ' + explainGitError(r.stderr));
    } finally { clearInterval(timer); }
  }

  async importAssets(force) {
    const st = this.readState() || {};
    const sha = await this.headSha();
    // the class cache too: without it the game cannot resolve its scripts' class names on the first start
    const importedOk = fs.existsSync(path.join(this.gameDir, '.godot', 'imported')) && fs.existsSync(path.join(this.gameDir, '.godot', 'global_script_class_cache.cfg'));
    if (!force && st.importedSha === sha && importedOk) { this.log('import: up to date'); return; }
    const exe = fs.existsSync(this.godotConsoleExe()) ? this.godotConsoleExe() : this.godotExe();
    const log = path.join(this.dataDir, 'logs', 'import_last.log');
    const first = !fs.existsSync(path.join(this.gameDir, '.godot', 'imported'));
    this.progress('import', null, first ? 'The first launch prepares every model, texture and sound. This takes a while once.' : 'Re-importing changed files');
    const state = { overall: 0, t: 0 };
    // the state says "not imported" until this import has finished, so a cancel or a crash half way never leaves a
    // checkout marked ready while the game would import (or fail) on its own first start
    this.writeState({ importedSha: null });
    const r = await this.runProc(exe, ['--headless', '--audio-driver', 'Dummy', '--path', this.gameDir, '--import', '--log-file', log], {
      tracker: this.tracker,
      idleTimeoutMs: IMPORT_IDLE_MS,
      onLine: (l) => {
        const p = importProgress(l, state);
        if (p) this.progress('import', p.pct, p.detail);
      },
    });
    this.log(`import exit ${r.code}${r.timedOut ? ' (stalled: no output for ' + IMPORT_IDLE_MS / 60000 + ' min, stopped)' : ''}`);
    if (r.timedOut) throw new Error(`Preparing assets stopped responding and was ended. Press PREPARE to try again. Log: ${log}`);
    if (isCrashCode(r.code)) throw new Error(`The engine crashed while preparing assets (${exitWords(r.code)}). Press PREPARE to try again. Log: ${log}`);
    if (!fs.existsSync(path.join(this.gameDir, '.godot', 'imported'))) {
      throw new Error(`Preparing assets failed (exit ${r.code}). See ${log}.`);
    }
    if (r.code !== 0) this.log(`import: exit ${r.code} with an import cache in place; accepted (see ${log})`);
    this.writeState({ importedSha: sha, importedAt: new Date().toISOString() });
  }

  gitProgress(step, line) {
    // "Receiving objects:  45% (1234/5678), 12.00 MiB | 3.00 MiB/s" / "Updating files:  60% (..)" / "Resolving deltas: .."
    const m = /^(?:remote:\s*)?([A-Za-z ]+):\s+(\d+)%\s*\(([\d/]+)\)(?:,\s*([\d.]+ \w+))?(?:\s*\|\s*([\d.]+ \w+\/s))?/.exec(line);
    if (!m) { if (!/^remote: (Enumerating|Counting|Compressing|Total)/.test(line)) this.log(`git: ${line}`); return; }
    const phase = m[1].trim();
    const weights = { 'Receiving objects': [0, 85], 'Resolving deltas': [85, 100], 'Updating files': [0, 100], 'Counting objects': [0, 5], 'Compressing objects': [0, 5] };
    const w = weights[phase] || [0, 100];
    const pct = w[0] + ((w[1] - w[0]) * +m[2]) / 100;
    const detail = [phase, m[3], m[4]].filter(Boolean).join(' · ');
    this.progress(step, pct, detail, m[5] ? { speedText: m[5].replace('i', '') } : {});
  }

  // ---------- information ----------
  async headSha() {
    if (!fs.existsSync(path.join(this.gameDir, '.git'))) return null;
    const r = await this.gitRun(['rev-parse', 'HEAD'], { cwd: this.gameDir }).catch(() => null);
    return r && r.code === 0 ? r.stdout.trim() : null;
  }

  /** Fetches the channel quietly and reports whether an update is waiting (and the commits it brings). */
  checkForUpdate() {
    return this.op('check', async () => {
      if (!(await this.detectGit())) return { available: false };
      if (!this.isInstalled()) {
        this.remoteSha = await this.checkAccess().catch((e) => { this.log('access: ' + e.message); return null; });
        return { available: false };
      }
      const ch = this.channel;
      this.progress('fetch', null, `Channel: ${ch.name}`);
      const r = await this.gitRun(['fetch', 'origin', `+refs/heads/${ch.branch}:refs/remotes/origin/${ch.branch}`],
        { cwd: this.gameDir, env: { GIT_LFS_SKIP_SMUDGE: '1' } });
      if (r.code !== 0) { this.lastError = explainGitError(r.stderr); throw new Error(this.lastError); }
      await this.loadFeed();
      const rs = await this.gitRun(['rev-parse', `origin/${ch.branch}`], { cwd: this.gameDir });
      this.remoteSha = rs.code === 0 ? rs.stdout.trim() : null;
      return { available: this.remoteSha && this.remoteSha !== (await this.headSha()) };
    });
  }

  /** Commits (first parent) for the patch-notes panel: incoming ones if an update waits, else the latest installed. */
  async patchNotes(limit = 40) {
    if (!this.git || !this.isInstalled()) return { incoming: [], recent: [] };
    const ch = this.channel;
    const fmt = '--format=%H%x1f%an%x1f%aI%x1f%s%x1e';
    const parse = (out) => out.split('\x1e').map((r) => r.trim()).filter(Boolean).map((r) => {
      const [sha, author, date, subject] = r.split('\x1f');
      return { sha, author, date, subject };
    });
    const inc = await this.gitRun(['log', '--first-parent', '-n', String(limit), fmt, `HEAD..origin/${ch.branch}`], { cwd: this.gameDir });
    const rec = await this.gitRun(['log', '--first-parent', '-n', String(limit), fmt, 'HEAD'], { cwd: this.gameDir });
    return { incoming: inc.code === 0 ? parse(inc.stdout) : [], recent: rec.code === 0 ? parse(rec.stdout) : [] };
  }

  /** launcher/feed.json from the fetched channel branch (falls back to the installed tree, then the bundled copy). */
  async loadFeed(bundled) {
    if (bundled) this.bundledFeed = bundled;
    let feed = null;
    if (this.git && this.isInstalled()) {
      for (const ref of [`origin/${this.channel.branch}`, 'HEAD']) {
        const r = await this.gitRun(['show', `${ref}:launcher/feed.json`], { cwd: this.gameDir }).catch(() => null);
        if (r && r.code === 0) { try { feed = JSON.parse(r.stdout); feed._source = ref; break; } catch (_) { /* bad json */ } }
      }
    }
    this.feed = feed || this.bundledFeed || null;
    return this.feed;
  }

  async status() {
    const installed = this.isInstalled();
    const st = installed ? this.readState() : null;
    const head = installed && this.git ? await this.headSha() : null;
    const ch = this.channel;
    return {
      busy: this.busy,
      installed,
      gameDir: this.gameDir,
      channel: ch,
      channels: this.channels(),
      head,
      remote: this.remoteSha,
      onChannel: !!(st && st.branch === ch.branch),
      updateAvailable: !!(installed && ((this.remoteSha && head && this.remoteSha !== head) || (st && st.branch !== ch.branch))),
      needsImport: !!(installed && head && (!st || st.importedSha !== head || !fs.existsSync(path.join(this.gameDir, '.godot', 'imported')))),
      needsFiles: !!(installed && head && this.lfsIncomplete(st || {}, head)),
      game: this.game ? { pid: this.game.pid, since: this.game.started, windowSeen: !!this.game.windowSeen } : null,
      engineReady: fs.existsSync(this.godotExe()),
      godotVersion: this.godotVersion(),
      lastError: this.lastError,
      updated: st && st.updated,
    };
  }

  // ---------- play ----------
  gameLogDir() { return this.gameLogDirOverride || path.join(this.gameDir, 'logs'); }
  playLogPath() { return path.join(this.dataDir, 'logs', 'launcher_play.log'); }

  /** LFS files for the checked-out commit did not all arrive (old installs without lfsSha: the import implies them). */
  lfsIncomplete(st, head) {
    if (!head) return false;
    if ('lfsSha' in st) return st.lfsSha !== head;
    return st.importedSha !== head;
  }

  /**
   * The engine processes started from the launcher's own engine copy (the game, or an import a crashed launcher left
   * behind). Windows only; matched by the exe's folder, so a developer's Godot elsewhere never counts.
   */
  async findGame() {
    if (this.findGameImpl) return this.findGameImpl();
    if (this.platform !== 'win32') return [];
    const exe = this.godotExe();
    const name = path.basename(exe, '.exe');
    const ps = `Get-Process -Name '${psq(name)}*' -ErrorAction SilentlyContinue | Where-Object { $_.Path -and (Split-Path $_.Path -Parent) -ieq '${psq(path.dirname(exe))}' } | ForEach-Object { $_.Id }`;
    try {
      const r = await run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', ps]);
      return r.stdout.split(/\s+/).map(Number).filter((n) => n > 0);
    } catch (_) { return []; }
  }

  gameAlive() { return !!(this.game && !this.game.exited); }

  async assertGameClosed() {
    const pids = this.gameAlive() ? [this.game.pid] : await this.findGame();
    if (pids.length) {
      throw codedError('running', 'The game is still running. Close it first: files change under a running game.', { pids, action: 'focus' });
    }
  }

  /** The engine arguments for PLAY (pure apart from the settings; tests/check.js covers it). */
  playArgs({ safe = false } = {}) {
    const s = this.getSettings();
    const extra = splitArgs(s.extraArgs || '');
    const dd = extra.indexOf('--');
    let engineExtra = dd >= 0 ? extra.slice(0, dd) : extra;
    const userArgs = dd >= 0 ? extra.slice(dd) : [];
    const safeMode = !!(safe || s.safeMode);
    if (safeMode) engineExtra = dropOption(engineExtra, '--render-thread');
    const ownThread = engineExtra.some((a) => a === '--render-thread' || a.startsWith('--render-thread='));
    const args = ['--path', this.gameDir, '--log-file', path.join(this.gameLogDir(), 'game_last.log')];
    // T-289 (the lead's decision): the renderer on its own thread like Play.bat (T-258: 66 -> 92 FPS), Windows only;
    // Settings > Safe mode, or "Start in safe mode" after a crash, leaves it out.
    if (this.platform === 'win32' && !safeMode && !ownThread) args.push('--render-thread', 'separate');
    if (s.renderingDriver && s.renderingDriver !== 'auto' && !engineExtra.includes('--rendering-driver')) args.push('--rendering-driver', s.renderingDriver);
    if (s.fullscreen && !engineExtra.includes('--fullscreen')) args.push('--fullscreen');
    args.push(...engineExtra, this.mainScene(), ...userArgs);
    const i = args.indexOf('--render-thread');
    const renderThread = (i >= 0 && !['safe', 'single'].includes(args[i + 1])) || args.some((a) => /^--render-thread=(separate|unsafe)/.test(a));
    return { args, renderThread, safeMode };
  }

  /** Why PLAY cannot start right now, as { code, message, action, pids? } (null: it can). */
  async playProblem() {
    if (this.busy && this.busy !== 'check') {
      return { code: 'busy', action: null, message: `Wait until the ${OP_WORDS[this.busy] || this.busy} finishes. The game cannot start while its files are changing.` };
    }
    if (!this.isInstalled()) return { code: 'not_installed', action: 'install', message: 'The game is not installed yet.' };
    if (this.gameAlive()) return { code: 'running', action: 'focus', pids: [this.game.pid], message: 'The game is already running.' };
    const pids = await this.findGame();
    if (pids.length) return { code: 'running', action: 'focus', pids, message: 'The game is already running (started earlier). Switch to it, or end it and start again.' };
    if (!fs.existsSync(this.godotExe())) return { code: 'engine', action: 'prepare', message: 'The game engine is missing. PREPARE downloads it again.' };
    if (!this.git) await this.detectGit().catch(() => null); // the update check may not have run (Settings)
    const head = await this.headSha();
    const st = this.readState() || {};
    const dotGodot = path.join(this.gameDir, '.godot');
    if (!head) {
      // no git to read the version with: do not block PLAY on what cannot be checked, only on a missing import
      if (!fs.existsSync(path.join(dotGodot, 'imported'))) return { code: 'import', action: 'prepare', message: 'The assets are not prepared yet. PREPARE does it now with a progress bar.' };
      return null;
    }
    if (this.lfsIncomplete(st, head)) {
      return { code: 'files', action: 'prepare', message: 'Some game files did not finish downloading (the last update stopped part way). PREPARE downloads the rest.' };
    }
    if (st.importedSha !== head || !fs.existsSync(path.join(dotGodot, 'imported'))) {
      return { code: 'import', action: 'prepare', message: 'The assets for this version are not prepared yet. PREPARE does it now with a progress bar (otherwise the game would do it silently on its first start and look stuck).' };
    }
    return null;
  }

  /**
   * Starts the game. Resolves { pid, renderThread, safeMode } once the process exists; rejects with a coded error when
   * it cannot start. The game is detached (it outlives the launcher) and writes stdout/stderr into
   * logs/launcher_play.log through an inherited file handle; while the launcher runs it watches the exit code and
   * emits 'game' events: starting, running (window seen), failed (an early exit, with the last log lines), exited.
   */
  async play(opts = {}) {
    const problem = await this.playProblem();
    if (problem) throw codedError(problem.code, problem.message, { action: problem.action, pids: problem.pids });
    const exe = this.godotExe();
    const { args, renderThread, safeMode } = this.playArgs(opts);
    const logDir = this.gameLogDir();
    await fsp.mkdir(logDir, { recursive: true });
    rotateGameLogs(logDir, GAME_LOGS_KEPT);
    const gameLog = path.join(logDir, 'game_last.log');
    const playLog = this.playLogPath();
    rotateFile(playLog, PLAY_LOG_MAX, 3);
    fs.appendFileSync(playLog, `\n===== ${new Date().toISOString()} PLAY${safeMode ? ' (safe mode)' : ''}\nexe:  ${exe}\ncwd:  ${this.gameDir}\nargs: ${JSON.stringify(args)}\n`);
    const startOffset = fs.statSync(playLog).size;
    this.log(`play: ${exe} ${args.map(quoteArg).join(' ')}`);
    const fd = fs.openSync(playLog, 'a');
    let child;
    try {
      child = this.spawn(exe, args, { cwd: this.gameDir, detached: true, stdio: ['ignore', fd, fd], windowsHide: false });
      await new Promise((resolve, reject) => {
        child.once('spawn', resolve);
        child.once('error', reject);
      });
    } catch (e) {
      const msg = spawnErrorWords(e, exe);
      try { fs.appendFileSync(playLog, `could not start: ${e.code || ''} ${e.message}\n`); } catch (_) { /* ignore */ }
      this.log(`play FAILED: ${e.code || ''} ${e.message}`);
      throw codedError('spawn', msg, { action: 'repair' });
    } finally {
      try { fs.closeSync(fd); } catch (_) { /* the child keeps its own handle */ }
    }
    child.on('error', (e) => this.log('game process error: ' + e.message)); // never an unhandled 'error' event
    const g = { pid: child.pid, started: Date.now(), args, renderThread, safeMode, playLog, gameLog, startOffset, exited: false, windowSeen: false };
    g.exitPromise = new Promise((resolve) => child.once('exit', (code, signal) => { this.onGameExit(g, code, signal); resolve(g); }));
    this.game = g;
    child.unref();
    this.emit('game', { state: 'starting', pid: g.pid, renderThread, safeMode });
    this.emit('state', await this.status().catch(() => ({})));
    return { pid: g.pid, renderThread, safeMode };
  }

  onGameExit(g, code, signal) {
    g.exited = true;
    g.code = code;
    const secs = (Date.now() - g.started) / 1000;
    try { fs.appendFileSync(g.playLog, `===== exit ${code == null ? 'signal ' + signal : code}${code ? ' (' + exitWords(code) + ')' : ''} after ${secs.toFixed(1)} s\n`); } catch (_) { /* ignore */ }
    this.log(`game pid ${g.pid} exit ${code == null ? signal : code} after ${secs.toFixed(1)} s`);
    if (this.game === g) this.game = null;
    const early = secs * 1000 < this.earlyExitMs;
    if (early && !g.endedByLauncher && (code !== 0 || !g.windowSeen)) {
      const output = tailLines(readFrom(g.playLog, g.startOffset), 12).filter((l) => !/^===== exit/.test(l));
      const gameLines = tailLines(readFrom(g.gameLog, 0), 20);
      this.emit('game', {
        state: 'failed', pid: g.pid, code, seconds: Math.round(secs * 10) / 10, reason: exitWords(code),
        lines: gameLines.length ? gameLines : output, output, offerSafe: !!g.renderThread,
        logFile: g.gameLog, playLog: g.playLog,
      });
    } else {
      this.emit('game', { state: 'exited', pid: g.pid, code, seconds: Math.round(secs) });
    }
    this.status().then((st) => this.emit('state', st)).catch(() => {});
  }

  /**
   * Waits until the started game shows its window (Windows: MainWindowHandle), exits, or WINDOW_WAIT_MS pass.
   * The launcher stays in front until then: minimizing at once handed the foreground to another program before the
   * game made its window, so Windows could open the game behind it (the "nothing happened, press PLAY again" start).
   */
  async waitForWindow(pid, timeoutMs = WINDOW_WAIT_MS) {
    const g = this.game && this.game.pid === pid ? this.game : null;
    if (!g) return 'exited';
    if (this.platform !== 'win32' || this.findGameImpl) {
      // no window probe off Windows (or in tests): a short wait, the early-exit watch covers the rest
      return Promise.race([g.exitPromise.then(() => 'exited'), delay(Math.min(timeoutMs, 1500)).then(() => 'timeout')]);
    }
    const ps = `$t=[DateTime]::Now.AddMilliseconds(${Math.round(timeoutMs)}); while([DateTime]::Now -lt $t){ $p=Get-Process -Id ${Number(pid)} -ErrorAction SilentlyContinue; if(-not $p){'exited'; exit}; if($p.MainWindowHandle -ne 0){'window'; exit}; Start-Sleep -Milliseconds 400 }; 'timeout'`;
    const probe = run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', ps])
      .then((r) => r.stdout.trim().split(/\s+/).pop() || 'timeout').catch(() => 'timeout');
    const r = await Promise.race([probe, g.exitPromise.then(() => 'exited')]);
    if (r === 'window') { g.windowSeen = true; this.emit('game', { state: 'running', pid }); }
    this.log(`game pid ${pid}: ${r === 'window' ? 'window shown' : r} after ${((Date.now() - g.started) / 1000).toFixed(1)} s`);
    return r;
  }

  /** Resolves true if the game outlived the early-exit window (checked before "close the launcher after PLAY"). */
  async survivesStart(pid) {
    const g = this.game && this.game.pid === pid ? this.game : null;
    if (!g) return false;
    const left = this.earlyExitMs - (Date.now() - g.started);
    const r = await Promise.race([g.exitPromise.then(() => false), delay(Math.max(0, left)).then(() => true)]);
    return r && !g.exited;
  }

  /** "Switch to it" / "End it" for a game that is already running. Only engine processes from the launcher's copy. */
  async gameAction(what, pids) {
    const ours = new Set(await this.findGame());
    if (this.gameAlive()) ours.add(this.game.pid);
    const list = (Array.isArray(pids) ? pids : []).map(Number).filter((p) => ours.has(p));
    if (!list.length) return false;
    if (what === 'focus') {
      if (this.platform !== 'win32') return false;
      const ps = `$w=New-Object -ComObject WScript.Shell; ${list.map((p) => `if($w.AppActivate(${p})){'ok'}`).join('; ')}`;
      const r = await run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', ps]).catch(() => ({ stdout: '' }));
      return /ok/.test(r.stdout);
    }
    if (what === 'end') {
      if (this.gameAlive() && list.includes(this.game.pid)) this.game.endedByLauncher = true;
      for (const p of list) {
        this.log(`ending game pid ${p} (the player asked)`);
        if (this.platform === 'win32') await run('taskkill', ['/PID', String(p), '/T', '/F']).catch(() => null);
        else { try { process.kill(p); } catch (_) { /* gone */ } }
      }
      return true;
    }
    return false;
  }

  /** A channel or folder change while files are being written would mix two versions: refused until it is done. */
  assertSettingsChange(patch, current) {
    if (!patch || !this.busy || this.busy === 'check') return;
    for (const k of ['channel', 'installDir']) {
      if (k in patch && patch[k] !== current[k]) {
        throw codedError('busy', `Wait until the ${OP_WORDS[this.busy] || this.busy} finishes (or press Cancel) before changing the ${k === 'channel' ? 'channel' : 'install folder'}.`);
      }
    }
  }

  async uninstall() {
    if (this.busy) throw new Error(`Busy: ${this.busy}`);
    await this.assertGameClosed();
    if (!this.isInstalled()) return;
    const dir = this.gameDir;
    if (!fs.existsSync(path.join(dir, MARKER))) throw new Error('This folder was not installed by the launcher; not deleting it.');
    this.log(`uninstall: removing ${dir}`);
    await fsp.rm(dir, { recursive: true, force: true, maxRetries: 3 });
  }

  /** Never install into (and later reset --hard) a folder the launcher does not own, e.g. a developer's working copy. */
  async assertInstallDirUsable(dir) {
    if (!fs.existsSync(dir)) return;
    const entries = await fsp.readdir(dir);
    if (entries.length === 0) return;
    if (entries.includes(MARKER)) return;
    throw new Error(`The install folder ${dir} is not empty. Pick an empty folder in Settings (the launcher never touches folders it did not create).`);
  }
}

// ---------- module helpers ----------
// The headless editor prints "[ 42% ] <task> | <item>" (with ANSI colours). Its top-level tasks run in this order;
// each gets a slice of one overall bar. Nested tasks (one per imported scene) only change the detail text.
const IMPORT_PHASES = { first_scan_filesystem: [0, 4], update_scripts_classes: [4, 12], _update_scan_actions: [12, 25], reimport: [25, 100] };
function importProgress(line, state) {
  const clean = String(line).replace(/\x1b\[[0-9;]*m/g, '');
  const m = /^\[\s*(\d+)%\s*\]\s*([^|]+?)\s*\|\s*(.*)$/.exec(clean.trim());
  if (!m) return null;
  const w = IMPORT_PHASES[m[2]];
  if (w) state.overall = Math.max(state.overall, w[0] + ((w[1] - w[0]) * +m[1]) / 100);
  const now = Date.now();
  if (now - state.t < 200) return null;
  state.t = now;
  const detail = m[3].replace(/^Started\s+/, '').replace(/\s*\(\d+ steps\)$/, '').replace(/\.\.\.$/, '').trim();
  return { pct: state.overall, detail: detail.slice(0, 90) };
}

// ---------- T-289 play helpers ----------
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
/** A single-quoted PowerShell string's inside. */
function psq(s) { return String(s).replace(/'/g, "''"); }
function quoteArg(a) { return /[\s"]/.test(a) ? `"${a.replace(/"/g, '\\"')}"` : a; }
/** Removes an option and its value ("--render-thread separate" or "--render-thread=separate"). */
function dropOption(list, name) {
  const out = [];
  for (let i = 0; i < list.length; i++) {
    if (list[i] === name) { if (list[i + 1] != null && !String(list[i + 1]).startsWith('-')) i++; continue; }
    if (String(list[i]).startsWith(name + '=')) continue;
    out.push(list[i]);
  }
  return out;
}
/** Windows exit codes a player can act on, in words. */
function exitWords(code) {
  if (code == null) return 'ended by the system';
  const u = code >>> 0;
  const known = {
    0: 'closed normally', 1: 'stopped with an error',
    0xC0000005: 'crashed (access violation)', 0xC0000409: 'crashed (stack buffer overrun)', 0xC00000FD: 'crashed (stack overflow)',
    0xC0000135: 'a system file (DLL) is missing', 0xC000001D: 'this processor lacks an instruction the engine needs',
    0xC0000142: 'could not initialise (a DLL failed to load)', 0xC0000017: 'out of memory', 0x40010004: 'ended by another program',
    0xC000013A: 'closed with Ctrl+C', 0xC0000374: 'crashed (heap corruption)', 0x87A: 'the graphics driver failed',
  };
  if (known[u]) return known[u];
  return u >= 0xC0000000 ? `crashed (0x${u.toString(16).toUpperCase()})` : `exit code ${code}`;
}
function isCrashCode(code) { return code == null || (code >>> 0) >= 0xC0000000; }
function spawnErrorWords(e, exe) {
  const c = e && e.code;
  if (c === 'ENOENT') return `The game engine was not found (${path.basename(exe)}). Press Repair to download it again.`;
  if (c === 'EACCES' || c === 'EPERM') return 'Windows refused to start the game engine. Your antivirus may have blocked or quarantined it: allow it there (or restore it), then press PLAY again. Repair downloads a fresh copy.';
  if (c === 'UNKNOWN' || c === 'EBUSY') return 'Windows could not start the game engine (it may be locked by an antivirus scan or blocked by Smart App Control). Wait a moment and press PLAY again; if it keeps failing, press Repair.';
  return `The game could not start: ${(e && e.message) || e}`;
}
/** Text of a file from byte offset `from` (at most the last 64 KB of it). */
function readFrom(file, from) {
  try {
    const fd = fs.openSync(file, 'r');
    try {
      const size = fs.fstatSync(fd).size;
      const start = Math.max(from || 0, size - 65536);
      if (size <= start) return '';
      const b = Buffer.alloc(size - start);
      fs.readSync(fd, b, 0, b.length, start);
      return b.toString('utf8');
    } finally { fs.closeSync(fd); }
  } catch (_) { return ''; }
}
function tailLines(text, n) {
  return String(text || '').replace(/\x1b\[[0-9;]*m/g, '').split(/\r?\n/).map((l) => l.replace(/\s+$/, '')).filter((l) => l.trim()).slice(-n);
}
/** file -> file.1 -> file.2 ... (keeping `keep`) once it is larger than maxBytes. */
function rotateFile(file, maxBytes, keep) {
  try {
    if (fs.statSync(file).size <= maxBytes) return false;
  } catch (_) { return false; }
  try { fs.rmSync(`${file}.${keep}`, { force: true }); } catch (_) { /* ignore */ }
  for (let i = keep - 1; i >= 1; i--) {
    try { fs.renameSync(`${file}.${i}`, `${file}.${i + 1}`); } catch (_) { /* none */ }
  }
  try { fs.renameSync(file, `${file}.1`); } catch (_) { return false; }
  return true;
}
/** Keeps the previous starts' logs: game_last.log -> game_<its time>.log, the newest `keep` files in all. */
function rotateGameLogs(dir, keep) {
  const last = path.join(dir, 'game_last.log');
  try {
    const st = fs.statSync(last);
    const stamp = new Date(st.mtimeMs).toISOString().replace(/[:]/g, '-').replace(/\..*$/, '');
    let dest = path.join(dir, `game_${stamp}.log`);
    for (let i = 2; fs.existsSync(dest); i++) dest = path.join(dir, `game_${stamp}_${i}.log`);
    fs.renameSync(last, dest);
  } catch (_) { /* no previous log, or it is open in another game */ }
  try {
    const old = fs.readdirSync(dir).filter((f) => /^game_\d{4}-.*\.log$/.test(f)).sort().reverse();
    for (const f of old.slice(Math.max(0, keep - 1))) fs.rmSync(path.join(dir, f), { force: true });
  } catch (_) { /* ignore */ }
}

function localBranch(b) { return 'launcher/' + b.replace(/[^\w./-]/g, '_'); }

function existingParent(p) {
  let cur = path.resolve(p);
  while (!fs.existsSync(cur)) { const up = path.dirname(cur); if (up === cur) break; cur = up; }
  return cur;
}

let wingetCache = null;
async function hasWinget() {
  if (process.platform !== 'win32') return false;
  if (wingetCache != null) return wingetCache;
  try { wingetCache = (await run('winget', ['--version'])).code === 0; } catch (_) { wingetCache = false; }
  return wingetCache;
}

function explainGitError(stderr) {
  const s = String(stderr || '');
  if (/Repository not found|HTTP 40[13]|error: 40[13]|returned error: 40[13]|Permission denied|could not read Username|Authentication failed|terminal prompts disabled/i.test(s)) {
    return 'GitHub refused access. Sign in with the GitHub account the owner invited (Settings > Switch GitHub account), and accept the invitation e-mail first.';
  }
  if (/Could not resolve host|unable to access|timed out|Failed to connect|SSL/i.test(s)) {
    return 'Could not reach GitHub. Check your internet connection and try again.';
  }
  if (/No space left|not enough space|disk full/i.test(s)) return 'The disk is full. Free some space or pick another install folder.';
  if (/Filename too long/i.test(s)) return 'A file path is too long for Windows. Pick a shorter install folder (for example C:\\Games\\ClaudeZombies).';
  return lastLines(s) || 'Git failed with no message.';
}

function splitArgs(s) {
  const out = []; const re = /"([^"]*)"|(\S+)/g; let m;
  while ((m = re.exec(s))) out.push(m[1] != null ? m[1] : m[2]);
  return out;
}

async function httpJson(url) {
  const r = await fetch(url, { headers: { 'User-Agent': 'game-launcher', Accept: 'application/vnd.github+json' } });
  if (!r.ok) throw new Error(`${url}: HTTP ${r.status}`);
  return r.json();
}
async function httpText(url) {
  const r = await fetch(url, { headers: { 'User-Agent': 'game-launcher' }, redirect: 'follow' });
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  return r.text();
}
function sha512(file) {
  return new Promise((res, rej) => {
    const h = crypto.createHash('sha512');
    fs.createReadStream(file).on('data', (d) => h.update(d)).on('end', () => res(h.digest('hex'))).on('error', rej);
  });
}
function fmtBytes(n) {
  if (!n) return '0 B';
  const u = ['B', 'KB', 'MB', 'GB']; let i = 0;
  while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
  return `${n.toFixed(i >= 2 ? 1 : 0)} ${u[i]}`;
}
/** Smoothed transfer speed + ETA, throttled to ~4 updates/s. */
class Meter {
  constructor() { this.t0 = Date.now(); this.last = 0; this.samples = []; }
  tick(got, total) {
    const now = Date.now();
    if (now - this.last < 250) return null;
    this.last = now;
    this.samples.push([now, got]);
    while (this.samples.length > 2 && now - this.samples[0][0] > 5000) this.samples.shift();
    const [t, g] = this.samples[0];
    const speed = now > t ? ((got - g) * 1000) / (now - t) : 0;
    const eta = speed > 0 && total ? (total - got) / speed : null;
    return { speed, eta };
  }
}

module.exports = { GameManager, fmtBytes, explainGitError, importProgress, STEP_NAMES, MARKER, splitArgs, exitWords, rotateFile, rotateGameLogs, tailLines };
