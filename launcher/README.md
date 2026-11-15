# CLAUDE ZOMBIES Launcher

A Windows launcher in the style of the big game launchers: news carousel, patch notes, release channels, one big
button. It installs everything a new player needs and keeps them on the newest build from GitHub.

## For players
1. Accept the GitHub invitation to the repository (the e-mail from GitHub). The repository is private.
2. Run `ClaudeZombiesLauncher-Setup-<version>.exe` (installs per user, no admin) or the `-portable.exe`.
3. Press **INSTALL**. When a GitHub window opens, sign in with the invited account. That's all.

After that, the launcher checks for updates every time it opens. The big button reads INSTALL, UPDATE or PLAY.

What INSTALL does, in order:
| Step | What | Where |
|---|---|---|
| Requirements | Git for Windows (brings Git LFS and the GitHub sign-in helper, Git Credential Manager). Installed with `winget`, or the official installer if winget is missing. Windows asks for admin approval once. | Program Files |
| GitHub | `git ls-remote` checks access and opens the GitHub sign-in on first use | — |
| Game data | `git clone --filter=blob:none --no-checkout` of the channel's branch, then checkout (files from the current version only, full commit history for the patch notes) | `%LOCALAPPDATA%\ClaudeZombies\game` |
| Game assets | `git lfs pull` (about 1.5 GB of models, textures, sound) | same |
| Engine | Godot 4.7.2 win64 from the official GitHub release, checked against its `SHA512-SUMS.txt` | `%LOCALAPPDATA%\ClaudeZombies\launcher\godot\4.7.2` |
| Prepare | `godot --headless --import` builds the `.godot` import cache (not in git). Slow the first time, quick after updates | game folder |

PLAY runs `godot --path <game> res://gravelight/ui/main_menu.tscn` (the same as Play.bat) and writes
`<game>\logs\game_last.log`.

UPDATE fetches the channel's branch, checks it out, pulls only the new LFS files and re-imports. **Repair** resets
the tracked files, pulls every LFS file again and re-imports. **Settings** has the install folder, channel, graphics
API (Vulkan / D3D12 / OpenGL for older GPUs), fullscreen, extra arguments, what the launcher does when the game starts,
"Switch GitHub account" and Uninstall.

## For the owner: posting news
News, the hero carousel and the channel list come from **`launcher/feed.json` on the branch of the channel the
player is on** (read with `git show origin/<branch>:launcher/feed.json` after each fetch). Edit it, push, and every
launcher shows it on its next start. No launcher rebuild.

- `news[]`: `id`, `date` (YYYY-MM-DD), `tag`, `title`, `summary`, optional `body` (paragraphs split by a blank line),
  `image`, `hero: true` for the big carousel, `channels: ["preview"]` to show an item on one channel only. Newest
  first; items of one day keep their order in the file.
- `image`: `art/<file>` is bundled with the launcher (`launcher/assets/art`); `repo:<path>` is any image in the game
  repo (shown once the game is installed). **New pictures go in `launcher/assets/news/` and are written
  `repo:launcher/assets/news/<file>`**: a launcher built after the picture shows its bundled copy at once, an older
  launcher finds it in the game folder after UPDATE. A picture that cannot be loaded falls back to the key art.
- `images` (launcher 1.1.0 and newer): a gallery for the article and the strip under the carousel text, a list of
  `{ "src": ..., "caption": ... }` or plain paths. `image` leads; repeat it in `images` to give it a caption. At most
  12. Pictures are 16:9 (960x540 JPEG): add a row to `tools/news_images.py` and run it from the repo root; it cuts,
  resizes and compresses from `docs/captures/`.
- `upcoming` (launcher 1.1.0 and newer; the **Upcoming** tab and the line under the patch notes):
  `{ "title", "note", "items": [{ "id", "area", "title", "summary" }] }`. Proposals, not promises: no dates. The tab
  hides itself when the list is empty. `channels` works on an item as it does on news.
- A launcher older than 1.1.0 ignores `images` and `upcoming` and shows the rest.
- Optional overrides: `channels` (id, name, branch, description), `godot.version`, `mainScene`, `exclude` (repo
  folders players never download).
- Patch notes need nothing: they are the branch's first-parent commit subjects.

Channels by default (`config.json`): **Stable** = `master`, **Preview** = `claude/boss-rework`. When Preview's branch
changes, put a `channels` list in master's `feed.json`.

## For developers
```
cd launcher
npm install
npm start                       # run it
npm run check                   # offline unit checks (progress parsing, errors, install-folder safety, feed)
npm run shots -- <out dir>      # screenshots of every state, no window shown
npm run shots -- <out dir> upcoming article:u19:2 hero:u18   # chosen states: an article at a picture, a carousel slide
                                # CZ_CAPTURE_SIZE=1080x660 for another window size, CZ_CAPTURE_DELAY=4000 to wait longer
node tests/live.js <dir> [channel]   # real end-to-end install from GitHub into <dir> (downloads ~2 GB), then a headless boot
npm run dist                    # dist/ClaudeZombiesLauncher-Setup-<v>.exe and -portable.exe
```
- `main.js` window + IPC, `preload.js` the renderer's fixed API, `src/manager.js` everything that touches the machine
  (plain Node, no Electron, so tests drive it directly), `src/proc.js` child processes with cancel, `renderer/` the UI.
- `launcher/.gdignore` keeps Godot from importing this folder.
- The window is frameless (`-webkit-app-region: drag` on the title bar), sandboxed, context-isolated; the renderer
  cannot reach Node. `game://` serves images from the install folder only.
- Safety: the launcher only installs into an empty folder and only resets/deletes a folder holding its
  `.launcher-managed` marker, so pointing it at a developer checkout cannot destroy work.
- Settings live in `%LOCALAPPDATA%\ClaudeZombies\launcher\settings.json`, logs in `...\launcher\logs\`
  (`launcher.log`, `import_last.log`). `CZ_LAUNCHER_DATA` overrides the folder (tests use it).

## Known limits
- The exe is not code-signed, so Windows SmartScreen warns on first run ("More info" > "Run anyway").
- Players get the whole repository, the purchased mocap pack included (personal project, private repo).
- Disk: 3.6 GB after the first import (measured 2026-11-12: game files, the LFS cache in `.git\lfs`, the import
  cache). The launcher asks for 5 GB free. A full install took 5.6 minutes on the owner's PC and connection.
- Windows only (Godot win64, winget, the Git for Windows installer).

Fonts: Stardos Stencil, Special Elite and IBM Plex Sans (licences in `assets/fonts/`). Art: our own map renders and
wordmark.
