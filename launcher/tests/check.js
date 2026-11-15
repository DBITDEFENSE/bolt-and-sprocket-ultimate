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
    assert.deepStrictEqual(real.slice(0, 5).map((n) => n.id), ['gore-1', 'u19-fixes', 'movement-perf', 'u19', 'u18']);
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
  await t('status before install', async () => {
    const s = await m.status();
    assert.strictEqual(s.installed, false);
    assert.strictEqual(s.channel.branch, 'master');
  });
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log(fails ? `${fails} FAILED` : 'all passed');
  process.exit(fails);
})();
