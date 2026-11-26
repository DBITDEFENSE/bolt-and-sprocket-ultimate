'use strict';
// Offline checks of the launcher core: node tests/check.js   (exit code = failures)
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { GameManager, explainGitError, importProgress, MARKER } = require('../src/manager');
const Feed = require('../renderer/feed'); // the renderer's feed logic (plain functions, shared with the page)

/** Width and height of a JPEG, from its start-of-frame marker. */
function jpegSize(buf) {
  let i = 2;
  while (i < buf.length) {
    if (buf[i] !== 0xff) { i++; continue; }
    const marker = buf[i + 1];
    if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) return [buf.readUInt16BE(i + 7), buf.readUInt16BE(i + 5)];
    i += 2 + buf.readUInt16BE(i + 2);
  }
  throw new Error('no JPEG frame header');
}

let fails = 0;
const t = async (name, fn) => { try { await fn(); console.log('ok   ' + name); } catch (e) { fails++; console.log('FAIL ' + name + '\n     ' + e.message); } };
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'czl-'));
const config = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config.json'), 'utf8'));
const events = [];
const settings = { installDir: path.join(tmp, 'game'), channel: 'stable' };
const m = new GameManager({ dataDir: path.join(tmp, 'data'), config, getSettings: () => settings, emit: (e, p) => events.push([e, p]) });

(async () => {
  await t('git progress: receiving objects maps to 0-85% with speed', () => {
    events.length = 0;
    m.gitProgress('clone', 'Receiving objects:  50% (500/1000), 12.00 MiB | 3.00 MiB/s');
    const p = events.find((e) => e[0] === 'progress')[1];
    assert.strictEqual(Math.round(p.pct), 43);
    assert.strictEqual(p.speedText, '3.00 MB/s');
    assert.match(p.detail, /Receiving objects · 500\/1000 · 12.00 MiB/);
  });
  await t('git progress: updating files is 0-100%', () => {
    events.length = 0;
    m.gitProgress('checkout', 'Updating files:  60% (9269/15447)');
    assert.strictEqual(events.find((e) => e[0] === 'progress')[1].pct, 60);
  });
  await t('git progress: noise lines are logged, not shown', () => {
    events.length = 0;
    m.gitProgress('clone', "Cloning into 'x'...");
    assert.ok(!events.some((e) => e[0] === 'progress'));
  });
  await t('errors: auth, network, long paths', () => {
    assert.match(explainGitError('remote: Repository not found.\nfatal: repository ... not found'), /GitHub refused access/);
    assert.match(explainGitError('fatal: unable to access ...: Could not resolve host: github.com'), /internet/);
    assert.match(explainGitError('error: unable to create file x: Filename too long'), /shorter install folder/);
    assert.doesNotMatch(explainGitError("error: pathspec 'x' did not match"), /refused/);
  });
  await t('import progress: one rising bar across the editor tasks, colours stripped', () => {
    const st = { overall: 0, t: 0 };
    const lines = fs.readFileSync(path.join(__dirname, 'fixtures', 'import_sample.log'), 'utf8').split(/\r?\n/);
    let last = -1; let seen = 0;
    for (const l of lines) {
      st.t = 0; // no throttling in the test
      const p = importProgress(l, st);
      if (!p) continue;
      seen++;
      assert.ok(p.pct >= last, `went back: ${p.pct} < ${last} at ${l}`);
      assert.ok(!/\x1b|\[\d+m/.test(p.detail), 'ANSI left in ' + p.detail);
      last = p.pct;
    }
    assert.ok(seen > 10, 'parsed ' + seen);
    assert.ok(last > 25, 'reached the reimport phase: ' + last);
    assert.strictEqual(importProgress('[  16% ] first_scan_filesystem | Loading global class names...\x1b[39m\x1b[0m', { overall: 0, t: 0 }).detail, 'Loading global class names');
  });
  await t('install dir: missing or empty is fine', async () => {
    await m.assertInstallDirUsable(path.join(tmp, 'nope'));
    fs.mkdirSync(path.join(tmp, 'empty'));
    await m.assertInstallDirUsable(path.join(tmp, 'empty'));
  });
  await t('install dir: a foreign non-empty folder (a dev checkout) is refused', async () => {
    const d = path.join(tmp, 'devrepo'); fs.mkdirSync(path.join(d, '.git'), { recursive: true });
    await assert.rejects(m.assertInstallDirUsable(d), /not empty/);
  });
  await t('install dir: a launcher-managed folder is accepted', async () => {
    const d = path.join(tmp, 'mine'); fs.mkdirSync(d); fs.writeFileSync(path.join(d, MARKER), '{}');
    await m.assertInstallDirUsable(d);
  });
  await t('uninstall refuses a folder without the marker', async () => {
    settings.installDir = path.join(tmp, 'devrepo');
    fs.writeFileSync(path.join(tmp, 'devrepo', MARKER), '{}'); // isInstalled true...
    fs.rmSync(path.join(tmp, 'devrepo', MARKER));               // ...then not ours
    await m.uninstall(); // not installed -> no-op, folder stays
    assert.ok(fs.existsSync(path.join(tmp, 'devrepo', '.git')));
    settings.installDir = path.join(tmp, 'game');
  });
  await t('channels: feed overrides config, unknown channel falls back to default', async () => {
    settings.channel = 'bogus';
    assert.strictEqual(m.channel.id, config.defaultChannel);
    m.feed = { channels: [{ id: 'x', name: 'X', branch: 'x' }] };
    assert.strictEqual(m.channel.id, 'x');
    m.feed = null; settings.channel = 'stable';
  });
  await t('feed.json parses and every image resolves', () => {
    const feed = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'feed.json'), 'utf8'));
    assert.ok(feed.news.length > 0);
    const repo = path.join(__dirname, '..', '..');
    const ids = new Set();
    let newBytes = 0; const counted = new Set();
    for (const n of feed.news) {
      assert.ok(n.id && n.title && n.date && n.tag, 'news needs id, title, date, tag: ' + n.id);
      assert.match(n.date, /^\d{4}-\d{2}-\d{2}$/, 'date is YYYY-MM-DD: ' + n.id);
      assert.ok(!ids.has(n.id), 'news id used twice: ' + n.id); ids.add(n.id);
      const pics = Feed.gallery(n);
      assert.ok(pics.length >= 1, 'news needs a picture: ' + n.id);
      for (const g of pics) {
        const src = g.src;
        assert.ok(/^(art\/|repo:)/.test(src), 'a picture is art/<file> or repo:<path>: ' + src);
        const rel = src.startsWith('art/') ? src : src.slice(5);
        assert.ok(Feed.safePath(rel), 'picture path: ' + src);
        const file = src.startsWith('art/') ? path.join(__dirname, '..', 'assets', src) : path.join(repo, rel);
        assert.ok(fs.existsSync(file), 'picture missing: ' + src);
        // a repo: picture must also be in the launcher's bundle, or a player without the game sees only the key art
        if (src.startsWith('repo:')) assert.ok(rel.startsWith('launcher/assets/'), 'repo: pictures live under launcher/assets: ' + src);
        if (rel.startsWith('launcher/assets/news/') && !counted.has(rel)) { counted.add(rel); newBytes += fs.statSync(file).size; }
        // 16:9 like every other picture box in the launcher (JPEG: read the size from the frame header)
        if (/\.jpe?g$/i.test(file)) { const [w, h] = jpegSize(fs.readFileSync(file)); assert.strictEqual(Math.round((w / h) * 100), 178, `16:9 expected, ${w}x${h}: ${src}`); }
      }
    }
    assert.ok(newBytes < 6 * 1048576, `launcher/assets/news stays under 6 MB (${newBytes} bytes)`);
    for (const l of feed.links || []) assert.match(l.url, /^https:\/\//);
    assert.ok(!/@[\w-]+\.[a-z]{2,}/i.test(JSON.stringify(feed)), 'no e-mail address in the feed');
  });
  await t('feed: the upcoming list is labelled as proposals, has no dates, and every item has a title and a summary', () => {
    const feed = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'feed.json'), 'utf8'));
    const up = Feed.upcoming(feed, 'stable');
    assert.ok(up.items.length >= 8 && up.items.length <= 10, 'eight to ten proposals: ' + up.items.length);
    assert.match(up.note, /proposed, not promised/i);
    const ids = new Set();
    for (const it of up.items) {
      assert.ok(it.title && it.summary && it.area, 'upcoming item needs title, summary, area: ' + it.id);
      assert.ok(!ids.has(it.id), 'upcoming id used twice: ' + it.id); ids.add(it.id);
      assert.ok(!/\b20\d\d\b|\b(january|february|march|april|june|july|august|september|october|november|december|next week|next month|soon)\b/i.test(it.title + ' ' + it.summary), 'no dates or promises: ' + it.id);
    }
    assert.strictEqual(feed.upcoming.items.length, up.items.length, 'no item was dropped');
  });
  await t('feed: a missing or odd upcoming block gives an empty list, never a throw', () => {
    for (const feed of [null, undefined, {}, { upcoming: null }, { upcoming: 'soon' }, { upcoming: { items: 'x' } }, { upcoming: { items: [null, 3, {}, { title: '  ' }] } }]) {
      const up = Feed.upcoming(feed, 'stable');
      assert.deepStrictEqual(up.items, []);
      assert.ok(up.title && up.note);
    }
    const up = Feed.upcoming({ upcoming: { title: 7, items: [{ title: 'A', summary: 5 }, { title: 'B', channels: ['preview'] }, { id: 'c', title: ' C ', area: 'MAPS', summary: 's' }] } }, 'stable');
    assert.deepStrictEqual(up.items, [{ id: 'upcoming-1', area: '', title: 'A', summary: '' }, { id: 'c', area: 'MAPS', title: 'C', summary: 's' }]);
    assert.strictEqual(up.title, 'Upcoming');
  });
  await t('feed: pictures fall back cleanly (bundled copy, then the installed game, then the key art)', () => {
    const D = Feed.DEFAULT_IMAGE;
    assert.deepStrictEqual(Feed.candidates('art/map01_kaltenbrunn.png', false), ['../assets/art/map01_kaltenbrunn.png', D]);
    assert.deepStrictEqual(Feed.candidates('repo:launcher/assets/news/u19_snow.jpg', false), ['../assets/news/u19_snow.jpg', D]);
    assert.deepStrictEqual(Feed.candidates('repo:launcher/assets/news/u19_snow.jpg', true), ['../assets/news/u19_snow.jpg', 'game://img/launcher/assets/news/u19_snow.jpg', D]);
    assert.deepStrictEqual(Feed.candidates('repo:docs/captures/a b.png', true), [D], 'spaces are not a feed path');
    assert.deepStrictEqual(Feed.candidates('repo:docs/captures/x.png', true), ['game://img/docs/captures/x.png', D]);
    assert.deepStrictEqual(Feed.candidates('repo:docs/captures/x.png', false), [D], 'a repo picture needs the game');
    // nothing, nonsense, a remote host, a climb out of the folder, a non-picture: the key art only
    for (const bad of [undefined, null, '', 42, {}, 'https://example.com/a.png', 'art/../../main.js', 'repo:../secret.png', 'repo:/etc/x.png', 'art/readme.txt', 'file:///c:/x.png'])
      assert.deepStrictEqual(Feed.candidates(bad, true), [D], String(bad));
    assert.ok(fs.existsSync(path.join(__dirname, '..', 'renderer', D)), 'the fallback picture is in the bundle');
  });
  await t('feed: an item\'s gallery is its image, then its images, without doubles; captions are optional', () => {
    assert.deepStrictEqual(Feed.gallery({}), []);
    assert.deepStrictEqual(Feed.gallery(null), []);
    assert.deepStrictEqual(Feed.gallery({ image: 'art/a.png' }), [{ src: 'art/a.png', caption: '' }]);
    assert.deepStrictEqual(Feed.gallery({ image: 'art/a.png', images: 'art/b.png' }), [{ src: 'art/a.png', caption: '' }]);
    assert.deepStrictEqual(
      Feed.gallery({ image: 'art/a.png', images: [{ src: 'art/a.png', caption: 'lead' }, 'art/b.png', null, 5, { caption: 'no src' }, { src: 'art/b.png' }, { src: 'art/c.png', caption: 9 }] }),
      [{ src: 'art/a.png', caption: 'lead' }, { src: 'art/b.png', caption: '' }, { src: 'art/c.png', caption: '' }]);
    assert.deepStrictEqual(Feed.gallery({ images: ['art/b.png'] }), [{ src: 'art/b.png', caption: '' }], 'images without image');
    const many = Feed.gallery({ images: Array.from({ length: 40 }, (_, i) => `art/p${i}.png`) });
    assert.strictEqual(many.length, Feed.MAX_GALLERY);
  });
  await t('feed: news is filtered by channel, newest first, same-day items in file order', () => {
    const feed = { news: [{ id: 'a', date: '2026-11-10', title: 'A' }, { id: 'b', date: '2026-11-15', title: 'B' }, { id: 'c', date: '2026-11-15', title: 'C' },
      { id: 'p', date: '2026-11-16', title: 'P', channels: ['preview'] }, { id: 'untitled', date: '2026-11-17' }, null] };
    assert.deepStrictEqual(Feed.visibleNews(feed, 'stable').map((n) => n.id), ['b', 'c', 'a']);
    assert.deepStrictEqual(Feed.visibleNews(feed, 'preview').map((n) => n.id), ['p', 'b', 'c', 'a']);
    assert.deepStrictEqual(Feed.visibleNews(null, 'stable'), []);
    assert.deepStrictEqual(Feed.visibleNews({ news: 'x' }, 'stable'), []);
    // the real feed leads with today's work on the stable channel
    const real = Feed.visibleNews(JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'feed.json'), 'utf8')), 'stable');
    assert.deepStrictEqual(real.slice(0, 5).map((n) => n.id), ['trailer-teaser', 'trailer-gameplay', 'gore-1', 'u19-fixes', 'movement-perf']);
    assert.ok(real.filter((n) => n.hero).length >= 3, 'a carousel of three or more');
  });
  await t('renderer: the page loads feed.js before app.js and its picture policy allows only bundled and game:// pictures', () => {
    const html = fs.readFileSync(path.join(__dirname, '..', 'renderer', 'index.html'), 'utf8');
    assert.ok(html.indexOf('src="feed.js"') > 0 && html.indexOf('src="feed.js"') < html.indexOf('src="app.js"'));
    assert.match(html, /img-src 'self' game: data:;/);
    for (const id of ['upList', 'upTitle', 'upNote', 'upTeaser', 'heroStrip', 'articleStrip', 'articlePrev', 'articleNext', 'articleCaption'])
      assert.ok(html.includes(`id="${id}"`), 'missing #' + id);
    assert.ok(html.includes('data-view="upcoming"'), 'the Upcoming tab');
  });
  await t('excludes (empty by default; the mechanism still works when a feed lists a folder)', async () => {
    const { execFileSync } = require('child_process');
    const g = (cwd, ...a) => execFileSync('git', a, { cwd, stdio: 'pipe' }).toString();
    const src = path.join(tmp, 'src'); const dst = path.join(tmp, 'dst');
    fs.mkdirSync(path.join(src, 'assets', 'user_supplied', 'mocap_online', 'pack'), { recursive: true });
    fs.mkdirSync(path.join(src, 'assets', 'zombies'), { recursive: true });
    fs.writeFileSync(path.join(src, 'assets', 'user_supplied', 'mocap_online', 'pack', 'raw.fbx'), 'raw');
    fs.writeFileSync(path.join(src, 'assets', 'zombies', 'clip.glb'), 'clip');
    fs.writeFileSync(path.join(src, 'project.godot'), '');
    g(src, 'init', '-q'); g(src, 'add', '-A'); g(src, '-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'x');
    g(tmp, 'clone', '-q', src, dst);
    await m.detectGit();
    settings.installDir = dst;
    m.feed = { exclude: ['assets/user_supplied/mocap_online/'] };
    await m.applyExcludes(dst);
    m.feed = null;
    assert.ok(!fs.existsSync(path.join(dst, 'assets', 'user_supplied', 'mocap_online', 'pack', 'raw.fbx')), 'raw pack still there');
    assert.ok(fs.existsSync(path.join(dst, 'assets', 'zombies', 'clip.glb')), 'converted clip missing');
    assert.strictEqual(g(dst, 'config', 'lfs.fetchexclude').trim(), 'assets/user_supplied/mocap_online/**');
    g(dst, 'checkout', '-q', '-f', '-B', 'x', 'HEAD');
    assert.ok(!fs.existsSync(path.join(dst, 'assets', 'user_supplied', 'mocap_online')), 'came back after checkout');
    settings.installDir = path.join(tmp, 'game');
  });
  // ---------- T-289: starting the game ----------
  // A fake install the play checks accept, a fake engine exe, and a spawn that never starts a real process.
  const { EventEmitter } = require('events');
  const { run: runProc } = require('../src/proc');
  const fakeGame = () => {
    const root = fs.mkdtempSync(path.join(tmp, 'play-'));
    const game = path.join(root, 'My Games', 'Claude Zombies'); // spaces on purpose
    fs.mkdirSync(path.join(game, '.git'), { recursive: true });
    fs.mkdirSync(path.join(game, '.godot', 'imported'), { recursive: true });
    fs.writeFileSync(path.join(game, '.godot', 'global_script_class_cache.cfg'), '');
    fs.writeFileSync(path.join(game, MARKER), JSON.stringify({ managedBy: 'launcher', branch: 'master', sha: 'abc', lfsSha: 'abc', importedSha: 'abc' }));
    const st = { installDir: game, channel: 'stable', extraArgs: '', renderingDriver: 'auto', fullscreen: false, safeMode: false };
    const ev = [];
    const calls = [];
    let behave = (child) => setImmediate(() => child.emit('spawn'));
    const pm = new GameManager({
      dataDir: path.join(root, 'data'), config, getSettings: () => st, emit: (e, p) => ev.push([e, p]),
      platform: 'win32', earlyExitMs: 400, findGame: async () => pm._running || [],
      spawn: (exe, args, opts) => {
        calls.push({ exe, args, opts });
        const child = new EventEmitter();
        child.pid = 4242 + calls.length; child.unref = () => {};
        behave(child, opts);
        return child;
      },
    });
    pm.headSha = async () => (pm._noGit ? null : 'abc');
    pm.git = 'git';
    fs.mkdirSync(path.dirname(pm.godotExe()), { recursive: true });
    fs.writeFileSync(pm.godotExe(), 'not really an exe');
    return { pm, st, ev, calls, game, setBehave: (f) => { behave = f; } };
  };
  const waitFor = async (fn, ms = 3000) => { const t0 = Date.now(); while (!fn()) { if (Date.now() - t0 > ms) throw new Error('timed out waiting'); await new Promise((r) => setTimeout(r, 20)); } };

  await t('play args: the separate render thread by default on Windows, not in safe mode, not off Windows', () => {
    const { pm, st } = fakeGame();
    let a = pm.playArgs().args;
    const i = a.indexOf('--render-thread');
    assert.ok(i > 0 && a[i + 1] === 'separate', a.join(' '));
    assert.ok(i < a.indexOf(config.mainScene), 'engine options before the scene');
    assert.strictEqual(a[a.length - 1], config.mainScene);
    assert.ok(pm.playArgs().renderThread);
    assert.ok(!pm.playArgs({ safe: true }).args.includes('--render-thread'), 'one-shot safe start');
    st.safeMode = true;
    assert.ok(!pm.playArgs().args.includes('--render-thread'), 'Settings > Safe mode');
    assert.strictEqual(pm.playArgs().renderThread, false);
    st.safeMode = false;
    pm.platform = 'linux';
    assert.ok(!pm.playArgs().args.includes('--render-thread'), 'Windows only');
    pm.platform = 'win32';
    a = pm.playArgs().args;
    assert.strictEqual(a[a.indexOf('--path') + 1], st.installDir, 'a path with spaces stays one argument');
  });
  await t('play args: extra arguments keep quoted values whole, user args after "--" follow the scene, no doubled render thread', () => {
    const { pm, st } = fakeGame();
    st.extraArgs = '--resolution 1920x1080 --log-file "C:\\Temp\\my log.txt" -- --frame-log';
    let a = pm.playArgs().args;
    assert.ok(a.includes('C:\\Temp\\my log.txt'), 'quoted value split: ' + JSON.stringify(a));
    assert.deepStrictEqual(a.slice(-3), [config.mainScene, '--', '--frame-log']);
    st.extraArgs = '--render-thread safe';
    a = pm.playArgs().args;
    assert.strictEqual(a.filter((x) => x === '--render-thread').length, 1, 'the player\'s own choice wins');
    assert.strictEqual(pm.playArgs().renderThread, false);
    assert.ok(!pm.playArgs({ safe: true }).args.includes('--render-thread'), 'safe mode drops a typed render thread too');
    st.extraArgs = '--render-thread=separate';
    assert.ok(!pm.playArgs({ safe: true }).args.some((x) => x.startsWith('--render-thread')));
    st.renderingDriver = 'opengl3'; st.fullscreen = true; st.extraArgs = '';
    a = pm.playArgs().args;
    assert.strictEqual(a[a.indexOf('--rendering-driver') + 1], 'opengl3');
    assert.ok(a.includes('--fullscreen'));
  });
  await t('play: spawns detached with the window shown, output into launcher_play.log, never through a shell', async () => {
    const { pm, calls, ev } = fakeGame();
    const r = await pm.play();
    assert.strictEqual(r.pid, 4243);
    const c = calls[0];
    assert.strictEqual(c.exe, pm.godotExe());
    assert.strictEqual(c.opts.detached, true, 'the game outlives the launcher');
    assert.strictEqual(c.opts.windowsHide, false, 'windowsHide would start the game window hidden');
    assert.ok(!c.opts.shell, 'no shell: spaces and quotes cannot split arguments');
    assert.strictEqual(c.opts.cwd, pm.gameDir);
    assert.strictEqual(c.opts.stdio[0], 'ignore');
    assert.strictEqual(typeof c.opts.stdio[1], 'number', 'stdout goes to a file handle (survives the launcher closing)');
    assert.ok(ev.some((e) => e[0] === 'game' && e[1].state === 'starting'));
    const log = fs.readFileSync(pm.playLogPath(), 'utf8');
    assert.match(log, /PLAY/); assert.match(log, /--render-thread/);
    assert.deepStrictEqual((await pm.status()).game.pid, 4243);
    await assert.rejects(pm.play(), (e) => e.code === 'running', 'a second PLAY while the first game runs is refused');
  });
  await t('play: an exit within seconds reports failed with the exit reason, the log lines and the safe-mode offer', async () => {
    const { pm, ev, setBehave } = fakeGame();
    setBehave((child, opts) => setImmediate(() => {
      child.emit('spawn');
      fs.writeSync(opts.stdio[1], 'Godot Engine v4.7.2\nERROR: Condition "!rd" is true.\n');
      fs.writeFileSync(path.join(pm.gameLogDir(), 'game_last.log'), 'Godot Engine v4.7.2\nVulkan 1.4 - Forward+\nERROR: finalize can only be called from the render thread.\n');
      setTimeout(() => child.emit('exit', 3221225477, null), 30);
    }));
    await pm.play();
    await waitFor(() => ev.some((e) => e[0] === 'game' && e[1].state === 'failed'));
    const f = ev.find((e) => e[0] === 'game' && e[1].state === 'failed')[1];
    assert.match(f.reason, /crashed \(access violation\)/);
    assert.ok(f.offerSafe, 'started with the render thread: offer safe mode');
    assert.ok(f.lines.some((l) => /finalize can only be called/.test(l)), 'the game log tail: ' + JSON.stringify(f.lines));
    assert.ok(f.output.some((l) => /Condition "!rd"/.test(l)), 'the captured stdout: ' + JSON.stringify(f.output));
    assert.match(fs.readFileSync(pm.playLogPath(), 'utf8'), /===== exit 3221225477 \(crashed \(access violation\)\) after/);
    assert.strictEqual((await pm.status()).game, null);
    // the same in safe mode does not offer safe mode again
    ev.length = 0;
    await pm.play({ safe: true });
    await waitFor(() => ev.some((e) => e[0] === 'game' && e[1].state === 'failed'));
    assert.strictEqual(ev.find((e) => e[0] === 'game' && e[1].state === 'failed')[1].offerSafe, false);
  });
  await t('play: a game that keeps running past the start window, then quits, is a normal exit (no error)', async () => {
    const { pm, ev, setBehave } = fakeGame();
    setBehave((child) => setImmediate(() => { child.emit('spawn'); setTimeout(() => child.emit('exit', 0, null), 600); }));
    const r = await pm.play();
    assert.strictEqual(await pm.survivesStart(r.pid), true);
    await waitFor(() => ev.some((e) => e[0] === 'game' && e[1].state === 'exited'));
    assert.ok(!ev.some((e) => e[0] === 'game' && e[1].state === 'failed'));
  });
  await t('play: a spawn error (missing exe, antivirus) becomes a clear message, not a crash of the launcher', async () => {
    const { pm, setBehave } = fakeGame();
    for (const [code, re] of [['ENOENT', /not found/], ['EPERM', /antivirus/], ['UNKNOWN', /Smart App Control|antivirus/]]) {
      setBehave((child) => setImmediate(() => { const e = new Error('spawn ' + code); e.code = code; child.emit('error', e); }));
      await assert.rejects(pm.play(), (e) => e.code === 'spawn' && re.test(e.message), code);
    }
    assert.match(fs.readFileSync(pm.playLogPath(), 'utf8'), /could not start: UNKNOWN/);
    assert.strictEqual(pm.game, null);
  });
  await t('play: refused while an update / import runs, allowed during the quiet update check', async () => {
    const { pm, calls } = fakeGame();
    for (const op of ['update', 'install', 'repair', 'prepare']) {
      pm.busy = op;
      await assert.rejects(pm.play(), (e) => e.code === 'busy', op);
    }
    pm.busy = 'check';
    await pm.play();
    assert.strictEqual(calls.length, 1);
    pm.busy = null;
  });
  await t('play: a half-finished update (LFS files or the import missing) asks for PREPARE instead of starting', async () => {
    const { pm, game, calls } = fakeGame();
    const write = (o) => fs.writeFileSync(path.join(game, MARKER), JSON.stringify({ managedBy: 'launcher', branch: 'master', sha: 'abc', ...o }));
    write({ lfsSha: null, importedSha: null });
    await assert.rejects(pm.play(), (e) => e.code === 'files' && e.action === 'prepare');
    write({ lfsSha: 'abc', importedSha: 'old' });
    await assert.rejects(pm.play(), (e) => e.code === 'import' && e.action === 'prepare');
    write({ importedSha: 'abc' }); // an install from before T-289 (no lfsSha): the import implies the files
    await pm.play();
    pm.game.exited = true; pm.game = null;
    fs.rmSync(path.join(game, '.godot', 'imported'), { recursive: true });
    await assert.rejects(pm.play(), (e) => e.code === 'import', 'no import cache: the first start would import');
    fs.rmSync(pm.godotExe());
    await assert.rejects(pm.play(), (e) => e.code === 'engine');
    assert.strictEqual(calls.length, 1);
    pm.git = 'git'; // status() reads HEAD only with git found
    const s = await pm.status();
    assert.ok(s.needsImport);
  });
  await t('play: without git to read the version, PLAY is not blocked (only a missing import cache blocks it)', async () => {
    const { pm, game, calls } = fakeGame();
    fs.writeFileSync(path.join(game, MARKER), JSON.stringify({ managedBy: 'launcher', branch: 'master', sha: 'abc' }));
    pm._noGit = true;
    await pm.play();
    assert.strictEqual(calls.length, 1);
    pm.game.exited = true; pm.game = null;
    fs.rmSync(path.join(game, '.godot', 'imported'), { recursive: true });
    await assert.rejects(pm.play(), (e) => e.code === 'import');
  });
  await t('play: a game already running from an earlier launcher session is found; update and repair wait for it', async () => {
    const { pm } = fakeGame();
    pm._running = [777];
    await assert.rejects(pm.play(), (e) => e.code === 'running' && e.pids[0] === 777);
    await assert.rejects(pm.assertGameClosed(), (e) => e.code === 'running');
    pm._running = [];
    await pm.assertGameClosed();
  });
  await t('channel or folder changes are refused while files are written (not during the quiet check)', () => {
    const { pm } = fakeGame();
    const cur = { channel: 'stable', installDir: 'x' };
    pm.busy = 'update';
    assert.throws(() => pm.assertSettingsChange({ channel: 'preview' }, cur), /before changing the channel/);
    assert.throws(() => pm.assertSettingsChange({ installDir: 'y' }, cur), /install folder/);
    pm.assertSettingsChange({ fullscreen: true }, cur);
    pm.assertSettingsChange({ channel: 'stable' }, cur);
    pm.busy = 'check';
    pm.assertSettingsChange({ channel: 'preview' }, cur);
    pm.busy = null;
  });
  await t('logs: launcher_play.log rotates past its size; the previous games\' logs are kept, five in all', () => {
    const { rotateFile, rotateGameLogs } = require('../src/manager');
    const d = fs.mkdtempSync(path.join(tmp, 'logs-'));
    const f = path.join(d, 'launcher_play.log');
    fs.writeFileSync(f, 'x'.repeat(50));
    assert.strictEqual(rotateFile(f, 100, 3), false);
    for (let i = 0; i < 5; i++) { fs.writeFileSync(f, String(i).repeat(200)); assert.ok(rotateFile(f, 100, 3)); }
    assert.deepStrictEqual(fs.readdirSync(d).sort(), ['launcher_play.log.1', 'launcher_play.log.2', 'launcher_play.log.3']);
    assert.match(fs.readFileSync(f + '.1', 'utf8'), /^4/);
    const g = path.join(d, 'game');
    fs.mkdirSync(g);
    for (let i = 0; i < 8; i++) {
      fs.writeFileSync(path.join(g, 'game_last.log'), 'run ' + i);
      const t0 = new Date(Date.UTC(2026, 10, 26, 7, i));
      fs.utimesSync(path.join(g, 'game_last.log'), t0, t0);
      rotateGameLogs(g, 5);
    }
    const kept = fs.readdirSync(g).sort();
    assert.strictEqual(kept.length, 4, 'four older ones (+ the new game_last.log written next): ' + kept);
    assert.strictEqual(fs.readFileSync(path.join(g, kept[kept.length - 1]), 'utf8'), 'run 7');
  });
  await t('exit codes in words', () => {
    const { exitWords } = require('../src/manager');
    assert.match(exitWords(3221225477), /access violation/);
    assert.match(exitWords(-1073741819), /access violation/, 'the same code as a signed number');
    assert.match(exitWords(0xC0000135), /DLL/);
    assert.match(exitWords(0xC0001234), /crashed \(0xC0001234\)/);
    assert.match(exitWords(2), /exit code 2/);
  });
  await t('import: a crash or a stall is a failure (the state stays "not imported"); exit 0 marks the version ready', async () => {
    const { pm, game } = fakeGame();
    const setRun = (res) => { pm.runProc = async () => res; };
    fs.writeFileSync(path.join(game, MARKER), JSON.stringify({ managedBy: 'launcher', sha: 'abc', lfsSha: 'abc', importedSha: 'old' }));
    setRun({ code: 3221225477, stdout: '', stderr: '' });
    await assert.rejects(pm.importAssets(false), /crashed while preparing/);
    assert.strictEqual(pm.readState().importedSha, null);
    setRun({ code: 1, stdout: '', stderr: '', timedOut: true });
    await assert.rejects(pm.importAssets(false), /stopped responding/);
    setRun({ code: 0, stdout: '', stderr: '' });
    await pm.importAssets(false);
    assert.strictEqual(pm.readState().importedSha, 'abc');
  });
  await t('proc: a child that prints nothing for idleTimeoutMs is ended and reported timedOut', async () => {
    const t0 = Date.now();
    const r = await runProc(process.execPath, ['-e', 'setTimeout(() => {}, 20000)'], { idleTimeoutMs: 400 });
    assert.ok(r.timedOut, JSON.stringify(r));
    assert.ok(Date.now() - t0 < 10000, 'ended quickly');
    const ok = await runProc(process.execPath, ['-e', 'console.log("hi")'], { idleTimeoutMs: 5000 });
    assert.ok(!ok.timedOut);
  });

  // ---------- T-289 part 2: trailers ----------
  await t('feed: a video item resolves to the installed game (repo:launcher/media) or the launcher bundle (media/)', () => {
    const v = Feed.video({ type: 'video', image: 'repo:launcher/assets/news/u19_snow.jpg', video: { src: 'repo:launcher/media/teaser_720p.mp4', label: 'Watch the teaser', duration: '1:07' } });
    assert.deepStrictEqual(v, { src: 'repo:launcher/media/teaser_720p.mp4', poster: 'repo:launcher/assets/news/u19_snow.jpg', label: 'Watch the teaser', duration: '1:07' });
    assert.deepStrictEqual(Feed.videoCandidates(v.src, true), ['game://media/launcher/media/teaser_720p.mp4']);
    assert.deepStrictEqual(Feed.videoCandidates(v.src, false), [], 'not installed: the poster and "after install"');
    assert.deepStrictEqual(Feed.videoCandidates('media/clip.webm', false), ['../assets/media/clip.webm']);
    assert.strictEqual(Feed.video({ video: 'repo:launcher/media/a.mp4' }).label, 'Watch trailer');
    for (const bad of [undefined, null, {}, { video: 5 }, { video: 'repo:docs/x.mp4' }, { video: 'repo:launcher/media/../../x.mp4' }, { video: 'https://example.com/t.mp4' },
      { video: 'repo:launcher/media/a.mkv' }, { video: { src: 'media/a b.mp4' } }, { video: 'file:///c:/t.mp4' }])
      assert.strictEqual(Feed.video(bad), null, JSON.stringify(bad));
    const feed = { news: [{ id: 'a', date: '2026-11-20', title: 'A', video: 'repo:launcher/media/a.mp4' }, { id: 'b', date: '2026-11-25', title: 'B' }, { id: 'c', date: '2026-11-26', title: 'C', video: 'media/c.mp4', channels: ['preview'] }] };
    assert.deepStrictEqual(Feed.trailers(feed, 'stable').map((n) => n.id), ['a']);
    assert.deepStrictEqual(Feed.trailers(feed, 'preview').map((n) => n.id), ['c', 'a']);
  });
  await t('feed: every trailer in feed.json exists, sits in launcher/media under Git LFS, and is H.264-sized (<= 80 MB)', () => {
    const feed = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'feed.json'), 'utf8'));
    const repo = path.join(__dirname, '..', '..');
    const attrs = fs.readFileSync(path.join(repo, '.gitattributes'), 'utf8');
    assert.match(attrs, /^launcher\/media\/\*\*\/\*\.mp4 filter=lfs/m, '.gitattributes sends launcher/media videos to LFS');
    for (const n of feed.news) {
      const v = Feed.video(n);
      if (!v) { assert.ok(!n.video && n.type !== 'video', 'a video item that does not parse: ' + n.id); continue; }
      assert.ok(n.image, 'a trailer needs its poster image: ' + n.id);
      if (v.src.startsWith('repo:')) {
        const file = path.join(repo, v.src.slice(5));
        assert.ok(fs.existsSync(file), 'trailer missing: ' + v.src);
        const head = fs.readFileSync(file).subarray(0, 200).toString('latin1');
        if (!head.startsWith('version https://git-lfs')) assert.ok(fs.statSync(file).size <= 80 * 1048576, 'a 720p trailer, not the 1080p master: ' + v.src);
      }
    }
  });
  await t('renderer: trailer elements exist and the page may play media from the bundle and game:// only', () => {
    const html = fs.readFileSync(path.join(__dirname, '..', 'renderer', 'index.html'), 'utf8');
    assert.match(html, /media-src 'self' game:;/);
    for (const id of ['bgVideo', 'trailerBtn', 'heroWatch', 'player', 'playerVideo', 'gameErr', 'gameErrLines', 'gameErrActions', 'setSafe'])
      assert.ok(html.includes(`id="${id}"`), 'missing #' + id);
    assert.match(html, /id="bgVideo"[^>]*muted/, 'the carousel preview is muted');
    const main = fs.readFileSync(path.join(__dirname, '..', 'main.js'), 'utf8');
    assert.match(main, /stream: true/, 'game:// streams (video needs it)');
    assert.match(main, /launcher', 'media'/, 'videos only from launcher/media');
    const pre = fs.readFileSync(path.join(__dirname, '..', 'preload.js'), 'utf8');
    for (const c of ["'prepare'", "'gameAction'", "'game'"]) assert.ok(pre.includes(c), 'preload lacks ' + c);
  });
  await t('status before install', async () => {
    const s = await m.status();
    assert.strictEqual(s.installed, false);
    assert.strictEqual(s.channel.branch, 'master');
  });
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(fails ? `${fails} FAILED` : 'all passed');
  process.exit(fails);
})();
