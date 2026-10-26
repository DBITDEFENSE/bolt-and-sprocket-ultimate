# OVERNIGHT RUN — build while I sleep, and have something playable when I wake up

I'm going to sleep. You have the whole night and no one will answer questions. This file sets the rules for this run. It **overrides every "PAUSE for my review" instruction** in `ULTIMATE_PROMPT.md` (v1), `ULTIMATE_PROMPT_V2.md`, and `ULTIMATE_PROMPT_V3_BOSSES.md`, all in `C:\Users\Devin\PROJECTS\bolt-and-sprocket\`. Every other rule in those files still applies: originality, licensed assets only, greybox first, data-driven tuning, git, and never touching the original web game.

**The goal:** when I wake up, I double-click one file and **play something that's clearly better than when I went to bed**, and I can read in 2 minutes what happened.

---

## 1. FIRST 10 MINUTES — orient

1. Read v1, v2, and v3 in full, then read this project's `docs/`, `ROADMAP.md`, `DECISIONS.md`, and `PROGRESS.md` if they exist. Run `git log --oneline -30` and `git status`.
2. Figure out where the build stands. If `PROGRESS.md` has a "RESUME HERE" line, continue from it exactly.
3. Check the toolchain: find the Godot 4 executable (on PATH, or in common install folders like `C:\Program Files\Godot`, `%LOCALAPPDATA%`, the Downloads folder, or a winget/Steam install). Record its path in `tools/godot_path.txt`. If Godot can't be found, try `winget install GodotEngine.GodotEngine` once. If that fails, do everything that doesn't need it (docs, data extraction, GDScript written carefully, tests ready to run). Make the missing toolchain the **first line of the morning report**, and don't pretend anything was tested.
4. Write the plan for tonight at the top of `PROGRESS.md`: the milestones you'll attempt, in order.

## 2. WORK ORDER FOR TONIGHT (skip anything already done; go as far as you can)

1. **M0, lean version:** the extraction tool plus `/data/bs_source/` JSON, `CANON.md`, `ROADMAP.md`, `DECISIONS.md`, and the Godot skeleton. **Cap M0 at about 90 minutes.** Write the docs the build needs now, and put any doc that isn't needed tonight on the roadmap. Do not spend the night writing documents. Instead of pausing for review, put my review items in the morning report.
2. **M2, Gravelight vertical slice, Map 0 "Crossroads Inn" in greybox:**
   - first-person controller, M1911, knife, frags;
   - Gängers with window entry and barricades;
   - rounds and scaling, Scrip, 2 wall-buys, 2 doors, the Mystery Crate, power-ups;
   - HUD, a game-over screen, and the dev console.

   This is the fastest path to something fun, so do it before the Bolt slice.
3. **M1, Bolt & Sprocket vertical slice:** the third-person controller at parity with the web build's `CONFIG` numbers, the mallet string, Sprocket following with barks, the Omni-Blaster, and a greybox chunk of Scrapheap Junction with Scrap Mutts and Tinker Turrets.
4. **MZ, zombie animation upgrade** (v2 §7), as far as possible: locomotion variants, posture layers, hit flinches, crawler transition, ragdoll deaths.
5. **HB1, The Cousins** (v3 §2) on Map 0, round 10.
6. If there's still time: the perk machines in the Map 0 cellar (v1 Appendix A §A9), then more M1/M3 work.

Each step must be **playable and committed** before the next one starts. A smaller thing that works beats a bigger thing that's half-built.

## 3. HOW TO WORK UNATTENDED

- **Never stop to ask.** When something is ambiguous, pick the sensible option, log it in `DECISIONS.md` with a one-line reason, and keep going. If you're truly blocked (missing tool, broken dependency, an asset you can't get), stub it with a clear placeholder, note it in `PROGRESS.md` under BLOCKED, and **move to the next task.** Never sit on one problem for more than ~30 minutes; break it into smaller pieces or route around it.
- **Branch per milestone** (`m2-crossroads`, `m1-bolt`, …). Merge into `main` only when it launches and the tests pass. **`main` must always launch.**
- **Commit at least every 30–45 minutes** with clear messages, and tag finished milestones.
- **Checkpoint for crashes and context resets:** after every commit, update `PROGRESS.md` with what's done, what's in progress, and a single **"RESUME HERE: …"** line precise enough that a fresh session could continue with no other context.
- **Verify, don't assume:**
  - Run the GUT tests headless.
  - Run a boot smoke test (launch each playable scene for ~10 seconds with `--quit-after` and check the output for script errors).
  - Fix every error and warning you introduce before committing.
- **Never mark something done that isn't.** In the report, "works," "partly works," and "not started" mean exactly that.
- **Stay inside this project folder.** No system changes beyond installing Godot if it's missing. No deleting anything outside the project. Never modify the original `bolt-and-sprocket` folder.

## 4. LEAVE THESE FOR THE MORNING

1. **`PLAY.bat`** in the project root. Double-clicking it launches the game straight to a simple dev menu with buttons for every playable thing: "Gravelight — Crossroads Inn," "Bolt & Sprocket — Scrapheap slice," "Boss test — The Cousins," and so on. It also has a "skip to round N" field and a god-mode checkbox so I can see late-round content fast.
2. **Screenshots:** a `tools/capture.gd` script (or a `--capture` launch flag) that opens each playable scene in a real window, waits for it to settle, and saves 2–3 PNGs to `morning/screenshots/<milestone>/`: the spawn view, combat with zombies on screen, and a boss if one exists. Run it at the end of each milestone.
3. **`morning/MORNING_REPORT.md`**, written last and kept short. I'll read it on my phone.
   - **Line 1:** one sentence on what's new tonight.
   - **Play it:** what to click in `PLAY.bat` and what to try first (e.g. "Crossroads Inn, round 10 → The Cousins").
   - **What's done:** each milestone marked works / partly works / not started.
   - **Screenshots:** a list linking the PNGs.
   - **Decisions I made for you:** the top 5–10 from `DECISIONS.md`.
   - **Needs you:** questions, the Likeness Sheet placeholders from v3, the HUMOR-REVIEW yes/no list, and anything blocked.
   - **Known bugs.**
   - **Next up:** what the next run will do.

## 5. START NOW
Begin with §1. Post a short progress note after each finished step, so the log shows the night's work even if no one is watching. Don't wait for confirmation. Go.
