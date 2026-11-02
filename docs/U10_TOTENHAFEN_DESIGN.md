# Totenhafen (map02), UPDATE 10 §2: the design (the lead's calls; DECISIONS T-152)

Everything here is binding for the two Totenhafen workers (systems; living world), the bots worker and the Haiku asset
worker. Ids and schemas are in `docs/U10_CONTRACTS.md` C2–C5. Canon: `docs/CANON.md` (the Marke §2.2, the Return Trip
§9), `docs/gravelight/LORE.md` §13 (Totenhafen), `docs/gravelight/MAPS.md` "MAP 2". The story question Totenhafen answers
is *where is the Nachtglas going*; the egg's answer is *we take the boat ourselves and sink the cargo*.

## 1. The story spine: Deacon's wish
Deacon has wanted to hear U-1047's diesels since the squad walked into the pen hall ("Somebody built that to be quiet.
I'd like to hear it loud, once."). The boat's log (four pages, hidden in the boat and the crane office) tells the rest:
her captain, **Kapitänleutnant Arvid Lenz**, refused to sail with fourteen lead coffins as ballast after his chief
engineer, **Obermaschinist Rolf Brecht**, opened one. Lenz locked the coffins in the warhead cage and wired Basel for
orders; Basel ("Hale, L., per Helvetia Automaten AG") wired back *sail on the next tide or the detachment is retained*.
The detachment was marked that week (CANON §2.2: U-1047's ratings took the Marke). Lenz scuttled the diesels' injectors
and threw the battery cells into the lower pens so nobody could take her out; the Erwachen reached the harbour on the
night of the 20th; Lenz went down to the pump deck with a lamp and did not come up (he is DER KIELHOLER). Brecht's hand
wrote the start sequence on the last page of the log "for whoever is not them". The egg is Brecht's instruction
followed to the letter: find the injector, raise a battery, run the sequence, flood the dock, open the curtain, take her
out, and sink her with the cargo where the chart says it is deepest. The Operator wants the cargo delivered; the squad
wants it gone. Peg's orders said "retrieve the tokens": she chooses the sea. That is the moment the campaign's Basel
thread turns (the Hale telegram is the proof Peg carries to the Return Trip).

## 2. "LETZTE FAHRT" (The Last Voyage): the step graph (EASTER_EGGS.md §10; quest `map02_letzte_fahrt`)
```
s0_power (Pumpenschalter; needs ballast_loaded ≥ 1)
 ├─ s1_ballast   dump 3 coffins at the sea stairs (the squad argues; the Operator sulks: +1 Glasshide next round each)
 ├─ s2_cipher    three radios (cannery office, workshop bench, U-1047 radio room) each give a 4-letter code group over
 │               U-boat traffic; the ENIGMA-LIKE but fictional "SCHLÜSSELGERÄT HAFEN" in the signal tower has three
 │               rotor wheels (A–Z): set them to the groups' first letters in the order the radios are keyed per match
 │               (seeded), press the lever: the teletype prints the chart's depth mark and the curtain code
 ├─ s3_log       four log pages (two seeded spots each: the captain's cabin, the radio room, the crane office desk,
 │               the pump deck locker); reading all four unlocks Deacon's line and the start sequence (s5c)
 └─ s4_parts     the Undertow (optional for the squad, required for the boss: the pump, the head, the shard)
s5_diesels  three holdouts, any order after s1–s3:
   s5a_injector  the workshop lathe: a 30 s machining hold DURING A FLOOD (the lathe runs only when the pump room is
                 wet, "the belt slips dry"), ×2 spawns, Kielholer at the dock door
   s5b_battery   the lower pens: a 30 s hold IN THE DARK (the lights die when the cell is lifted; the searchlight from
                 the tower or the squad's flashlights are the only light; the pump deck floods to the knees)
   s5c_sequence  the engine room: a 45 s hold at the start panel while KIELHOLER PULL AT THE HULL (the hull shakes,
                 boarders come up the gangway; Brecht's sequence read aloud by whoever holds the panel)
s6_boss     DER KIELHOLER rises from dock 2 (the drowned captain; §4). He drops THE IGNITION KEY.
s7_key      turn the key in the signal tower's chart room: the cliff church's bell tolls once (the §2.2 beat), the
            curtain code is live
s8_curtain  the pen curtain opens (the storm comes in; the dock floods to spring height); the boat is ready
s9_sail     THE LAST VOYAGE: the moving holdout (C2 "the boat"): the deck and the tower for 150 s as she noses out;
            boarders from the water and the pen walls, the Kielholer drag at the hull, the searchlight tracks you, the
            scenery scrolls (the pen mouth, the breakwater, the burning town on the cliff); Hinnerk steers
s10_ending  she dives at the depth mark: the cutscene (§6); rewards
```
Randomised per match: which radio is keyed first (the rotor order), the log pages' spots, the parts' spots, the dock
the boss surfaces at first. Fail-safes: if the boss is not dead after 420 s he dives and the key floats up at the dock
edge; if the sail holdout wipes, the match ends as a wipe (it is the finale); every holdout can be retried next round.
Bots: every step has a `bot_task` (the cipher gets a solver with a 20–40 s think delay; the carry task for the
coffins; the holds are `hold_position` tasks with the step's twist as a modifier; the sail is a `stay_on_platform`
task).

## 3. The Ballast choice (the squad comments)
- Load (crane): the Operator is pleased ("Ballast received. The schedule thanks you.") and pays 500 Scrip; Dutch: "That's
  a man in there. Was." Wren says nothing and looks at the pallet.
- Dump (sea stairs): the Operator is snippy ("That was inventory.") and the next round brings one more Glasshide; Deacon:
  "Lord, forgive me, that's the only burial they get." Peg, on the third: "That's three. That's enough to make it a
  choice."
- The egg needs three dumped; the power needs one loaded; the coffins respawn on their pallets so both are always
  possible. Bots prefer the egg's choice once the egg is started, the power's before.

## 4. DER KIELHOLER (the drowned captain, `bosses/map02.json`, on HomageBoss)
- **Who:** Kptlt. Arvid Lenz in a diving dress with a brass helmet (the harbour's salvage suit: he went down to the pump
  deck in it to wreck the cells), the Marke under the helmet glass glowing violet, an anchor chain over one shoulder.
  He is not a joke and not a monster for its own sake: his last impulse is *keep her in the pen*.
- **Arena:** the whole pen hall. He surfaces at a dock (dock 2 first), walks the piers and the aprons, submerges when
  hurt 25% and resurfaces at another dock after 6–10 s (a ripple telegraph). At high tide and spring tide he is ×1.3
  faster and surfaces closer.
- **Attacks:** the anchor-chain sweep (a 1.2 s telegraph: he swings the chain overhead; a 9 m line that pulls hit
  players 4 m toward him and knocks them down), a helmet-first charge along a pier (telegraphed by the helmet lamp
  turning to the target), a grab at the dock edge (the Kielholer pull, stronger).
- **Weak points:** the helmet glass (`helmet_glass` ×1.0 until it breaks after 15% of max HP, then the glow ×2.0 and he
  roars), the Marke glint inside (×1.5 as every zombie), the back of the suit where the chain rubs (×1.3).
- **Health** by player count per HOMAGE_BOSSES §3.1, `bots_alone` scaling, failsafe 420 s (he dives; the key floats
  up). **Drop:** the ignition key (a pickup with a tag "U-1047 · Brecht").
- **Rounds:** the egg's s6, or round 20 standalone (40 in the campaign) without the egg (then he drops the key but s7
  needs the cipher too).
- **VO:** `OPR_BOSS_KIELHOLER_*` (spawn, death), `KLH_*` (he has four lines, German, subtitled, under the water's
  distortion: "Sie bleibt hier." ("She stays here."), "Die Fracht bleibt hier.", "Brecht… du hast es aufgeschrieben."
  ("Brecht… you wrote it down."), and on death: "Dann fahrt. Fahrt sie raus." ("Then sail. Take her out.")), the squad's
  reactions `DUT/PEG/DEA/WRN_BOSS_KIELHOLER_01/02`.

## 5. THE UNDERTOW (WEAPONS.md §11; C4)
- **Look:** a brass-and-rubber pressure cylinder on a shoulder stock, a Nachtglas-tipped harpoon on a violet-black
  chain, a pump handle under the barrel (the diver's pump), a pressure gauge whose needle shivers with the hum.
- **Fire:** the harpoon flies 25 m, skewers up to 5 zombies in a line, and the chain reels them in over 1.2 s; they
  arrive stunned in a heap at 2 m (melee them, or fire the next harpoon into the heap). Reload: pump three strokes
  (2.1 s). Magazine 1, reserve 12.
- **In water (a flooded box):** the harpoon opens a whirlpool, 4 m, 6 s: non-boss zombies in it are dragged under
  (a kill with the drowned's scream), bosses take 40/s.
- **MAELSTROM (Crucible):** the whirlpool opens on land too (a violet vortex in the concrete, 3 m, 5 s), harpoons chain
  to the next target within 6 m (up to 3 chains), reserve 18.
- **Parts:** `undertow_pump` (the diver's pump, lower pens, 2 spots), `undertow_head` (a harpoon head, the workshop's
  tool wall or the warhead cage, 2 spots), `undertow_shard` (a shard of a dumped coffin: after the third dump the
  shard lies on the sea stairs). Bench: the crane office. First pickup VO per character (`*_WONDER_UNDERTOW_01`):
  Dutch "A fishing pole. For what's down there." Peg "Pressure's good. Don't point the sharp end at me." Deacon "Lord,
  it's humming. They all hum." Wren "Line and hook. I was taught the same with a rifle."

## 6. The sailing finale and the cutscene (s9/s10)
The deck holdout: the players hold the deck and the tower; Hinnerk Petersen steers from the bridge (his scene: he was
trapped in the flooding tower stairwell since the Erwachen; hand him a gun on the tower stair and he fights from the
signal room like Selwyn; in the finale he takes the wheel: "I said I'd never take a boat out of here at night. I lied
to the wrong people."). The searchlight tracks the boat; the Kielholer (plural, the drowned) drag at the hull;
boarders come over the saddle tanks. The scenery scrolls: the pen mouth's curtain, the breakwater light (dark since
round 10, now lit by the storm's lightning), the burning town on the cliff. At 150 s the chart's depth mark: the
cutscene: Deacon cuts the diesels ("That's enough. I heard it."), the crew goes below, the hatches close, the Operator's
only line is "Cargo… lost." as the boat dives with the coffins, and on the surface the cutter's lamp. Card: the Hale
telegram in Peg's hand, "BASEL · HALE · ON THE NEXT TIDE". Rewards: 2500 Scrip each, a tier gift (one held tonic +1
tier), the calling card `CARD_LETZTE_FAHRT` ("THE LAST VOYAGE"), the Archive entries. Then the normal exfil to the
next map (the campaign continues at round 31 as before; the boat's absence from the pen is remembered in the profile for
flavour only).

## 7. Timed beats and the living world (the living-world worker; C1)
- Round 6: RAF Mosquitoes low over the harbour, flak from the cliff. Round 10: the lighthouse goes dark. Round 12: the
  bombing raid on the pens (dust, icicles, lamps swinging, the hall shakes; the Operator complains about the schedule).
  Round 15: the cutter slips into the sea (a new sea-stair spawn and a hidden item: a sailor's letter). The cliff bell
  tolls once at `egg_lf_started`.
- The sea: chop and swell beyond the breakwater, a burning freighter card, a destroyer's searchlight sweeping the bay,
  star shells; the dead U-boat half-sunk at the breakwater; the lighthouse beam every 9 s until round 10.
- Reactive: chains and blocks swing; gulls scatter at the first shot; frozen spray on the parapet; wet footprints;
  fish crates spill when zombies run through; the conveyor jolts at power-on; radios crackle U-boat traffic in German,
  subtitled (six lines, `RADIO_UBOAT_01..06`).
- Power-on spectacle: the pumps thunder, the docks drain 0.4 m, the lamps sweep dock by dock from the pump room to the
  quay, the perks wake with stings, the tower lamp turns, U-1047's interior goes red to white, a burst, the Operator.

## 8. Story props (6, `story_props.json` map "2", Archive)
`INT_M2_LOG_1` (the captain's cabin: Lenz's first entry on the coffins), `INT_M2_LOG_2` (the radio room: Basel's
reply), `INT_M2_LOG_3` (the crane office: the marked detachment), `INT_M2_LOG_4` (the pump deck locker: Brecht's start
sequence "for whoever is not them"), `INT_M2_SAILOR_LETTER` (under the cutter after round 15: a rating's letter home,
never sent), `INT_M2_HALE_TELEGRAM` (the signal tower's teletype tray: BASEL · HALE · ON THE NEXT TIDE), plus
`INT_M2_PAYSLIP` (the cannery office: a pay slip in Scrip), `INT_M2_DRAWING` (the cliff town's shelter: a child's
drawing of the boat with a smiling sun; shown with care), `INT_M2_RATION_BOOK` (Hinnerk's, in the signal room). The
six the work order asks for are LOG (as a set), the letter, the telegram, the pay slip, the drawing, the ration book.

## 9. THE SLENDER at Totenhafen (the canon call, T-160)
HOMAGE_BOSSES §6 places THE SLENDER at Morgenrot, round 20. Morgenrot is not built; his design (a very tall night
watchman with a lantern and a ring of keys, who works the night shift) fits the harbour's night watch exactly. Canon:
he is **the Hafenwächter**, the pens' night watchman, who walked the catwalks with a lantern and a ring of keys and
locked every door behind him on the night of the Erwachen so the dead would stay in the pens; the Marke kept him
walking. He appears at Totenhafen round 25 standalone (45 campaign), walks the catwalks, locks the Pen Hall doors and
the pump stair as he passes (free to reopen when he leaves the zone or dies), and his lantern beam is the danger per
§6.3's Watch system. The Morgenrot hook stays in `bosses/map03.json` as a placeholder entry so he can return there.
Likeness fields stay default; the code never prints a placeholder token.
