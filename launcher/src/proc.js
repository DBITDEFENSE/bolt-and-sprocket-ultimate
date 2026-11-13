'use strict';
// Child-process helpers: run a command, stream its output line by line (git writes progress with \r), allow cancel.
const { spawn } = require('child_process');

class Cancelled extends Error {
  constructor() { super('Cancelled'); this.cancelled = true; }
}

/**
 * run(cmd, args, { cwd, env, onLine, onStdout, input, tracker })
 * Resolves { code, stdout, stderr }. Rejects only on spawn failure or cancel; a non-zero exit is returned, not thrown,
 * unless opts.check is true.
 */
function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawn(cmd, args, {
        cwd: opts.cwd,
        env: { ...process.env, ...(opts.env || {}) },
        windowsHide: true,
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (e) { reject(e); return; }
    if (opts.tracker) opts.tracker.add(child);
    let stdout = '';
    let stderr = '';
    const feed = (buf, which) => {
      const s = buf.toString('utf8');
      if (which === 'out') stdout += s; else stderr += s;
      if (stdout.length > 4e6) stdout = stdout.slice(-2e6);
      if (stderr.length > 4e6) stderr = stderr.slice(-2e6);
      if (opts.onLine) {
        const key = which === 'out' ? '_o' : '_e';
        const pending = (feed[key] || '') + s;
        const parts = pending.split(/\r\n|\r|\n/);
        feed[key] = parts.pop();
        for (const p of parts) if (p.trim()) opts.onLine(p, which);
        // git's progress lines end in \r only; flush a dangling partial line that looks like progress
        if (feed[key] && /\d+%/.test(feed[key]) && feed[key].length > 8) { /* wait for the \r */ }
      }
    };
    child.stdout.on('data', (b) => feed(b, 'out'));
    child.stderr.on('data', (b) => feed(b, 'err'));
    child.on('error', (e) => { if (opts.tracker) opts.tracker.remove(child); reject(e); });
    child.on('close', (code) => {
      if (opts.tracker) opts.tracker.remove(child);
      if (opts.onLine) {
        if (feed._o && feed._o.trim()) opts.onLine(feed._o, 'out');
        if (feed._e && feed._e.trim()) opts.onLine(feed._e, 'err');
      }
      if (opts.tracker && opts.tracker.cancelled) { reject(new Cancelled()); return; }
      const res = { code, stdout, stderr };
      if (opts.check && code !== 0) {
        const err = new Error(`${cmd.split(/[\\/]/).pop()} ${args.slice(0, 3).join(' ')} failed (exit ${code}): ${lastLines(stderr || stdout)}`);
        err.result = res;
        reject(err);
        return;
      }
      resolve(res);
    });
    if (opts.input != null) child.stdin.end(opts.input); else child.stdin.end();
  });
}

function lastLines(s, n = 4) {
  return String(s || '').split(/\r?\n|\r/).map((l) => l.trim()).filter(Boolean).slice(-n).join(' | ');
}

/** Tracks the running children of one operation so Cancel can kill them (the whole tree on Windows). */
class Tracker {
  constructor() { this.children = new Set(); this.cancelled = false; }
  add(c) { this.children.add(c); if (this.cancelled) killTree(c); }
  remove(c) { this.children.delete(c); }
  cancel() {
    this.cancelled = true;
    for (const c of this.children) killTree(c);
  }
  check() { if (this.cancelled) throw new Cancelled(); }
}

function killTree(child) {
  if (!child || child.exitCode != null) return;
  if (process.platform === 'win32') {
    try { spawn('taskkill', ['/pid', String(child.pid), '/T', '/F'], { windowsHide: true }); } catch (_) { /* ignore */ }
  } else {
    try { child.kill('SIGTERM'); } catch (_) { /* ignore */ }
  }
}

module.exports = { run, Tracker, Cancelled, lastLines };
