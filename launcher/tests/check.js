'use strict';
// Offline checks of the launcher core: node tests/check.js   (exit code = failures)
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { GameManager, explainGitError, importProgress, MARKER } = require('../src/manager');

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
    for (const n of feed.news) {
      assert.ok(n.title && n.date && n.tag, 'news needs title, date, tag: ' + n.id);
      if (n.image && n.image.startsWith('art/')) assert.ok(fs.existsSync(path.join(__dirname, '..', 'assets', n.image)), n.image);
    }
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
