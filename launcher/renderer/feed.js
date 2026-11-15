'use strict';
// What the launcher reads out of feed.json, as plain functions: no DOM, no Electron, so tests/check.js runs them in Node
// and the renderer loads the same file with a <script> tag (window.Feed).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Feed = factory();
})(this, function () {
  const DEFAULT_IMAGE = '../assets/art/map00_crossroads.png';
  const MAX_GALLERY = 12;

  // A feed path is letters, digits, _ - . and / only, and never climbs out of its folder.
  function safePath(p) {
    return typeof p === 'string' && /^[\w\-./]+$/.test(p) && !p.split('/').includes('..') && !p.startsWith('/') && /\.(png|jpe?g|webp|gif)$/i.test(p);
  }

  /**
   * The URLs to try for a feed image, best first; the launcher's own key art is always last, so a missing or
   * misspelled picture never leaves a hole.
   *   art/<file>                  bundled with the launcher (launcher/assets/art)
   *   repo:launcher/assets/<file> in the game repo AND in this launcher's bundle: the bundled copy first, then the
   *                               installed game (a launcher older than the picture finds it there after UPDATE)
   *   repo:<path>                 any other picture in the game repo (needs the game installed)
   */
  function candidates(src, installed) {
    const out = [];
    if (typeof src === 'string') {
      if (src.startsWith('art/') && safePath(src)) out.push('../assets/' + src);
      else if (src.startsWith('repo:') && safePath(src.slice(5))) {
        const rel = src.slice(5);
        if (rel.startsWith('launcher/assets/')) out.push('../assets/' + rel.slice('launcher/assets/'.length));
        if (installed) out.push('game://img/' + rel.split('/').map(encodeURIComponent).join('/'));
      }
    }
    if (!out.includes(DEFAULT_IMAGE)) out.push(DEFAULT_IMAGE);
    return out;
  }

  /** A news item's pictures: `image` first, then `images` (strings or {src, caption}), no doubles, at most 12. */
  function gallery(item) {
    const out = [];
    const seen = new Set();
    const add = (src, caption) => {
      if (typeof src !== 'string' || !src || seen.has(src) || out.length >= MAX_GALLERY) return;
      seen.add(src);
      out.push({ src, caption: typeof caption === 'string' ? caption : '' });
    };
    if (!item || typeof item !== 'object') return out;
    const extra = Array.isArray(item.images) ? item.images : [];
    // the caption of the lead picture may be given by repeating it in `images`
    const lead = extra.find((g) => g && typeof g === 'object' && g.src === item.image);
    add(item.image, lead && lead.caption);
    for (const g of extra) {
      if (typeof g === 'string') add(g, '');
      else if (g && typeof g === 'object') add(g.src, g.caption);
    }
    return out;
  }

  function onChannel(entry, channelId) {
    return !Array.isArray(entry.channels) || entry.channels.includes(channelId);
  }

  /** News for a channel, newest first; items of one day keep the order they have in the file. */
  function visibleNews(feed, channelId) {
    const items = (feed && Array.isArray(feed.news) ? feed.news : []).filter((n) => n && typeof n === 'object' && n.title && onChannel(n, channelId));
    return items.map((n, i) => [n, i]).sort((a, b) => String(b[0].date).localeCompare(String(a[0].date)) || a[1] - b[1]).map((p) => p[0]);
  }

  /** The "Upcoming" list: { title, note, items: [{ id, area, title, summary }] }; items without a title are dropped. */
  function upcoming(feed, channelId) {
    const u = feed && feed.upcoming && typeof feed.upcoming === 'object' ? feed.upcoming : {};
    const str = (v) => (typeof v === 'string' ? v : '');
    const items = (Array.isArray(u.items) ? u.items : [])
      .filter((it) => it && typeof it === 'object' && str(it.title).trim() && onChannel(it, channelId))
      .map((it, i) => ({ id: str(it.id) || `upcoming-${i + 1}`, area: str(it.area), title: str(it.title).trim(), summary: str(it.summary) }));
    return { title: str(u.title) || 'Upcoming', note: str(u.note) || 'Proposed, not promised.', items };
  }

  return { DEFAULT_IMAGE, MAX_GALLERY, safePath, candidates, gallery, visibleNews, upcoming };
});
