# Humor Pack — Review Draft (v12)

**Status: NOT WIRED.** Nothing below is hooked into triggers, quests, or the shop yet.
Approve / edit / cut lines here, and I'll wire the survivors. Target locations reference
sections in `index.html`. All content is original — no character names, quotes, or
verbatim lines from any existing game; the cameo is an archetype homage only.

---

## 1. Cameo NPC: COMMANDER REX TREMENDOUS

Washed-up galactic hero turned mall-tour celebrity and racing-league hype man. Vain,
takes credit for other people's work, sells his own merch mid-sentence, and remembers
his own history differently every time. Optional side content only — zero campaign role.

- **Speaker entry** → `SPEAKERS` (~line 9190): `rex: { name: 'CMDR. REX TREMENDOUS', color: '#ffe27a' }`
- **Where he stands**: Scrapheap Junction hub, near the race unlock (appears once `G.story >= 1`),
  plus two flavor lines in the OMNIGRAND PRIX lobby.
- **Portrait**: square jaw, gleaming teeth, a cape that is clearly a beach towel.

### Meet-the-legend dialogue (optional interact, not a quest gate)
- REX: "A fan! No autographs before noon — the wrist is insured. You may bask."
- SPROCKET: "Bolt, this is Commander Tremendous. He 'saved' the Threnody Cluster. The quotes are load-bearing."
- REX: "I DID save it. Or possibly a very similar cluster. There was definitely a cluster, and afterwards it was TREMENDOUSLY saved."
- BOLT: "Weren't you at the OmniScrap gala last year? On a branded hoverboard?"
- REX: "SPONSORSHIP IS NOT LOYALTY, junior. Also that board is available in the gift shop. Tell them Rex sent you. There's no discount, but they'll be impressed."

### Side quest draft: "The Highlight Reel" (collect, 3 items, 120 bolts)
Collect Rex's three lost promo holo-tapes around the junkyard. Each tape he describes
contradicts the last.
- INTRO — REX: "Tragedy, kid. My highlight reel — three tapes, scattered by what I can only describe as sabotage, jealousy, or possibly me leaving them on the roof of my ship. Retrieve them. History NEEDS me."
- INTRO — SPROCKET: "The tapes are labeled 'REX VS. THE VOID DRAGON', 'REX VS. THE VOID DRAGON (SECOND ATTEMPT)', and 'REX APOLOGIZES TO THE VOID DRAGON'."
- PROG — REX: "Found them yet? Tape two is the important one. Tape three is CONTEXT. Nobody needs context."
- DONE — REX: "My legacy! Restored! You know, this reminds me of the time I recovered the Threnody Crystals single-handedly." / BOLT: "You just watched ME do this." / REX: "And I'll remember it single-handedly. 120 bolts. Rex away!"
- Reward flourish: he 'signs' the HUD — banner: `AUTOGRAPHED — "To my biggest fan — R.T." (it's upside down)`

### Ambient barks (6, rotating)
1. "I trained the mallet-arts masters who trained... whoever trained you. So really, this is my victory too."
2. "Back in my prime I defeated Grindstone SPIRITUALLY. The lawsuit says I can't elaborate."
3. "Buy the Rex Tremendous action figure! The kung-fu grip is licensed separately."
4. "I remember this junkyard when it was a WASTELAND. Progress, kid. Tremendous progress."
5. "My memoirs drop this fall: 'I Was There (Volume One of Nine)'. Pre-order cancels are disabled."
6. "You've got potential. I had potential once. Then I had a smoothie franchise. Life comes at you fast."

### Grand Prix lobby lines (2)
- "The league banned me for 'excessive winning'. The record book says 'crashing', but records are written by cowards."
- "Rule one of racing: it's not about speed. It's about MERCHANDISING."

---

## 2. Escalating weapon-vendor ad copy (Blartz)

→ append to `BLARTZ_LINES.pitches` (~line 9320). Escalation pattern: each claim bigger, safety smaller.
1. '"The Mk. II holds twelve rounds. The Mk. III holds a GRUDGE."'
2. '"Field-tested! The field is gone, but the data is BEAUTIFUL."'
3. '"This trigger has a two-stage pull: commitment, and consequences."'
4. '"Voted \'Least Recallable Product\' three years running — they CANNOT recall it. We\'ve tried."'
5. '"Ammo sold separately. Dignity sold separately. The gun is the free part of a much larger transaction."'
6. '"If you can read the serial number, you are legally the safety inspector now. Congratulations."'

## 3. Travel-screen "tips" (absurd / self-contradictory)

The game has no loading screens; the space-travel minigame is the natural slot — a small
rotating tip line under the SPACE TO SKIP prompt (`SPACE TRAVEL` section, ~line 10850).
1. "TIP: The mallet works best when swung."
2. "TIP: Enemies can smell fear. They cannot smell anything else. This has never mattered."
3. "TIP: Collect bolts to buy weapons that help you collect bolts."
4. "TIP: Never dodge left. Enemies expect this. Also never dodge right. Consider not being attacked."
5. "TIP: The double jump is a single jump performed twice. Do not tell physics."
6. "TIP: Reading tips during interstellar travel improves reaction time by 0%."
7. "TIP: Grind rails are perfectly safe. This tip was sponsored by the rails."
8. "TIP: If you die, try being at full health instead."
9. "TIP: Sprocket can hear you. Sprocket can always hear you. Compliment Sprocket."
10. "TIP: The Skyway race is easier if you keep looking where you want to go. Harder if you look at the ground. The ground knows this."

## 4. Trophy names that undercut the accomplishment

⚠ No achievement system exists yet — wiring these means building a small trophies panel
(EXTRAS screen) + unlock checks. Say the word and I'll add it; names for review first:
- **"Participation Foreseen"** — finish the tutorial planet.
- **"Percussive Diplomacy"** — 100 mallet KOs.
- **"Adequate."** — beat a boss without dying. (Grindstone's voice.)
- **"Refund Denied"** — die 10 times. 
- **"Sandwich Closure"** — finish Rusty's quests.
- **"Legally Distinct Champion"** — win every Grand Prix gold.
- **"Employee of the Month (Posthumous)"** — clear the Foundry.
- **"Read The Fine Print"** — collect all 35 memos.
- **"It's Not Hoarding If It's Bolts"** — bank 5,000 bolts.
- **"The Greeter Greeted"** — defeat GREETER PRIME.
- **"Window Shopper"** — leave the Galleria without buying a phone case.
- **"Backseat Firmware"** — let Super Sprocket get 25 KOs.

## 5. Deadpan Sprocket reactions to the player's plans

→ append to `BARKS.idle` / new `BARKS.plan` bucket (~line 9280). Trigger: idle near a boss
door, or hovering the shop's most expensive item.
1. "I see you eyeing the expensive one. I've pre-drafted the eulogy for our savings."
2. "Your plan has one step. I admire that. Structurally, I fear it."
3. "Statistically, charging straight in works 40% of the time, every time."
4. "Go on, take the zipline. I'll catalog your scream for the highlight reel."
5. "We could also NOT do this. Noting for the record that not doing this remains available."
6. "You have 4 HP and the confidence of a warranty that expired in 2049. Proceed."
7. "Ah, the 'hit it harder' doctrine. A classic. Peer-reviewed by nobody."
8. "I've alerted my next of kin. It's you. This system has flaws."

## 6. Racing vehicle disclaimers / warranty humor

→ race lobby footer rotation + countdown banner sublines (`OMNIGRAND PRIX` section, ~line 12330).
1. "Hoverboard warranty void where prohibited, which is everywhere the race takes place."
2. "The board hovers at a legally mandated distance from your safety."
3. "In the event of a crash, the board's black box will testify against you."
4. "Top speed is a suggestion. The wall is a fact."
5. "OMNIGRAND PRIX™ is not liable for finishes: photo, strong, or otherwise."
6. "This vehicle was inspected by Blartz. That sentence is the entire safety report."

---

## Already-wired new lines (from the approved v12 plan) — flag any you want changed
| Content | Location in index.html |
|---|---|
| Grand Galleria arrival/boss/ledger cutscenes | `CUTSCENES`: `arrive9`, `galleriaGreeter`, `galleriaLedger` |
| Memo epilogue cutscene | `CUTSCENES.epilogue` (plays at 35/35 memos) |
| 5 Galleria memos | `MEMOS` (last five entries) |
| Gilda (Kiosk #7) quests ×2 | `QUESTS`: `q6a`, `q6b` |
| Foundry intern quest | `QUESTS`: `q3b` |
| Core-planet late beats | `STORY`: `novaLate`, `glaciusLate`, `verdantLate` |
| Mall PA announcements ×3 | `GALLERIA_PA` (next to `buildGalleria`) |
| Race result quips ×3 | `raceFinish()` sponsor line |
| Race lobby/menu strings | `#race` screen HTML, `TRACKS` descriptions |
