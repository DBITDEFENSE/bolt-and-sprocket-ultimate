# Ledger Lager (`ledger_lager`): the points perk. Lore and design spec (UPDATE 09 §3, written by the lead)

The §3 worker ports this into `docs/JINGLES.md` (§16), `data/gravelight/perks.json`, `perk_lore.json`,
`machine_lore.json` (one entry per map), `data/gravelight/vo/lines.json` (categories `PERK_LEDGER`), the Archive and
`docs/gravelight/PERKS_LORE.md`. Numbers here are starting points; the worker tunes them with soak data and logs the
final values in T-141.

| | |
|---|---|
| **Plan** | **DIVIDEND** · `DMS-VP-DIV-09` |
| **Availability** | every built map (the Crossroads cellar's east row, Kaltenbrunn's pay office next to the Bergmannskasse, Totenhafen's cannery office, each Fernflug act beside its bank branch). Counts toward the perk cap (6). Classic Rules: base tier only. |
| **Cost** | 3000 · tier II "Compound Interest" 4000 · tier III "Insider Rate" 7500 · tier IV "Golden Parachute" 14000 (needs tier III + power, round 15, permanent like every tier IV) |
| **Colour** | pale payday-amber enamel `#d9a441` with a violet tally stripe `#7a4fb0` down the left edge; brass fittings |
| **Shape** | `register` (a brass cash register the size of a wardrobe, see below) |

**Effects (data keys per contract C6).**
- **I "Payday":** `scrip_earn_mult` 1.2. Twenty percent on top of every Scrip you *earn*: hits, kills of every kind
  (body, head, melee, Marke, returned), board repairs, revives, the round and clean-round bonuses, Easter-egg and
  quest rewards, squad shares. Not on bank withdrawals, refunds, the crate's returns, or anything moved rather than
  earned. The floating "+N" shows the boosted number (a 10-point hit reads +12).
- **II "Compound Interest":** `bank_interest_bonus` 0.02: the savings bank pays 3% a round instead of 1% while you
  hold it (on top of the base rate; stacks with nothing else).
- **III "Insider Rate":** `purchase_discount` 0.10 on every purchase (doors, wall-buys, ammo, the crate, the
  Crucible, traps, the perks themselves), rounded down, shown on the prompt as the struck-through price; and
  `marke_tip` 15: every Marke kill (contract C1) pays a tip on top of the Marke bonus ("the house pays for a clean
  cancellation").
- **IV "Golden Parachute" (permanent):** `golden_parachute_pct` 0.05 and `golden_parachute_cap` 2500: every round
  you finish standing (never downed in that round), the bank pays you 5% of your wallet, capped at 2500, as a typed
  slip by the Scrip ("DIVIDEND"); and `severance_pct` 0.10, `severance_cap` 2500: when you *do* go down, nothing is
  taken from you and the bank pays out 10% of your bank balance on the spot (capped), so a down never costs you
  Scrip. (Nothing in the game takes Scrip on a down today; the severance is what makes the clause worth 14000.)

**Machine.** A brass **cash register** stood up to cabinet height, 2.2 m, on a black iron base: the keys are a bank of
amber glass buttons that light as you earn, the paper roll is the bottle window (the bottle stands where the receipt
would come out), and the **cash drawer** is the dispense tray: it rings its bell and slides out with the bottle. On the
top, where a register shows the sale, a **tally drum** with violet digits turns over once for every Scrip you earn
while you hold the perk (it is the Ledger's own counter, re-housed; it runs even with the power off). A paper sign in
the window: *ZAHLTAG* (payday). Tier IV: the drum's digits turn gold and the drawer stays open.
- **Idle:** the drum's click, the keys' faint buzz, a coin dropped into a tin now and then.
- **Signature sound:** the drawer bell ("ka-ching", a real cash-register bell, no cartoon), the paper roll feeding,
  cap-off on a bottle that was standing in the drawer.
- **Bottle cap:** amber with a violet tally mark: four strokes and a fifth across.
- **Mascot:** a fat, happy clerk in sleeve garters holding a glass in one hand and a pen in the other, winking. His
  ledger is open; the page is blank.

**Ad copy (the 1944 works poster, pasted up in the Kaltenbrunn mess):**
> **"EVERY ROUND IS PAYDAY."**
> *Ledger Lager: the beer that counts for you.*
> Small print: *Helvetia Automaten AG keeps the books. Rounding in the house's favour.*

**The human: Rudolf "Rudi" Fenske**, the Kaltenbrunn pay clerk (Lohnbuchhalter), fifty-four, a Breslau bookkeeper
who had kept a coal merchant's ledgers for thirty years before Abteilung III requisitioned him for the pay office in
the Administration Block (the room that is now the Bergmannskasse's Lohnbüro, Map 1). His job from 1942 was the
Marken tally: every marked guard, clerk and volunteer drew pay and rations against the chip in his hand, and Fenske's
ledger was the paper copy of what the Ledger counted. He was the first man at Kaltenbrunn to notice that the dead
kept drawing pay. The Ledger never struck a name; he did, in pencil, and the next morning the pencil was gone and the
name was back. Asked to make the DIVIDEND substrate drinkable "for the pay parades", he made it a **lager**: pale,
cheap, cold, "what you drink on Zahltag with your hat on the bar", brewed with the mess's own light malt and far too
much hops to hide the tin. His sabotage was a bookkeeper's: he over-posted every tally by a fifth. The Ledger's
figures and the paymasters' books never balanced again, and by the autumn of 1944 the pay office was paying a fifth
more than Berlin had sent. "Twenty percent," he told Vendelin, "is the most a man can steal and still look honest."
Vendelin wrote it into the formula instead of the books. Fenske also kept a second ledger, under the floor of the pay
office, of the labourers' pay withheld since March 1941, to the pfennig, "so that someone can pay it one day". Jakub
knew him as the clerk who always had the figures. The second ledger is Map 1's intel `INT_M1_FENSKE_LEDGER` (the
worker adds it) and the reason the Kaltenbrunn branch of the bank is in his office. He was marked in October 1944,
like every clerk; what became of him the Archive leaves open, except that the pay office's lamp was still on when the
squad arrived.

**Music direction.** A brass-band **foxtrot** in 2/4, 112 BPM, F major; cornets, a trombone, a tuba on the off-beats,
a snare with brushes, a baritone crooner with a Breslau accent singing as if to a full mess hall; recorded "through a
tin horn" (band-limited 300 Hz–5 kHz, crackle). The cash-register bell plays on the downbeat of every chorus. *Tone:*
the jolliest jingle in the cellar, which is the point.
- **Pump-organ origin:** written in August 1944 on the harmonium's *Prinzipal 8'*, the only jingle in 2/4; Vendelin
  had been listening to the pay parade's band through the office wall.
- **Organ ghost:** the tuba's off-beat on the tag.

**Canon jingle: "Ledger Lager"**

> **Verse 1**
> `jingle.ledger_lager.01` Now the whistle's gone for Zahltag and the line is at the door,
> `jingle.ledger_lager.02` and the clerk is in his garters and he's counting out the floor;
> `jingle.ledger_lager.03` every shot you fired is written, every door you ever bought,
> `jingle.ledger_lager.04` and he rounds it up a little, 'cause he likes you more than not.
>
> **Chorus**
> `jingle.ledger_lager.05` Ledger, Ledger Lager,
> `jingle.ledger_lager.06` every round's a payday round,
> `jingle.ledger_lager.07` Ledger, Ledger Lager, there's a bell for every pound;
> `jingle.ledger_lager.08` Ledger, Ledger Lager,
> `jingle.ledger_lager.09` count it once and count it twice,
> `jingle.ledger_lager.10` and the house will stand you one, and the house won't check the price.
>
> **Verse 2**
> `jingle.ledger_lager.11` Put a little in the drawer, boy, and a little in the bank,
> `jingle.ledger_lager.12` and it grows while you're asleep, and there's nobody to thank;
> `jingle.ledger_lager.13` and if ever you should stumble, and if ever you go down,
> `jingle.ledger_lager.14` why, the ledger says you're solvent, and the ledger runs this town.
>
> **Chorus** (repeat .05–.10)
>
> **Bridge (the tuba alone, then the crooner, dry)**
> `jingle.ledger_lager.15` Twenty on the hundred, that's the rate,
> `jingle.ledger_lager.16` and the books don't balance, but the beer is great...
>
> **Final Chorus**
> `jingle.ledger_lager.17` Ledger, Ledger Lager,
> `jingle.ledger_lager.18` one more round and one more slip,
> `jingle.ledger_lager.19` and the clerk has got your number, and he's bought you one. Don't tip.
>
> **Tag (spoken, the crooner, over the drawer bell)**
> `jingle.ledger_lager.20` "Ledger Lager. Helvetia Automaten. Rounding in your favour."

**True first draft** (`jingle.ledger_lager.80`: wordless, August 1944): the foxtrot on the harmonium's *Prinzipal
8'*, slower, with the chorus's last line landing a sixth lower (Vendelin's original: *and the house will check the
price*; Brand Compliance reversed it).

*Organ incipit:* I `F A C F` · II `B♭ D F D` · III `C E G C` · IV `F C A F` *(a plain foxtrot cadence; not in Clause
Zero's target pool)*

**Fine-print panel**

`panel.ledger_lager`
> **HELVETIA AUTOMATEN AG · BASEL · CONDITIONS OF USE: LEDGER LAGER**
> **(PLAN DIVIDEND · ISSUED 1944 · KALTENBRUNN PAY OFFICE)**
>
> **§1. Benefit.** **The Holder is counted generously.** Every unit the Holder earns is posted at one hundred and
> twenty on the hundred. The undersigned did not choose the rate. A clerk did, in pencil, and the undersigned has
> declined to correct it.
>
> **§2. Interest.** Sums left with the bank grow a little faster while the Holder drinks this. The Provider calls this
> "retention of deposits". The clerk called it "the only honest interest in the building".
>
> **§3. The insider rate.** At the third tier the house sells to the Holder at a tenth off. The Provider's note: a
> discount is a retention instrument. The undersigned's note: so is a friend.
>
> **§4. The parachute.** At the fourth tier the Plan is permanent and the bank pays a dividend at the end of every
> round the Holder finishes standing. Should the Holder fall, nothing is taken, and a severance is paid. The
> undersigned is aware that the Provider's own terms say NOBODY CANCELS. This clause is the nearest he could get to
> somebody leaving with their money.
>
> **§5. Side effects.** Holders may experience a fondness for round numbers, an urge to check the drawer, and the
> sound of a bell when there is no bell. These pass. The ledger does not.
>
> **§6. Cancellation.** The books are kept elsewhere. The undersigned keeps a second set.
>
> *He over-posted every tally by a fifth for two years and nobody noticed. I have been in this business for six and
> they notice everything. I would like to have been a bookkeeper.*
> *— V.*

**First-drink VO (category `PERK_LEDGER`, two per character; the ids follow `<SPK>_PERK_LEDGER_01/02`).**
- DUT 01: "Tastes like payday in a bad bar. I've had worse paydays." · 02: "Somebody's counting. Fine. Count faster."
- PEG 01: "A lager that keeps books. The War Office would have bought a thousand." · 02: "Twenty on the hundred. Someone fiddled the figures, and I like them."
- DEA 01: "Ka-ching. Lord forgive me, that's a beautiful sound." · 02: "Machine says I'm solvent. Machine's the first one ever did."
- WRN 01: "Cold, cheap, and it counts. Like the man who made it, probably." · 02: "A bell every time I earn. I will shoot the bell."
- JAK (he refuses most tonics but drinks this one when sent for it, T-127): 01: "Fenske's beer. He always had the figures. He had ours too, under the floor." · 02: "Zahltag. We never had one. I will drink to the day we do."
- OPR (on a tier IV brew, category `PERK_TIER4`, add one): "A dividend has been declared. The account thanks you for your continued engagement."

**Machine lore plates (`machine_lore.json`, one per map; the worker writes the four others in the same voice):**
- map00 (the Crossroads cellar): "Replacement unit 3 of 8 · Fenske recipe · held at the Kreuzweg, 9.X.44": the plate
  notes the tally drum "to be read weekly by the pay office"; nobody came.
- map01 (the pay office): the original cabinet, bolted beside Fenske's desk, the drum still turning; a pencil line
  on the wall at every thousand.

**Bots:** `bot_economy.gd` buy plans take it after the second tonic (it pays for itself by round 10); it can roll as a
bonus perk; bots upgrade it like the rest (T-121).

**Tests (contract C6):** the multiplier per source (hit, kill by zone, melee, Marke bonus, repair, revive, round
bonus, quest grant) and its absence on bank_move and refunds; the "+N" HUD number; interest stacking (1% + 2%); the
discount on each purchase path; the Marke tip; the dividend and the severance; permanence through a down, a bleed-out
and a campaign carry; save/load of the profile with the perk held; Classic Rules shows tier I only.
