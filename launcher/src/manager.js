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
const { run, Tracker, Cancelled, lastLines } = require('./proc');

const MARKER = '.launcher-managed';
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
};

class GameManager {
  /**
   * @param {object} o
   * @param {string} o.dataDir     launcher data root (godot/, logs/)
   * @param {object} o.config      config.json contents
   * @param {function} o.getSettings  () => settings object (installDir, channel, ...)
   * @param {function} o.emit      (event, payload) => void   events: progress, log, state
   */
  constructor(o) {
    this.dataDir = o.dataDir;
    this.config = o.config;
    this.getSettings = o.getSettings;
    this.emit = o.emit || (() => {});
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
    if (this.busy) throw new Error(`Busy: ${this.busy}`);
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
      await this.syncTo(this.channel, { fetched: false });
    });
  }

  /** Repair: discard local changes to tracked files, re-pull every LFS file, re-import. */
  repair() {
    return this.op('repair', async () => {
      await this.ensureDeps();
      if (!this.isInstalled()) throw new Error('The game is not installed yet.');
      const dir = this.gameDir;
      this.progress('repair', null, 'Checking the repository');
      const fsck = await this.gitRun(['fsck', '--connectivity-only', '--no-progress'], { cwd: dir });
      if (fsck.code !== 0) this.log('fsck reported problems: ' + lastLines(fsck.stderr));
      await this.gitRun(['reset', '--hard', 'HEAD'], { cwd: dir, env: { GIT_LFS_SKIP_SMUDGE: '1' }, check: true });
      await this.lfsPull(dir);
      this.writeState({ importedSha: null });
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
    this.writeState({ channel: ch.id, branch: ch.branch, sha: after, updated: new Date().toISOString() });
    await this.lfsPull(dir);
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
    const importedOk = fs.existsSync(path.join(this.gameDir, '.godot', 'imported'));
    if (!force && st.importedSha === sha && importedOk) { this.log('import: up to date'); return; }
    const exe = fs.existsSync(this.godotConsoleExe()) ? this.godotConsoleExe() : this.godotExe();
    const log = path.join(this.dataDir, 'logs', 'import_last.log');
    const first = !importedOk;
    this.progress('import', null, first ? 'The first launch prepares every model, texture and sound. This takes a while once.' : 'Re-importing changed files');
    const state = { overall: 0, t: 0 };
    const r = await run(exe, ['--headless', '--audio-driver', 'Dummy', '--path', this.gameDir, '--import', '--log-file', log], {
      tracker: this.tracker,
      onLine: (l) => {
        const p = importProgress(l, state);
        if (p) this.progress('import', p.pct, p.detail);
      },
    });
    this.log(`import exit ${r.code}`);
    if (!fs.existsSync(path.join(this.gameDir, '.godot', 'imported'))) {
      throw new Error(`Preparing assets failed (exit ${r.code}). See ${log}.`);
    }
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
      needsImport: !!(installed && head && (!st || st.importedSha !== head)),
      engineReady: fs.existsSync(this.godotExe()),
      godotVersion: this.godotVersion(),
      lastError: this.lastError,
      updated: st && st.updated,
    };
  }

  // ---------- play ----------
  async play() {
    if (this.busy) throw new Error(`Busy: ${this.busy}`);
    const s = this.getSettings();
    const exe = this.godotExe();
    if (!fs.existsSync(exe)) throw new Error('The engine is missing. Press Repair.');
    const logs = path.join(this.gameDir, 'logs');
    await fsp.mkdir(logs, { recursive: true });
    const args = ['--path', this.gameDir, '--log-file', path.join(logs, 'game_last.log')];
    if (s.renderingDriver && s.renderingDriver !== 'auto') args.push('--rendering-driver', s.renderingDriver);
    if (s.fullscreen) args.push('--fullscreen');
    if (s.extraArgs) args.push(...splitArgs(s.extraArgs));
    args.push(this.mainScene());
    this.log(`play: ${exe} ${args.join(' ')}`);
    const { spawn } = require('child_process');
    const child = spawn(exe, args, { cwd: this.gameDir, detached: true, stdio: 'ignore' });
    child.unref();
    return child.pid;
  }

  async uninstall() {
    if (this.busy) throw new Error(`Busy: ${this.busy}`);
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

module.exports = { GameManager, fmtBytes, explainGitError, importProgress, STEP_NAMES, MARKER };
