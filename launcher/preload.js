'use strict';
// The renderer's only door to the main process: a fixed list of calls and four event streams.
const { contextBridge, ipcRenderer } = require('electron');

const CALLS = ['boot', 'status', 'requirements', 'feed', 'patchNotes', 'check', 'install', 'update', 'repair', 'prepare', 'cancel',
  'play', 'gameAction', 'uninstall', 'signOut', 'getSettings', 'setSettings', 'pickDir', 'openFolder', 'openExternal', 'win'];

const api = {};
for (const c of CALLS) api[c] = (...a) => ipcRenderer.invoke(c, ...a);
api.on = (channel, fn) => {
  if (!['progress', 'log', 'state', 'window', 'game'].includes(channel)) return () => {};
  const h = (_e, p) => fn(p);
  ipcRenderer.on(channel, h);
  return () => ipcRenderer.removeListener(channel, h);
};
contextBridge.exposeInMainWorld('launcher', api);
