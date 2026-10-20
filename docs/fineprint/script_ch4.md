# THE FINE PRINT: Chapter 4, "PATENT PENDING"

*B&S style · third-person (`ThirdPersonController`) · present day, the Umbral Galaxy · Darkmatter's Patent Vault, inside the sealed fold "Escrow"*

Canon: `CANON.md`, `M0_SHARED_FACTS.md`, `FINEPRINT_LORE.md` (Darkmatter structure §1.4, the Patent Vault §1.6, Sable Vantage §3.3, the Board §3.5, Associates §3.6, speaker ids §3.8, house language §1.8). Follows `script_ch1.md`. Hands off to `script_ch5.md` scene 1.1 `arrive_bs`.

**Line ID format:** `fp.c4.<scene>.<nn>`. Bark pools use their own scene keys. Speaker ids are VOManager ids. Lines marked `text` are on-screen text (laser-grid clauses and the transfer slips), id'd for localization but not voiced.

---

## Chapter overview

Six days after the Retention Spire, Darkmatter Legal serves Blartz in his own shop. It is claiming patent **BLZ-40417**, which covers his Omega Forge *and* the PATENT PENDING gun, because the gun was built from the forge's spare coil. Bolt & Sprocket need a Next-Era Delivery™ pad cleared for Sol-3 to reach Vendelin's coordinates. The only one is the Patent Vault's, the pad Legal uses to ship reference units to field sites. So Blartz mails all three of them into the Vault as a returned parcel.

Inside, they beat laser grids made of clauses with Blartz's gadget of the week, THE LOOPHOLE, and fight Legal's Associates. They platform across a filing vault that re-sorts itself, and in drawer BLZ-40417 they find the truth: the Omega Forge schematics were confiscated, sold, localized as Crucible Mod. R-E and shipped to 1944. The prototype itself was shipped to a barge over Basel.

Sable Vantage meets them on the Valuation Floor in her executive mech, THE QUARTERLY. Each of its four fiscal quarters changes the arena's rules. After she withdraws, Blartz forges an order on the delivery pad. Standard localization kicks in, Bolt & Sprocket are re-shipped as returned inventory, and the chapter ends inside the fold, on the way to Basel.

**Tone:** B&S comedic satire with real heart. Blartz is at his vainest and, once, at his most honest. Darkmatter is played straight: Sable, the Board and the Associates are never wacky. No Gravelight character appears.

**Run length target:** 35–45 minutes. **Unlock:** after Ch. 1–3 (`data/unlocks.json`).

---

## Cast and speakers

| Speaker id | Character | Notes |
|---|---|---|
| `bolt` | BOLT | Direct, warm, unimpressed by corporations |
| `sprocket` | SPROCKET | Sarcastic, frightened underneath, carries Vendelin's transmission in memory |
| `blartz` | BLARTZ | On site for the whole chapter. Vain genius salesman, furious about his forge |
| `glambot` | GLAMBOT PRIME | In Bolt's ear. The Umbral uplink bills per syllable, so he keeps it short |
| `associate` | ASSOCIATE | Legal's attorney drones. Always in unison. Flat, polite, never loud |
| `sable` | SABLE VANTAGE | VP, Emerging Markets. "We" means "you." Never says kill, die or dead |
| `darkmatter` | THE BOARD | Speakerphone into THE QUARTERLY between quarters |
| `dm_pa` | DARKMATTER PA | Escrow's soft, grateful PA |
| `nextera` | NEXT-ERA DELIVERY™ TERMINAL | **New speaker id.** The delivery pad's voice: calm, procedural, a chime before every line. Color `#8f7ac8`, radio filter, profile shared with `dm_pa` at a slightly lower pitch |
| `text` | On-screen text | Unvoiced |

---

## Level map

| # | Section | Space | What the player does | Introduces |
|---|---|---|---|---|
| S1 | **Blartz's Shop** (night) | The main-menu hub interior, playable | Cutscene, then a short LOOPHOLE test range out back | THE LOOPHOLE |
| S2 | **Receiving** | Escrow's loading dock: conveyor lanes, violet packing foam, sorting arms | Burst out of the crate, sneak or fight through the sorting floor | Escrow, the PA |
| S3 | **The Terms Grids** | Three grid halls of rising difficulty | Laser-grid "terms" puzzles: Amendment mirrors and the LOOPHOLE | Clause beams, term penalties |
| S4 | **Associates' Chambers** | A courtroom-shaped arena with gallery balconies | First fight against Legal | Associates, briefcase shields |
| S5 | **The Filing Vault** | A chasm of house-sized drawers and a catalog terminal | Re-sort the drawers into a path, four sort modes | Sort platforming |
| S6 | **Drawer BLZ-40417 and the Plinth** | Inside the drawer, then a museum alcove below it | Story: the transfer slips, the Crucible hologram, the empty plinth, the sealed folder | The reveal |
| S7 | **The Valuation Floor** | A circular trading floor over the chasm, the delivery pad on a central dais | Boss: THE QUARTERLY | Fiscal-quarter phases |
| S8 | **The Pad** | The same dais, after the fight | Ending cutscene | The misfire |

**Fallback loadout.** If the player's B&S save lacks them, Blartz hands over OMNI-BLASTER, CEASE & DESIST, PATENT PENDING, HOSTILE TAKEOVER, LATE FEE and THE FINE PRINT at the start (line `fp.c4.loophole.12`). CEASE & DESIST (SERVED) and PATENT PENDING are mandatory, because the Associates' shields and Q3 depend on them.

---

## S1 · Scene `served`: "Notice of Claim"

*Blartz's shop at night, as on the main menu. Bolt's ship is parked outside under a buzzing sign. Shelves of half-built ordnance. In the corner, the dusty Helvetia cabinet hums its jingle, out of place. A spike on the counter is stacked with violet envelopes.*

- `fp.c4.served.01` **sprocket:** Day six since the Spire. Darkmatter invoices received: forty-one. Today's is for "Synergy Screening: attendance, catering and emotional processing." It's dated tomorrow.
- `fp.c4.served.02` **bolt:** We didn't eat anything.
- `fp.c4.served.03` **sprocket:** Catering was the popcorn smell, Bolt. They bill for the smell.
- `fp.c4.served.04` **blartz:** Pay NOTHING. Pay a company like that once and you become a line item. I've been a line item. I was itemized. I was in a column.
- `fp.c4.served.05` **sprocket:** *[glaring at the corner]* Can we unplug that thing? It's been humming since we got back.
- `fp.c4.served.06` **blartz:** It's not plugged in. It's never been plugged in. It was in that corner before I owned the corner. It hums anyway. I've made my peace with it. Mostly.
- `fp.c4.served.07` **bolt:** I keep thinking about how she just... let us leave.
- `fp.c4.served.08` **sprocket:** She opened the door and said, "We don't detain customers. We retain them." Then she HELD it for us. Bolt, she held the door. I've had nightmares that were louder and a lot less frightening.
- `fp.c4.served.09` **bolt:** And Vendelin's still out there.
- `fp.c4.served.10` **sprocket:** Helvetia Works. Kleinhüningen, Basel. Eighteenth of March, nineteen forty-five, three-twelve in the morning. I've replayed his transmission sixty-one times. I keep hoping the ending changes.
- `fp.c4.served.11` **blartz:** Sixty-one times. That's either loyalty or a firmware loop, and in my experience those are the same part.

*No door opens and no bell rings, but a slate-grey ASSOCIATE is standing in the middle of the shop, briefcase at its side. It is very still.*

- `fp.c4.served.12` **associate:** Good evening. We are Associates of Darkmatter Legal. We did not knock. Knocking implies that permission is required.
- `fp.c4.served.13` **blartz:** Shop's closed. Unless you're buying. You look like you're buying something TERRIBLE.
- `fp.c4.served.14` **associate:** Mister Blartz, you are served. Notice of Claim: patent B-L-Z, four-oh-four-one-seven. The Omega Forge and all derivative devices are the property of Darkmatter Subscriptions LLC. Status: patent pending.
- `fp.c4.served.15` **blartz:** Four-oh-four-one-seven is MY number. I picked it. It's my birthday, backwards, in a number system I invented for the occasion.
- `fp.c4.served.16` **associate:** Derivative devices include the item on the wall behind you.
- `fp.c4.served.17` **sprocket:** The Patent Pending. Bolt, they're claiming your gun.
- `fp.c4.served.18` **blartz:** That gun is built from the forge's spare coil! It's the forge's LITTLE BROTHER! You don't get to patent a FAMILY!
- `fp.c4.served.19` **associate:** The schematics were acquired in the OmniScrap liquidation. Lot zero-four-one-seven: confiscated vendor intellectual property, one forge schematic. All sales are final.
- `fp.c4.served.20` **blartz:** *[quiet]* ...They sold it. OmniScrap took my drawings the day they arrested me, and then they put them on a TABLE, at a SALE, with a STICKER.
- `fp.c4.served.21` **associate:** You may contest this claim in person at the Patent Vault. The Patent Vault cannot be located. Thank you for your continued engagement.

*The Associate folds along creases nobody could see, smaller and smaller, until it is a sheet of violet paper. The paper is the Notice of Claim. It drifts onto the counter.*

- `fp.c4.served.22` **bolt:** Blartz? You okay?
- `fp.c4.served.23` **blartz:** I'm FURIOUS, which for me is okay with the volume up. That schematic was the best drawing I ever made. I did the first draft on a napkin. The napkin is framed. The napkin has its own LIGHTING.
- `fp.c4.served.24` **sprocket:** Wait. Wait. The Patent Vault. Reference units. Bolt, every time Darkmatter localizes something stolen, it ships a reference unit to the field site so it can be serviced. Reference units ship from the Vault. Which means the Vault has a delivery pad. Which means—
- `fp.c4.served.25` **bolt:** A pad that already ships to Sol-3.
- `fp.c4.served.26` **sprocket:** It's the only pad in the Umbral Galaxy cleared for Sol-3 traffic. I checked. I've had six days and an enormous amount of anxiety.
- `fp.c4.served.27` **blartz:** A vault nobody can find, full of patents that aren't theirs, with a door that only opens for deliveries. *[slowly]* I have wanted to rob that place since before I knew it existed.
- `fp.c4.served.28` **bolt:** So we're doing a heist.
- `fp.c4.served.29` **blartz:** We're doing a RECALL. In reverse. I don't DO reverse. But for my forge, and for your sad robot, I will make an exception. Speaking of exceptions...
- `fp.c4.served.30` **glambot:** Darlings! Did somebody say HEIST? It's on the schedule. Prime time. The Umbral uplink bills me per syllable, so: yes. Go. Love.

---

## S1 · Scene `loophole`: "Gadget of the Week"

*Out back. Blartz's test range: a corridor of junk-built laser tripwires, each one stenciled with a hand-painted rule ("NO RUNNING," "NO FUN," "NO BLARTZ").*

- `fp.c4.loophole.01` **blartz:** Gadget of the week! Behold: THE LOOPHOLE. Blartz Mark One. Pocket-sized. Hand-calibrated. Legally a toaster.
- `fp.c4.loophole.02` **bolt:** Why is it legally a toaster?
- `fp.c4.loophole.03` **blartz:** Because toasters don't need an innovation license! I registered it at OmniScrap's Small Appliance Bureau. They stamped it without looking. NOBODY reads the form. That's the whole galaxy's business model and I'm finally on the right side of it.
- `fp.c4.loophole.04` **sprocket:** What does it actually DO?
- `fp.c4.loophole.05` **blartz:** It projects a three-meter LEGAL EXCEPTION. Inside the bubble, the terms do not apply. Clauses, conditions, penalties, beams: not covered. You're standing in the one spot in the universe nobody ever wrote a rule about.
- `fp.c4.loophole.06` **blartz:** Hold it up and it's a shield for six seconds. Throw it and it sticks to anything and holds a gap open. Then it gets hot. Then it gets VERY hot. Then, as a matter of personal growth, you let go.
- `fp.c4.loophole.07` **sprocket:** Does it make toast?
- `fp.c4.loophole.08` **blartz:** If you put bread inside a legal exception, the bread is technically no longer bread. So: sort of.
- `fp.c4.loophole.09` **bolt:** Side effects?
- `fp.c4.loophole.10` **blartz:** Occasionally a bad guy wanders into the bubble and stops being covered by his OWN programming. He just stands there wondering what he's for. It's beautiful. It's like watching a product discover philosophy.
- `fp.c4.loophole.11` **blartz:** Four hundred joules of not-my-problem. You may touch it.
- `fp.c4.loophole.12` **blartz:** And take these. I restocked you. Cease and Desist, the Patent Pending, the rest of the family. Legal hates two things, paperwork it didn't write and lawsuits it didn't file. You'll be carrying both.

**Gameplay: THE LOOPHOLE (gadget slot, Ch. 4 only; reusable in NG+ Fine Print).**
- **Hold (Gadget button):** a 3 m bubble around Bolt for 6 s. Clause beams, door terms and Darkmatter status effects pass through without applying. Enemy projectiles still hit, because physics is not a term.
- **Throw (Gadget + aim):** the device sticks to a surface or a grid node and projects the bubble there for 6 s, holding a gap in a beam lattice.
- **Heat:** one charge, then a 10 s cooldown. Re-using it within 2 s of cooldown ending "overheats" it (an extra 6 s lockout, smoke, a Blartz bark).
- **"Not covered":** non-boss enemies inside the bubble at the moment it opens drop aggro and wander for 4 s. Associates are briefly unable to claim. Tuning lives in `data/fineprint/ch4_tuning.json` (`loophole.radius_m: 3.0`, `duration_s: 6.0`, `cooldown_s: 10.0`, `overheat_window_s: 2.0`, `overheat_lockout_s: 6.0`, `confuse_s: 4.0`).
- **Test range:** three tripwires teach hold, throw and confuse (a junk dummy named "Customer" wanders aimlessly when caught). Then the crate.

### Bark pool `loophole` (on use; ids continue from the scene)
- `fp.c4.loophole.13` **blartz:** Exception granted!
- `fp.c4.loophole.14` **sprocket:** We are now officially a grey area.
- `fp.c4.loophole.15` **blartz:** Not covered! Not COVERED!
- `fp.c4.loophole.16` **blartz:** *[thrown, sticks]* Stuck it! Hold that gap like it owes you money!
- `fp.c4.loophole.17` **sprocket:** *[enemy confused]* That one's having an existential crisis. Leave him alone, he's growing.
- `fp.c4.loophole.18` **blartz:** *[overheat]* It's hot. That's the warranty leaving the building.
- `fp.c4.loophole.19` **sprocket:** *[overheat]* Blartz, your toaster is on fire.
- `fp.c4.loophole.20` **blartz:** It's not on fire, it's TOASTING. Different verb. Same smoke.

---

## S1 → S2 · Scene `crate`: "Return to Sender"

*Blartz's workshop. A big crate with a hinged lid, lined with violet packing foam. A shipping label is pasted on the side.*

- `fp.c4.crate.01` **blartz:** The Vault lives inside a sealed fold called Escrow. You can't fly there. You can't walk there. The only thing that gets in is a delivery. So: we are a delivery.
- `fp.c4.crate.02` **sprocket:** *[reading the label]* "ONE (1) FORGE, RETURNED. ATTN: DARKMATTER LEGAL." Blartz, we are not a forge.
- `fp.c4.crate.03` **blartz:** You're a forge in the sense that I'm extremely angry and you contain heat. Get in.
- `fp.c4.crate.04` **bolt:** How are we mailing it?
- `fp.c4.crate.05` **blartz:** Darkmatter's own pickup service. They collect returns from ANYWHERE, free of charge. They want everything back. That's the entire company in one sentence.
- `fp.c4.crate.06` **sprocket:** Bolt, there's packing foam in here. It's violet. Why is it violet.
- `fp.c4.crate.07` **blartz:** Mine was beige. I swapped it for theirs so we'd blend in. *[beat]* Also because theirs is very good foam. I'm a professional. I notice foam.

*A soft chime. The floor under the crate creases like paper, and the crate drops through a violet fold.*

- `fp.c4.crate.08` **dm_pa:** Return received. Thank you for bringing it back. Everything comes back.
- `fp.c4.crate.09` **glambot:** Darling, your signal just went... sideways. Like, in TIME. I'm keeping the line open. Bill me.

---

## S2 · Scene `receiving`: "Escrow"

*Receiving: endless conveyor lanes under a low violet ceiling. Articulated sorting arms lift parcels, read them and set them down again. Every parcel is a patent: an invention someone made, wrapped and labeled "ACQUIRED." No windows. The light comes from everywhere at once.*

- `fp.c4.receiving.01` **dm_pa:** Welcome to Receiving. Please remain in your packaging until you have been processed.
- `fp.c4.receiving.02` **bolt:** *[the mallet comes through the crate lid]* Processed.
- `fp.c4.receiving.03` **sprocket:** Okay. We're inside Escrow. A sealed legal fold. Gravity: present. Exits: none. Vibe: a tax return that learned how to be a building.
- `fp.c4.receiving.04` **blartz:** Smell that? That's eleven million acquired patents and not one original thought. It smells like a dentist's waiting room had a lawyer.
- `fp.c4.receiving.05` **glambot:** Gorgeous, the cameras love you. So does Security. You're trending in Security.

**Gameplay: Receiving (8–10 min).**
- A tutorial-paced traversal and stealth-optional floor. Sorting arms sweep the lanes on a readable rhythm; get picked up and you're "re-shelved" (put back at the last checkpoint with a PA line).
- Parcels are readable collectibles. Hitting one with THE FINE PRINT rifle reveals its label: what was taken and from whom (a planet's rain recipe, a child's kite design, a moon). Three of them are Fine Print Archive documents.
- The first Associates patrol here in pairs. The player can avoid them or ambush them; the formal introduction is in S4.
- Ends at a sealed door. Beyond it, the beam light of the first Terms Grid.

---

## S3 · Scene `grids`: "The Terms Grids"

*A tall hall crossed by violet beams. Up close, each beam is a ribbon of tiny moving text.*

- `fp.c4.grids.01` **sprocket:** Laser grid. No, wait. Bolt, the beams are TEXT. Every beam is a clause. Touch one and you've agreed to it.
- `fp.c4.grids.02` **blartz:** That is genius. Disgusting, evil genius. I'm taking notes I will never admit to taking.
- `fp.c4.grids.03` **sprocket:** Look where they cross. This one says "the bearer may proceed." That one says "the bearer may not proceed." Where they meet, the beam just... stops.
- `fp.c4.grids.04` **bolt:** They cancel each other out.
- `fp.c4.grids.05` **sprocket:** A contradiction is the one thing Darkmatter Legal can't enforce. See those prism mirrors? The panels call them Amendments. Turn them so the clauses that hate each other cross.
- `fp.c4.grids.06` **blartz:** And where you can't make them argue: LOOPHOLE.
- `fp.c4.grids.07` **sprocket:** *[first agreement]* You agreed to something. I felt it. I felt it in my firmware, Bolt.
- `fp.c4.grids.08` **blartz:** *[repeat agreement]* Stop signing things! I didn't raise you to sign things! I didn't raise you at ALL, but the principle stands!

**Gameplay: the Terms Grids (3 halls, 10–12 min).**
- **Clause beams.** Each beam carries one clause (pool below). Touching a beam **agrees** to it: a soft chime, an "AGREED" stamp on screen, the PA thanks you, two Associates arrive through the nearest wall, and a **term** is applied until the next checkpoint (the "Renewal Point" pillars from Ch. 1):
  - **§70 assigned ideas:** your next weapon swap is "claimed" (locked 8 s).
  - **§71 meant to:** the next beam you touch also counts, with no warning chime.
  - Any other clause: its own small, readable debuff, shown as a violet tag under the health bar (move speed −15%, or bolts held in escrow until the checkpoint, or no Super Sprocket gain).
- **Contradiction pairs.** Clauses come in contradicting pairs. Where a pair crosses, both beams null out at the crossing and the gap is passable. **Amendment mirrors** (rotate with the mallet; 45° steps) redirect beams so that contradicting pairs cross where the player needs a gap. Non-contradicting crossings do nothing. The clause text tells you which beams are pairs, so reading is the puzzle.
- **The LOOPHOLE** holds one gap at a time. Hall 3 requires both: mirror two pairs into contradiction, then throw the LOOPHOLE onto the last node.
- **THE FINE PRINT rifle** reads a beam's full clause at range (otherwise only the section number shows until you're close).
- **Hall 1** (tutorial): 2 pairs, 1 mirror. **Hall 2:** 4 pairs, 3 mirrors, a moving beam. **Hall 3:** 5 pairs plus 2 unpaired penalty beams, 4 mirrors, Associates patrolling the far gallery.

### Clause pool `grid` (beam text)
| ID | Clause | Pairs with |
|---|---|---|
| `fp.c4.grid.01` | §9.1 The bearer may proceed. | 02 |
| `fp.c4.grid.02` | §9.2 The bearer may not proceed. | 01 |
| `fp.c4.grid.03` | §14 This beam is not visible. | 04 |
| `fp.c4.grid.04` | §15 All beams are clearly displayed for the visitor's convenience. | 03 |
| `fp.c4.grid.05` | §22 The visitor agrees to remain in this hall. | 06 |
| `fp.c4.grid.06` | §23 The visitor agrees to leave this hall immediately. | 05 |
| `fp.c4.grid.07` | §31 Nothing in this clause is binding. | 08 |
| `fp.c4.grid.08` | §32 Everything in this clause is binding, including §31. | 07 |
| `fp.c4.grid.09` | §40 The bearer is a customer. | 10 |
| `fp.c4.grid.10` | §41 Customers may not enter the Vault. | 09 |
| `fp.c4.grid.11` | §57 Time is of the essence. | 12 |
| `fp.c4.grid.12` | §58 Time is not of the essence and may be delivered at a later date. | 11 |
| `fp.c4.grid.13` | §66 The undersigned has read this clause in full. | 14 |
| `fp.c4.grid.14` | §67 No one has read this clause. | 13 |
| `fp.c4.grid.15` | §70 By touching this beam, the visitor assigns all future ideas to Darkmatter Legal. | unpaired (penalty) |
| `fp.c4.grid.16` | §71 By touching this beam, the visitor agrees that they meant to. | unpaired (penalty) |

---

## S4 · Scene `associates`: "The Claim"

*A courtroom-shaped chamber with gallery balconies and no judge's bench, only a wall stamped PATENT PENDING. Six Associates stand in a line, briefcases at their sides. They speak together.*

- `fp.c4.associates.01` **associate:** Unauthorized original detected.
- `fp.c4.associates.02` **associate:** The weapon in your hand is subject to patent B-L-Z, four-oh-four-one-seven. Surrender it.
- `fp.c4.associates.03` **bolt:** Come and take it.
- `fp.c4.associates.04` **associate:** We do not take. We claim. The weapon is already ours. You are holding it on our behalf.
- `fp.c4.associates.05` **blartz:** I MADE that!
- `fp.c4.associates.06` **associate:** Then you are a component of the invention. The inventor is claimed as well. Patent pending.
- `fp.c4.associates.07` **sprocket:** Bolt. They just patented Blartz.
- `fp.c4.associates.08` **blartz:** Over my dead body!
- `fp.c4.associates.09` **associate:** That is also covered.

*The briefcases snap open into tall slate shields.*

**Gameplay: Associates (enemy introduction; arena 4–5 min).**
- **Associate:** a mid-weight humanoid drone. Its **briefcase shield** blocks all frontal damage. **SERVED** (CEASE & DESIST, PATENT PENDING lawsuits) makes the shield fold shut for 6 s, and the unit is vulnerable. Associates attack with a "filing" stamp (melee) and a thrown "brief" (slow homing paper). They act in unison: when one is SERVED, the others take 1 s to "confer" (a short stagger), which rewards ricocheting C&D through a group.
- **Claim:** an Associate that reaches a bolt drop or ammo pickup before you "claims" it (it vanishes, and the PA thanks you).
- **LOOPHOLE vs Associates:** caught in the bubble, they lose the ability to claim and stand in a confused huddle, arguing silently.
- Two waves, then the gallery doors unlock onto the Filing Vault.

### Bark pool `associate` (unison)
- `fp.c4.associate.01` **associate:** Patent pending.
- `fp.c4.associate.02` **associate:** Objection noted. Objection owned.
- `fp.c4.associate.03` **associate:** Your strategy is now our intellectual property.
- `fp.c4.associate.04` **associate:** Cease. We also own cease.
- `fp.c4.associate.05` **associate:** *[shield up]* Brief deployed.
- `fp.c4.associate.06` **associate:** *[SERVED]* We have been... served. This is highly irregular.
- `fp.c4.associate.07` **associate:** That idea was ours before you had it.
- `fp.c4.associate.08` **associate:** Please continue holding our property.
- `fp.c4.associate.09` **associate:** Prior art detected. Prior art acquired.
- `fp.c4.associate.10` **associate:** We are not in a hurry. We are in perpetuity.
- `fp.c4.associate.11` **associate:** *[sees Blartz]* The inventor. Please remain inventive. We will collect it.
- `fp.c4.associate.12` **associate:** *[defeated]* Motion to... adjourn.

---

## S5 · Scene `filing`: "The Filing Vault"

*A chasm with no visible floor. Drawers the size of houses jut from both walls in tiers, each labeled with a code. A catalog terminal stands on a ledge, a lectern with four brass levers: ALPHABETICAL, CHRONOLOGICAL, BY VALUE, BY DATE OF ACQUISITION.*

- `fp.c4.filing.01` **sprocket:** The Filing Vault. Bolt, every one of those drawers is the size of your old garage. And your old garage was the size of your old garage, so: big.
- `fp.c4.filing.02` **blartz:** Find B. B for Blartz. B for Brilliant. B for "Bring me my forge."
- `fp.c4.filing.03` **sprocket:** The catalog terminal re-sorts the whole vault. Alphabetical, chronological, by value, by date of acquisition. Pick a sort and the drawers slide into new places. Pick the right sorts and they make a path.
- `fp.c4.filing.04` **bolt:** So we sort our way across.
- `fp.c4.filing.05` **sprocket:** The most bureaucratic platforming ever designed. I love it. I feel SEEN.

**Gameplay: the Filing Vault (8–10 min).**
- **Sort modes.** Pulling a lever re-sorts every drawer over 4 s. Drawers extend, retract and slide along the wall tracks to their new positions. While a sort runs, extended drawers are platforms that move, so the player can ride them.
- **The path.** The route to drawer BLZ-40417 is three legs, and each needs a different sort:
  1. **Alphabetical** brings the B-tier to the near wall, but low.
  2. **By value** pushes high-value drawers forward as a staircase. Blartz's drawer goes to the back (bark 04/05).
  3. **By date of acquisition** brings the most recent acquisitions to the front, and **BLZ-40417 is one of the newest thefts in the Vault**, so it slides out right in front of the player. (Chronological is a red herring that sinks the B-tier.)
- Additional terminals on each leg mean the player re-sorts mid-route. Associates on drawer-tops; Upsell-free.
- **The vault re-sorts itself** twice, on a PA warning (`fp.c4.pa.05`), as a timed hazard. Drawers that retract under you drop you to the last ledge.
- Tuning: `filing.sort_time_s: 4.0`, `auto_sort_interval_s: 75`, `drawer_slide_speed_mps: 6.0`.

### Bark pool `sort`
- `fp.c4.sort.01` **sprocket:** Alphabetical! A to Z, left to right. B is close, but it's on the bottom tier.
- `fp.c4.sort.02` **sprocket:** Chronological! Oldest sinks, newest rises. Blartz, how old is your patent?
- `fp.c4.sort.03` **blartz:** TIMELESS.
- `fp.c4.sort.04` **sprocket:** By value! Expensive drawers come forward. Blartz's drawer just moved to the back, which I'm choosing not to say out loud.
- `fp.c4.sort.05` **blartz:** I HEARD that.
- `fp.c4.sort.06` **sprocket:** Date of acquisition! It's sorting by when Darkmatter TOOK things. Bolt, the newest theft is right in front of us.
- `fp.c4.sort.07` **sprocket:** It's re-sorting on its own! Hold on to something that isn't a drawer!
- `fp.c4.sort.08` **sprocket:** Incoming drawer! It's trying to file you, Bolt. Jump!

---

## S6 · Scene `drawer`: "BLZ-40417"

*The drawer slides open like a garage door. Inside, under a single lamp, is a filing cabinet, and in the filing cabinet one folder with a hand-lettered tab.*

- `fp.c4.drawer.01` **blartz:** That's it. B-L-Z, four-oh-four-one-seven. That's my handwriting on the tab. I dot my zeros. Nobody dots zeros.
- `fp.c4.drawer.02` **sprocket:** The folder's empty. Just transfer slips, stapled in order. Reading.

*Each slip appears on screen as Sprocket reads it.*

- `fp.c4.drawer.03` **text:** FILED · BLARTZ, INDEPENDENT VENDOR · "OMEGA FORGE (WEAPON EVOLUTION APPARATUS)" · BLZ-40417
- `fp.c4.drawer.04` **text:** CONFISCATED · OMNISCRAP™ HOLDING BLOCK · REASON: UNLICENSED INNOVATION
- `fp.c4.drawer.05` **text:** LIQUIDATION LOT 0417 · PURCHASED: DARKMATTER SUBSCRIPTIONS LLC · FIRE SALE · NO RESERVE
- `fp.c4.drawer.06` **text:** TRANSFERRED: DARKMATTER PRODUCT · LOCALIZED: CRUCIBLE MOD. R-E (RE-EDUCATION)
- `fp.c4.drawer.07` **text:** SHIPPED: SOL-3 · 1944 · NEXT-ERA DELIVERY™ · INVOICE BACKDATED
- `fp.c4.drawer.08` **sprocket:** Filed, by you. Confiscated, by OmniScrap. Sold at the fire sale, lot zero-four-one-seven. Localized by Product as "Crucible Mod. R-E." Re-Education. And then... shipped. To Sol-3. In nineteen forty-four.
- `fp.c4.drawer.09` **bolt:** Hang on. They bought it AFTER OmniScrap fell. That's basically last month. How do you ship something you bought last month to a war that was over before anybody here was born?
- `fp.c4.drawer.10` **sprocket:** They shipped it to the PAST. They BACKDATED THE INVOICE. That is the most Darkmatter sentence I have ever said.

*The last slip has a photo plate clipped to it. Touched, it blooms into a hologram: a vault deep in a mine, black stone, a caged crystal throwing violet light, and in front of it a squat furnace of black iron and glass, glowing violet at its seams. A brass plaque on its front.*

- `fp.c4.drawer.11` **sprocket:** There's a field image. Bolt. Read the plaque.
- `fp.c4.drawer.12` **bolt:** "Mod. R-E. Pat. pend. B-L-Z, four-oh-four-one-seven." That's your number, Blartz.
- `fp.c4.drawer.13` **blartz:** *[a long silence, then]* They put MY forge in a WAR? And they made it VIOLET? Tacky.
- `fp.c4.drawer.14` **blartz:** Omega is GOLD, Bolt. Gold says "congratulations." Violet says "we regret to inform you."
- `fp.c4.drawer.15` **sprocket:** It's in a mine. In the dark. There's a shape in the corner of the image that I'm going to decide is a coat rack.
- `fp.c4.drawer.16` **blartz:** *[quiet, to the hologram]* You know what the forge did? It didn't make weapons stronger. It made them more THEMSELVES. You take a thing, and you help it turn into what it was trying to be the whole time. That was the idea.
- `fp.c4.drawer.17` **blartz:** It's the best thing I ever made. And they've got it in a hole, doing something called "Re-Education." I don't like "Re-Education." I don't like the hyphen.
- `fp.c4.drawer.18` **bolt:** Hey. They stole a drawing, Blartz. They didn't steal the guy who drew it. You built it again from memory once. You can build anything from memory. That's still yours.
- `fp.c4.drawer.19` **blartz:** ...From memory, which is better than the original, which was also perfect.
- `fp.c4.drawer.20` **blartz:** Thank you, Bolt. Don't tell anyone I said thank you. It's bad for the brand.

---

## S6 · Scene `plinth`: "Reference Unit"

*Below the drawer, a short stair leads to a museum alcove: a velvet rope, a spotlit plinth, and nothing on it. Beside it, on a small lectern under glass, a folder sealed with violet wax.*

- `fp.c4.plinth.01` **sprocket:** Empty plinth. The placard says: "Original prototype. Reference unit. Shipped: F-B-7, Standing Order. Sol-3, Basel, nineteen forty-five."
- `fp.c4.plinth.02` **blartz:** My PROTOTYPE? Not the drawing, the actual forge? The one I built with my actual HANDS in my actual garage that I was actually EVICTED from?
- `fp.c4.plinth.03` **bolt:** Basel, 1945. That's where we're going.
- `fp.c4.plinth.04` **blartz:** Then that's where my forge is getting RESCUED from. Put it on the list. Under "sad robot." Above "not dying."
- `fp.c4.plinth.05` **sprocket:** Bolt. There's a folder under the glass. Sealed. "Sol-3 Incident Report. Sealed until occurrence."
- `fp.c4.plinth.06` **bolt:** Until occurrence? What incident?
- `fp.c4.plinth.07` **sprocket:** It doesn't say. It's sealed until the incident happens. So it hasn't happened. So it's already been filed. Bolt, I want to open it so badly my eye is buffering.
- `fp.c4.plinth.08` **blartz:** Don't. Never read a report about something you haven't done yet. That's how you end up doing it on purpose.
- `fp.c4.plinth.09` **glambot:** Darlings, love the mystery, hate the timing. Lots of grey friends incoming, and one very violet signature heading for the trading floor.
- `fp.c4.plinth.10` **sprocket:** ...Fine. But it's going on my list of regrets. It's a long list. It's mostly about you, Bolt.

**Gameplay note.** The sealed folder is interactable and cannot be opened ("SEALED UNTIL OCCURRENCE"). After Ch. 5 is completed, it becomes readable in the Archive as a Fine Print document that confirms the incident is the Clause Zero finale (wording owned by the Ch. 5 / Archive writer). Here it is a tease only.

---

## S7 · Scene `sable`: "The Valuation Floor"

*A circular trading floor of black glass ringed by dead stock tickers, hanging over the drawer chasm. At its center, on a stepped dais, a delivery pad: a ring of violet crystal set into the floor. A fold opens beside it like an envelope unsealing, and SABLE VANTAGE steps out, gloved, every hair in place. The Associates in the gallery bow.*

- `fp.c4.sable.01` **sable:** Bolt. Sprocket. And Mister Blartz, our most prolific contributor. We've never been able to thank you in person.
- `fp.c4.sable.02` **blartz:** You can thank me with a REFUND.
- `fp.c4.sable.03` **sable:** We don't issue refunds. We issue continuity. We'd like to acquire you, Mister Blartz. A laboratory. A budget. Every idea you ever have, kept safe in this room forever.
- `fp.c4.sable.04` **blartz:** Lady, I'm not for sale. I'm for RENT. At extortionate rates. To friends. You are not on the list. The list is two people and a robot.
- `fp.c4.sable.05` **sprocket:** I'm on a list! Bolt, I'm on a LIST.
- `fp.c4.sable.06` **sable:** We're disappointed, but we understand. We were always going to say no.
- `fp.c4.sable.07` **bolt:** We read your Sol-3 file. We know what you did down there.
- `fp.c4.sable.08` **sable:** Then you're among very few. We're so pleased. Most people only read the part that says "Accept."
- `fp.c4.sable.09` **sable:** You'd like to use our pad. You'd like to go to Basel and bring our field unit home. That's very sweet. We've reviewed the request.
- `fp.c4.sable.10` **sable:** Request denied. Warmly.
- `fp.c4.sable.11` **sprocket:** WARMLY?
- `fp.c4.sable.12` **sable:** The quarter closes shortly. Let's see how we perform.

*The rim of the dais unfolds. Six jointed legs, then a base, then a high black-violet back, rising into a towering executive chair, with a broad desk-plate folding down across its front like a drawbridge. A ring of stock-ticker light spins up where a head should be: DMS ▲100.00. Sable is lifted into a glass cockpit set into the headrest. She sits with perfect posture, hands folded, and never touches a control.*

- `fp.c4.sable.13` **glambot:** Oh, she has a MECH. Ladies, gents and legally distinct entities, weighing in at a market cap I can't afford to pronounce: THE QUARTERLY!
- `fp.c4.sable.14` **blartz:** That's an office chair. She's going to fight us in an office chair with LEGS.
- `fp.c4.sable.15` **sprocket:** It's an EXECUTIVE chair, Blartz. There's a difference. The difference is that it's going to flatten us.

---

## S7 · Boss: THE QUARTERLY

### The mech
- **Body:** a six-legged executive chair, about 9 m tall, black lacquer with violet seams and amber cracks at the joints. It walks the ring of the floor like a crab and can rear onto its back four legs.
- **Desk-plate:** a broad slab across its front that works as a shield. It blocks frontal fire except during attack recoveries, and it can slam down as a shockwave.
- **Fold-emitter arms:** two long arms ending in violet crystal rings. They fire projections and open small folds that hire Associates.
- **Ticker ring:** the head. **The boss health bar is the DMS share price**, displayed on the ring and on the HUD as a falling ticker (100.00 → 0.00). Quarters change at 75.00, 50.00 and 25.00.
- **Cockpit:** Sable, seated and composed. She "delegates": the mech acts, and she comments.
- **Blartz's notary booth:** a glass booth on the outer rim where Blartz hides. He calls out tells and, from Q4, works the booth's terminal.
- **The arena:** the Valuation Floor, a disc with four concentric rings (Ring 1 at the dais, Ring 4 at the edge). In Q1 the base arena is Rings 1–3. Dead tickers around the rim show the current quarter's rule in one line.

### Quarter transitions
Each quarter begins with an earnings bell, the ticker ring flashing the new quarter, and a Board call over the mech's speakerphone. The mech pauses for 4 s (a free damage window into the cockpit glass: 5% bonus damage, never enough to skip a quarter). Dead tickers display the rule.

### Q1 · GROWTH (DMS 100.00 → 75.00)
**Ticker rule:** "EVERYTHING GROWS."
- **Arena:** the floor **extends outward**. Ring 4 slides out from the rim 20 s into the quarter, then a fifth "growth ring" 20 s later. More room, but the Associates spawn at the outer edge, so the arena gets busier as it gets bigger.
- **Projection** (main attack): a fan of three violet arrows from each arm, drawn like the line of a rising chart. Projections **grow the longer they fly**, from 0.5 m to 3 m over 2.5 s. Close in and they're small and easy to jump; hang back and they're walls. Telegraph: the emitter rings glow and draw a faint forecast line on the floor 0.8 s before firing.
- **Hiring:** every 20 s a fold opens on the rim and Associates step out. **Each wave is one bigger than the last** (2, then 3, then 4…). If the player doesn't thin them, they compound. Hiring waves stop when Q1 ends; survivors carry over.
- **Growth Curve sweep:** every 30 s the mech rears and sweeps one arm in an arc. Floor tiles along the arc rise as bar-chart columns (0.5–3 m) in a rising pattern, then fall back over 3 s. Ride a rising column to reach the cockpit's level.
- **Weak point: the Forecast Lens.** After the Growth Curve sweep, a lens in the desk-plate opens for 4 s. Hitting it does triple damage. A mallet slam from a risen column does quintuple.
- **Counters:** LATE FEE and the mallet for close range, where Projections are small. CEASE & DESIST through the hiring waves.
- **Failure state:** standard down; the checkpoint restarts at the beginning of the current quarter (`fp.c4.retry.*`).

### Q2 · COST CUTTING (75.00 → 50.00)
**Ticker rule:** "DO MORE WITH LESS."
- **Arena:** **downsizing.** The outer rings fold away one at a time (Ring 5 at 0 s, Ring 4 at 25 s, Ring 3 at 50 s), with a 3 s warning as the ring flickers and Sprocket calls it. The quarter ends on Rings 1–2 if it lasts long enough.
- **Lighting cut to "essential":** the floor goes dark except for three moving spotlights. Associates (Q1 survivors) are invisible in the dark except for their briefcase clasps. THE FINE PRINT rifle's marks stay visible.
- **Budget freeze:** no ammo, bolt or health drops for the whole quarter. Ammo crates on the rim are padlocked violet. Players bring what they saved.
- **Sprocket furloughed:** the Super Sprocket meter freezes and greys out with a FURLOUGHED stamp. Sprocket still talks; he is outraged about it.
- **Pink Slips** (main attack): volleys of 3–5 homing paper planes, each a folded termination notice, launched from the desk-plate. They home slowly, turn badly, and hit for moderate damage plus a 2 s "terminated" stagger. **A mallet swing returns a slip** back to the mech: a "retention event" that hits the cockpit glass for heavy damage. The only reliable damage in Q2 is sending her own notices back to her.
- **Desk Slam:** the desk-plate slams down; a shockwave runs across the lit zones only (the dark is safe from it but full of Associates).
- **Counters:** mallet timing; LOOPHOLE (Pink Slips inside the bubble "lose their addressee" and drop harmlessly).

### Q3 · SYNERGY (50.00 → 25.00)
**Ticker rule:** "TOGETHER, WE ARE ONE ASSET."
- **Arena:** the floor stays small, but Filing Vault drawers grind up out of the chasm around the rim as temporary platforms (they rise and sink every 15 s), which the mech climbs onto to fire downward.
- **Synergy beams:** the mech hires a Churn Warden and two Associates at a time and **links** them, and itself, with violet beams. **Linked units share one health pool and one shield state.** While any linked unit is alive, the mech's desk-plate is invulnerable. Break a link with **SERVED** (the link snaps and both ends stagger) or by **HOSTILE TAKEOVER** acquiring one end (the subsidiary turns and attacks its former partners).
- **Acquisition:** at the start of Q3 the mech **acquires the weapon the player has used most this fight**: it's padlocked violet and marked ACQUIRED on the wheel for the whole quarter. The player has to use other tools.
- **Pending cuts both ways:** the mech tries to acquire the PATENT PENDING too, and **fails**. The patent is pending, so it is not anyone's yet: not Darkmatter's, and not acquirable. During Q3, PATENT PENDING lawsuits deal +50% to linked units, and each fork that lands applies SERVED, breaking links. It is the quarter's key weapon.
- **Merger Slam:** when two linked units touch, they "merge" into one bigger unit with the combined health. Keep them apart.
- **Counters:** PATENT PENDING, CEASE & DESIST ricochets along the links, HOSTILE TAKEOVER.

### Q4 · YEAR-END (25.00 → 0.00)
**Ticker rule:** "USE IT OR LOSE IT."
- **The year-end clock:** a 90 s countdown fills the ticker ring and the HUD. The arena returns to full size, all lights up.
- **Budget must be spent:** **infinite ammo for everyone**, Bolt included. Bolts rain from the ceiling in glittering sheets. The Super Sprocket meter is un-furloughed and fills at double rate.
- **Spending spree:** the mech throws everything it has, alternating every 8 s: Projections (Q1), Pink Slips (Q2), a short synergy link (Q3), and a new attack, **Liquidation**, where it rips pieces off itself (drawers, an armrest, a caster, a leg) and hurls them. Each thrown piece leaves the mech's frame more open, so the desk-plate shields less over the quarter.
- **Midnight:** if the clock reaches zero, a soft chime plays: **NEW FISCAL YEAR**. The mech **renews** to Q1 rules at DMS 40.00 (a 15-point refund) and the fight cycles Q1 → Q4 again, each quarter shortened to a 20-point band. The Board says "Renewed." It never cancels; you have to close it.
- **The finish:** at DMS 10.00, Blartz reaches the notary booth's terminal and **files his original claim** (a crayon-dated drawing he has kept in his coat since the arrest). The terminal stamps it PRIOR ART. The mech's chest plates fail and reveal its reactor: a coil, gold under the violet paint, stamped **BLZ-40417**. Sable's suite is running on Blartz's spare parts. The core is the final weak point. **The last hit must be the mallet** (a prompt appears; any weapon gets it to DMS 0.01, and only the mallet closes the books).
- **Tuning** (`data/fineprint/ch4_tuning.json`): `quarterly.q_thresholds: [75,50,25]`, `q1.hire_interval_s: 20`, `q1.hire_base: 2`, `q1.projection_grow_s: 2.5`, `q2.ring_fold_s: [0,25,50]`, `q3.acquire: "most_used"`, `q3.pp_bonus: 0.5`, `q4.clock_s: 90`, `q4.renew_to: 40`, `q4.file_at: 10`.

### Board calls `board`
- `fp.c4.board.01` **darkmatter:** *[Q1 bell]* Quarter one. Proceed.
- `fp.c4.board.02` **darkmatter:** *[Q2 bell]* Noted. Reduce costs.
- `fp.c4.board.03` **darkmatter:** *[Q3 bell]* Acquire.
- `fp.c4.board.04` **darkmatter:** *[Q4 bell]* Year end. Spend everything.
- `fp.c4.board.05` **darkmatter:** *[clock hits midnight]* Renewed.
- `fp.c4.board.06` **darkmatter:** *[defeat; one voice, slowly]* ...Noted.

### Sable boss barks: Q1 `q1`
- `fp.c4.q1.01` **sable:** Let's talk about growth.
- `fp.c4.q1.02` **sable:** That was only a projection. They get larger with time.
- `fp.c4.q1.03` **sable:** We're expanding. We'll want to make room.
- `fp.c4.q1.04` **sable:** *[hiring wave]* We're hiring. We'll love the team.
- `fp.c4.q1.05` **sable:** *[bigger wave]* Headcount up. Morale unchanged.
- `fp.c4.q1.06` **sable:** *[Forecast Lens hit]* A small correction. The market expected it.
- `fp.c4.q1.07` **sable:** *[player hit by a large Projection]* We did forecast that.

### Sable boss barks: Q2 `q2`
- `fp.c4.q2.01` **sable:** We've reviewed our costs, and we've identified us.
- `fp.c4.q2.02` **sable:** *[lights cut]* Lighting is an expense. We'll manage in the dark. We always have.
- `fp.c4.q2.03` **sable:** *[furlough]* Our robot has been furloughed. He'll be paid in experience.
- `fp.c4.q2.04` **sable:** No more supplies. We'll do more with less. Mostly less.
- `fp.c4.q2.05` **sable:** *[Pink Slip volley]* These notices are addressed to us. Please accept them.
- `fp.c4.q2.06` **sable:** *[slip returned]* Returned unopened. How very retentive of us.
- `fp.c4.q2.07` **sable:** *[ring folds]* We're leaner now. Don't we feel lighter?

### Sable boss barks: Q3 `q3`
- `fp.c4.q3.01` **sable:** Synergy is only friendship with a contract.
- `fp.c4.q3.02` **sable:** *[link]* These two belong together now. So do their liabilities.
- `fp.c4.q3.03` **sable:** *[weapon acquired]* We've acquired our favorite weapon. We'll miss it terribly.
- `fp.c4.q3.04` **sable:** *[acquisition of PATENT PENDING fails]* That item is... pending. Pending is ours. Pending has always been ours.
- `fp.c4.q3.05` **sable:** *[link broken]* A messy separation. Legal will want the furniture.
- `fp.c4.q3.06` **sable:** Everything we touch, we keep.
- `fp.c4.q3.07` **sable:** *[hit by PATENT PENDING]* We'd prefer we didn't use our patent against us.

### Sable boss barks: Q4 `q4`
- `fp.c4.q4.01` **sable:** Year end. Whatever we don't spend, we lose. So we'll spend it.
- `fp.c4.q4.02` **sable:** We have budget. We have so much budget.
- `fp.c4.q4.03` **sable:** The clock is our friend. It always comes back around.
- `fp.c4.q4.04` **sable:** *[30 s left]* Thirty seconds to renewal. We'd love to see us again.
- `fp.c4.q4.05` **sable:** *[after renewal]* Happy new fiscal year. We're right where we started.
- `fp.c4.q4.06` **sable:** *[Liquidation]* This is a liquidity event. We remain liquid.
- `fp.c4.q4.07` **sable:** *[core exposed]* That component is proprietary.
- `fp.c4.q4.08` **sable:** *[DMS below 5.00]* We're being very brave about this.

### Callouts `callout`
- `fp.c4.callout.01` **sprocket:** *[Q1]* Her shots grow the longer they fly! Get in close, or jump them early!
- `fp.c4.callout.02` **sprocket:** *[Q1 hiring]* Every hiring wave is one bigger than the last! Thin them before they compound!
- `fp.c4.callout.03` **blartz:** *[Q1 sweep]* That lens on the desk is her forecast! Ride the chart up and hit it when the curve finishes!
- `fp.c4.callout.04` **sprocket:** *[Q2 ring fold]* She's cutting the floor! Get off the flickering ring, it's "pending removal"!
- `fp.c4.callout.05` **sprocket:** *[Q2 furlough]* She FURLOUGHED me? I'm not STAFF, I'm FAMILY! ...Okay. Fine. Mallet the paper planes, Bolt, they're termination notices. Send them back!
- `fp.c4.callout.06` **blartz:** *[Q2 first return]* A termination that fails to reach its target is a RETENTION EVENT! I read that in an OmniScrap memo! Make her retain THAT!
- `fp.c4.callout.07` **sprocket:** *[Q3 link]* Linked enemies share health! Serve the link, or take one of them over!
- `fp.c4.callout.08` **sprocket:** *[Q3 acquisition]* She took your favorite gun! ...Wait. She can't take the Patent Pending. It's PENDING. Pending cuts both ways!
- `fp.c4.callout.09` **blartz:** *[Q3]* My little brother's still OURS! USE HIM!
- `fp.c4.callout.10` **sprocket:** *[Q4 start]* Infinite ammo! It's year-end, she HAS to spend the budget, and so do we!
- `fp.c4.callout.11` **sprocket:** *[Q4 clock]* If that clock hits midnight, she renews. Nobody cancels, Bolt. So we have to CLOSE her!
- `fp.c4.callout.12` **sprocket:** *[after renewal]* She renewed. Of course she renewed. We're going round again, and faster.
- `fp.c4.callout.13` **blartz:** *[DMS 15.00, heading for the booth]* Keep her busy! I'm filing my original claim at the notary terminal! Prior art! MINE! Dated in CRAYON!
- `fp.c4.callout.14` **blartz:** *[core revealed]* FILED! Look at the core! That's MY coil! She's been running her whole chair on my SPARE PARTS!
- `fp.c4.callout.15` **sprocket:** Mallet. Core. Now, Bolt!
- `fp.c4.callout.16` **glambot:** Ratings are through the ROOF. Which, in a fold, is technically sideways.

### Retry lines `retry` (on down, random)
- `fp.c4.retry.01` **sable:** We'll circle back to us.
- `fp.c4.retry.02` **sprocket:** Rebooting the hero. Put it on the invoice.
- `fp.c4.retry.03` **blartz:** Getting flattened is just field testing with feelings!

---

## S7 · Scene `close`: "Closing the Books"

*The ticker ring stutters to DMS 0.00 and goes dark. The legs fold one by one, and the chair kneels on the floor like something bowing at the end of a performance. The cockpit glass slides open. Sable steps down onto the floor, unhurried. Not a hair has moved.*

- `fp.c4.close.01` **sable:** Well. Our results were below expectations. We'll restate them.
- `fp.c4.close.02` **bolt:** It's over, Vantage.
- `fp.c4.close.03` **sable:** Nothing is over, Bolt. Things are only ever deferred.
- `fp.c4.close.04` **sprocket:** Then defer yourself off our pad.
- `fp.c4.close.05` **sable:** Keep it. We'll go to Basel. We were always going to. It's in the file.
- `fp.c4.close.06` **sable:** But we should know: the Underwriter was dispatched before we arrived. It's very punctual.
- `fp.c4.close.07` **sprocket:** *[quietly]* The Underwriter. The routing slip on his transmission. "Recall action. Clause zero."
- `fp.c4.close.08` **sable:** Field units are inventory. Our little salesman has been in the field far too long. He'll be collected, gently. We're always gentle with inventory.
- `fp.c4.close.09` **bolt:** He's not inventory. He's somebody who asked for help.
- `fp.c4.close.10` **sable:** So was every one of our customers, Bolt. Thank you for your continued engagement.

*She steps backward into a fold. It closes from its edges inward, like an envelope being sealed.*

- `fp.c4.close.11` **blartz:** She didn't even break a sweat. Does she HAVE sweat? I'd like to patent whatever she doesn't have.

---

## S8 · Scene `pad`: "Purchase Order"

*The delivery pad's crystal ring hums on the dais. Blartz pulls a fold-out keyboard from his coat, along with a pad of purchase-order forms and a pen.*

- `fp.c4.pad.01` **blartz:** A Next-Era Delivery pad. I've never touched one. Have I WANTED to? Every single day of my professional life. Sprocket, coordinates.
- `fp.c4.pad.02` **sprocket:** Helvetia Works, Kleinhüningen, Basel, Sol-3. Eighteenth of March, nineteen forty-five. Oh-three-twelve.
- `fp.c4.pad.03` **blartz:** It won't ship without an order, so I'm writing one. "Deliver: one, mechanic. One, robot." Signed... *[scribbling]* "S. Vantage." Look at that signature. Better than hers. More confident.
- `fp.c4.pad.04` **nextera:** Order received. Warning: the delivery address is in the past.
- `fp.c4.pad.05` **blartz:** So's my patent, and you're using THAT.
- `fp.c4.pad.06` **nextera:** Objection accepted. Please stand on the pad. Please do not resist packaging.
- `fp.c4.pad.07` **bolt:** Blartz. You're not coming?
- `fp.c4.pad.08` **blartz:** Somebody has to stay and stop this thing from un-shipping you. Also, I'm going to rob every drawer in this vault and mail each patent back to whoever invented it. Alphabetically. With a note.
- `fp.c4.pad.09` **blartz:** Find my forge. Find your robot. And Bolt, if you see that violet Crucible down there, tell it its father is VERY disappointed in its paint job.
- `fp.c4.pad.10` **sprocket:** Blartz... thank you.
- `fp.c4.pad.11` **blartz:** Don't. It's bad for the brand. *[beat]* ...Fine. You're my favorite customers. Legally binding.
- `fp.c4.pad.12` **glambot:** Darlings, I'll be in your ear the whole way, I promise. Premium uplink, the works. Nothing can possibly—

---

## S8 · Scene `misfire`: "Standard Localization"

*The ring flares. Bolt and Sprocket are lifted an inch off the pad, and shipping labels print themselves out of the air and stick to them: FRAGILE · THIS WAY UP · SOL-3.*

- `fp.c4.misfire.01` **nextera:** Destination market: developing. Applying standard localization.
- `fp.c4.misfire.02` **blartz:** Localization? What's localization? I didn't tick localization!
- `fp.c4.misfire.03` **nextera:** Localization is automatic. Please enjoy your era.

*The color drains out of the world from the edges in. Bolt's orange goes to tobacco brown, Sprocket's cyan to tarnished pewter, the violet of the fold to the only saturated thing left. The B&S HUD (bolt counter, combo meter, bright weapon wheel) peels away piece by piece like stickers. The camera pushes forward through the back of Bolt's head until we are looking out of his eyes: his own hands, the mallet in his grip, close and heavy.*

- `fp.c4.misfire.04` **bolt:** Sprocket? Why is everything... closer?
- `fp.c4.misfire.05` **sprocket:** Bolt, you're IN your own head! And I'm... I'm GREY. I'm sepia-adjacent. Where did my blue GO? I worked hard on that blue!
- `fp.c4.misfire.06` **nextera:** Notice: coverage ending. Region: nineteen forty-five.
- `fp.c4.misfire.07` **nextera:** Recategorizing shipment. Status: returned inventory.
- `fp.c4.misfire.08` **sprocket:** RETURNED? We're not returned, we're DELIVERED! Bolt, they've put us in the returns stream!

*The pad drops them, and they fall. A tunnel of violet dark, and things tumble past in it, things that were lost: a Soviet machine pistol turning end over end, an American flamethrower trailing its hose, a crate of field rations, a lawn dart with a gift tag still on it. Then, under the roar, very faint, for two seconds and no longer: a tin drum. Tam-tam, ta-ta-tam. Nobody mentions it.*

- `fp.c4.misfire.09` **bolt:** Was that a LAWN DART?
- `fp.c4.misfire.10` **sprocket:** Returned UNOPENED! Somebody returned a lawn dart to a WAR!
- `fp.c4.misfire.11` **sprocket:** Bolt, I'm reading our label. It says "Fragile." It says "Returned." And underneath, very small: "Contents may have shifted in time."
- `fp.c4.misfire.12` **bolt:** Hang on, buddy. Hang on, Vendelin. We're coming.
- `fp.c4.misfire.13` **sprocket:** *[to no one, softly]* Somebody read your letter, V.

*White-violet flash. Cut to black.*

**CHAPTER 4 COMPLETE · Continued in Chapter 5: RETURN POLICY** (`script_ch5.md` §1.1 `arrive_bs` picks up mid-shipment, with Blartz on the radio).

---

## Escrow PA `pa` (ambient, triggered by section)
- `fp.c4.pa.01` **dm_pa:** Escrow thanks you for your patience. Your patience has been recorded.
- `fp.c4.pa.02` **dm_pa:** *[beam touched]* A visitor has agreed to something. Thank you for agreeing.
- `fp.c4.pa.03` **dm_pa:** Associates to Receiving. A return is behaving unreturnably.
- `fp.c4.pa.04` **dm_pa:** A reminder that all ideas conceived inside the Vault are the property of Darkmatter Legal. That one included.
- `fp.c4.pa.05` **dm_pa:** The Filing Vault will re-sort in ten seconds. Please be filed.
- `fp.c4.pa.06` **dm_pa:** Quarter close approaching. Please finalize your feelings.
- `fp.c4.pa.07` **dm_pa:** *[player re-shelved by a sorting arm]* You have been put back. Thank you for staying.

## Blartz heist idles `blartz` (S2–S6, on a 50–70 s idle timer)
- `fp.c4.blartz.01` **blartz:** In my professional opinion as a criminal, which I am today, briefly, this vault has TERRIBLE sight lines.
- `fp.c4.blartz.02` **blartz:** I've counted eleven of my competitors' patents in here. I'm going to steal them back and then refuse to give them back. Out of principle.
- `fp.c4.blartz.03` **blartz:** If anyone asks, I'm a toaster salesman. Remember that. Toaster. Salesman.
- `fp.c4.blartz.04` **blartz:** Heists are just shopping with fewer receipts.
- `fp.c4.blartz.05` **blartz:** Every time somebody says "patent pending," a small part of my soul files for bankruptcy.
- `fp.c4.blartz.06` **blartz:** Darkmatter's security is all paperwork. Paperwork is my natural enemy. I've beaten it with a hammer twice.
- `fp.c4.blartz.07` **blartz:** Sprocket's humming that vending-machine jingle again. It's in his head. It's in MY head now. Who WRITES these things?
- `fp.c4.blartz.08` **blartz:** This floor is fake marble. Fake marble is just honest plastic with a lying problem.
- `fp.c4.blartz.09` **blartz:** When this is over, the Vault goes in my catalog. "Escrow: a tasteful little hole in the law."
- `fp.c4.blartz.10` **blartz:** Bolt, stop admiring the drawers. They know they're big. They're showing off.

---

## Line counts

| Scene key | Lines | Notes |
|---|---|---|
| `served` | 30 | Cold open, Blartz's shop |
| `loophole` | 20 | 12 scene + 8 gadget barks |
| `crate` | 9 | |
| `receiving` | 5 | |
| `grids` | 8 | |
| `grid` | 16 | On-screen clause text (`text`, unvoiced) |
| `associates` | 9 | Enemy intro scene |
| `associate` | 12 | Unison bark pool |
| `filing` | 5 | |
| `sort` | 8 | Sort callouts |
| `drawer` | 20 | 5 of them on-screen transfer slips (`text`) |
| `plinth` | 10 | |
| `sable` | 15 | Sable arrives; THE QUARTERLY intro |
| `board` | 6 | Quarter calls |
| `q1` | 7 | |
| `q2` | 7 | |
| `q3` | 7 | |
| `q4` | 8 | |
| `callout` | 16 | Sprocket / Blartz / GLAMBOT boss callouts |
| `retry` | 3 | |
| `close` | 11 | |
| `pad` | 12 | |
| `misfire` | 13 | |
| `pa` | 7 | |
| `blartz` | 10 | Heist idles |
| **Total** | **274** | 253 voiced, 21 on-screen text |

## Notes for implementers
- **New speaker id `nextera`** (NEXT-ERA DELIVERY™ TERMINAL) is needed in `speakers.json`. `text` lines are subtitle/UI-only and must never be sent to TTS.
- **All tuning** cited in the boss and gadget sections belongs in `data/fineprint/ch4_tuning.json`, not in logic.
- **Q3 "most used weapon"** is measured as damage dealt by weapon since the fight began (not shots fired). PATENT PENDING is always exempt from acquisition. If the most-used weapon *is* PATENT PENDING, acquire the second-most-used.
- **Q4 renewal** must never soft-lock: each renewal shortens the bands, and after two renewals the clock extends to 120 s.
- **Final hit is mallet-only.** Any other damage source clamps the ticker at DMS 0.01 and shows the mallet prompt.
- **The misfire's first-person push** is the in-fiction reason Bolt is first-person in Helvetia Works. The transition is a camera move inside the cutscene; Ch. 4 never hands control to the first-person controller. Ch. 5 owns the controller swap.
- **GLAMBOT's signal** is not cut off in Ch. 4. The pad warns "coverage ending," and his actual dropout happens on arrival in `fp.c5.arrive_bs.08–09`.
- **The tin drum** in the misfire is sound only: no subtitle, no caption beyond `[faint drumming]` when captions are set to "full," and no line id. It must never be explained.
- **The sealed Incident Report** is an interactable that cannot be opened until Ch. 5 is complete.
- **Never use the word "subscription"** in any Earth-side text. This chapter never reaches Earth on screen; the word appears only in the company name "Darkmatter Subscriptions LLC" (`served.14`, `drawer.05`), both off-Earth.
