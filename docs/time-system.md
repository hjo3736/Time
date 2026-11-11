# Time System

The single mechanic everything else hangs off. Time is simultaneously the
per-turn resource (energy analog), the run-length resource, and the difficulty
dial.

## The unit

Everything is denominated in minutes and displayed as a calendar clock
(`Day 3 — 14:30`). The deadline is not a separate timer: it is the Warden's
remaining time, which is the same number the player spends on cards. See
[setting.md](setting.md).

## Two clocks

There are two distinct layers. Conflating them is the main design trap.

| | Turn budget | World clock |
|---|---|---|
| Scope | Resets every battle turn | Persists for the whole run |
| Spent by | Playing cards | Taking turns, traveling, resting |
| Analog | Energy in Slay the Spire | Run progress + difficulty |

**Base turn budget: 3 hours.** Card costs: `0 / 1 / 2 / 3` hours, or variable.

**Every number the player reads is a whole hour.** No 30-minute tier, no halves.
With a 3h budget and 0–3h cards this is exactly Slay the Spire’s energy curve,
which is a proven shape and stays legible during a turn. Storage is in integer
minutes so the calendar clock keeps its resolution and a sub-hour value remains
possible later — but nothing displays a fraction.

### Three tracked quantities

| | **Remaining** | **Elapsed** | **Restored** |
|---|---|---|---|
| Movement | Down on spend; up **only** by conversion at a rest | **Only ever up** | Up on kills, down on spending |
| Meaning | The Warden's life — the deadline | Drives Threat Level | Run goal, shop currency, ending measure |
| Displayed as | The primary HUD number | Threat phase + hours to next step | Secondary counter |

Remaining and Elapsed must be separate because conversion decouples them. Filling
the Warden does not un-warp the world: the leak has been leaking the whole time
either way. **Farming always raises the difficulty**, with no exceptions and no
way to buy the ratchet back — that is the load-bearing rule of the whole economy.
See [setting.md](setting.md) for why it is also true in fiction.

### Remaining is a single budget for the entire run

**It does not reset between acts.** 720h covers all three, start to finish.

The fiction forbids a reset outright — the hourglass is empty, and the god cannot
top the Warden up. But the mechanical reason is the stronger one: a per-act budget
would make each act an independent game, and a choice made in act I would never be
felt in act III. *How much do I farm* only means something if it echoes across the
whole run.

The cost of this is real and named elsewhere in this document: over-farming
becomes a delayed failure. It is mitigated by showing Threat as run progress, and
by act bosses paying out a large chunk of Restored — a big Askew is holding a lot
of leaked time. That gives a run a **pulse** (long drain, boss payout, conversion
at the next fire) without resetting anything or touching the fiction.

### The rule that makes it work

> **Unspent time is lost. The world clock advances by the full turn allotment
> whether you spend it or not.**

Without this rule, the optimal play is to hoard: play as few cards as possible so
the world clock creeps. That is the death of a deck-builder — the core verb
becomes self-punishing and fights turn into stalling contests.

With it:

- Within a turn, spend every minute. No reason not to.
- Across the run, **turn count is what costs you**, not card count.
- The deck-building goal becomes legible: *win in fewer turns*.
- It is thematically exact. The hour passes whether or not you act.

## Restored — the third number

Defeating an Askew fills **Restored**: time pulled back out of the leak, scaled
from the enemy's maximum health. This is the white gauge made mechanical.

**Restored is not a refund.** It never reduces what a fight cost. This
distinction is the whole reason the design works:

- A fight's price stays **predictable and displayable** before you commit to it,
  which is what the perfect-information pillar requires. If defeating enemies
  discounted the fight, the cost of a map node would depend on how well the
  player was about to play, and no honest number could be shown on the map.
- The Warden's own clock keeps running **one way**, which is the entire emotional
  weight of a game about time. A clock with income is a wallet.

An earlier draft had kills refund Remaining directly, on the reasoning that a
purely draining economy offers no relief. That reasoning was wrong — Slay the
Spire is a pure drain (HP only rises at rests) and relief comes from card
rewards, relics, and rest sites, not from the clock.

### Three sinks

Restored is spent three ways, and the tension between them is the run's
strategic spine.

| Sink | Effect | Costs the ending? |
|---|---|---|
| **Deliver** | Left in the pool at the run's end | — it *is* the ending measure |
| **Shops** | Buys cards, removals, relics | **No** |
| **Rest conversion** | Becomes Remaining, at a loss | **Yes** |

**Restored replaces gold entirely.** There is no second currency. One less system
to build, and the theme sharpens: you buy things with hours you were sent to give
back.

### Why shops are free and rests are not

The fiction carries this. Time paid to a merchant **stays in the world below** —
redistributed, not removed. Time converted into the Warden's body leaves the
world permanently. Only the second changes the ledger the ending reads.

The practical reason matters as much as the fictional one. If shopping also cost
the ending, an ending-focused player would buy nothing and shops would be dead
content — the same hoarding failure the unspent-time rule already had to solve one
layer up. Keeping shops neutral leaves exactly **one meaningful transaction**
instead of two mushy ones.

### The conversion, and why it self-balances

Remaining rises by no other means. So conversion is not a temptation the player
can simply resist — it is survival. The question is never *should I*, it is
**how much do I need to finish**. (It is not theft, and the game never frames it
as one — the Warden has no concept that would make it theft. See
[setting.md](setting.md).)

That produces the correlation this game wants for free: a stronger player spends
fewer turns, needs less conversion, and reaches the better ending. The best
outcome is the hardest one, and it is earned by play rather than granted by a
dialogue choice.

First-pass terms: **2 restored → 1 remaining**, capped at 36h of Restored per fire. The loss in
transfer is the point; a clean 1:1 would read as banking rather than taking. A
worsening rate as total conversion climbs is a good later knob — a body running
mostly on recovered material should be harder to sustain — but keep it flat until
the base economy is tuned.

### Design consequences

- Overkill damage must **not** increase Restored, or burst decks break the
  economy. It is a property of the enemy, not of the killing blow.
- Fleeing a fight, if it exists, forfeits Restored — that is its cost.
- Track **delivered** and **converted** separately for the ending. They are the
  two halves of the same pool and the ending needs to read both.
- A card that increases Restored is a top-rarity effect. Treat it like Snecko Eye.

### Optional: Overtime

A later knob, not v1. Allow spending past the turn allotment; the overflow is
billed to the world clock on top of the standard tick. Burn future time for
present power. Only add this once the base economy is tuned — it is a
difficulty-smoothing valve and a good place for a class mechanic.

## HP, and why there are two run-level resources

HP and Remaining are different objects answering different questions: *can I
survive this fight* versus *can I finish this run*. Both persist across the run.
They meet at exactly one place — the fire.

| | HP | Remaining |
|---|---|---|
| Reduced by | Enemy attacks | Turns, travel, rest, shops |
| Restored by | **Resting**, plus 10% of max when an act's boss falls | **Conversion at a fire only** |
| At zero | Lose the current fight | The Warden is gone |
| Lives in | `RunState` | `RunClock` |

### Damage is a tax, not a cause of death

Taking a hit does not kill the player. It makes them need a fire, and resting at
one costs 4 hours.

> damage taken → HP low → need a fire → 4h spent → Remaining drops

**Damage becomes time, one step removed.** This is the load-bearing decision of
the whole resource layer, and the reason is blunt: *whichever resource kills the
player most often is what the game is actually about.* If HP were the usual cause
of death, this would be an ordinary deck-builder with a clock stapled to it, and
every hour of design above this line would collapse into decoration. Routing HP
pressure through the fire guarantees that HP trouble is always **paid for in the
game's own currency**.

It also fits the fiction exactly. The Warden is a body assembled in a hurry, out
of the last time left in a broken hourglass. Damage is that vessel failing, and
resting is time spent holding it together — a thing made of time spending itself
to stay in one piece.

### The fire: each action once, priced by which one

Take any of, each **once** per fire:

| | Costs | Does |
|---|---|---|
| **Rest** | 4h | Heal 30% of max HP |
| **Upgrade** | 2h | Improve one card |
| **Convert** | free | Restored into Remaining at 2:1, capped |

Leaving after taking anything puts the fire out; walking past without taking
anything leaves it lit for later.

**The price is hours, not the other arms.** Every arm is paid for on the clock
(conversion is the exception, and it pays by spending Restored that would
otherwise be returned), so a fire is a place to spend time, and how much to spend
there is the decision.

*(This replaced a one-action rule, Slay the Spire's rest-or-smith. That rule made
the single action the opportunity cost — low HP and short time meant choosing
which way to die, and taking the conversion cost the heal. Changed 2026-11-10;
the reasoning is not written down yet. That squeeze is what was given up, so if
fires turn out too generous, the hours are the first dial and the single choice
the second.)*

### A worked segment

Opening: Remaining 720h · HP 80/80 · Restored 0.

| Step | Remaining | HP | Restored |
|---|---|---|---|
| start | 720h | 80/80 | 0 |
| walk 2h → normal fight, 3 turns (9h), take 12 | 709h | 68/80 | 6h |
| walk 3h → **elite**, 6 turns (18h), take 26 | 688h | 42/80 | 20h |

Decision point at 42/80. A fire sits 3h of corridor away; a shop sits 1h away.

- **Fire:** 3h walk + 4h rest = 7h → Remaining 681h, HP 58/80, and the
  20h of Restored can be converted at the same fire, for nothing in hours.
- **Shop:** 1h walk + 1h inside = 2h → Remaining 686h, and 20h of Restored buys
  cards. HP stays at 42, and the next bad fight ends the run.

Five hours and a card reward against sixteen points of health. The answer differs
every time — it depends on the deck, the Threat step, and what the map shows
ahead. That is the loop.

### Two failure states, deliberately unequal

| | HP → 0 | Remaining → 0 |
|---|---|---|
| Character | Sudden, tactical | Gradual, strategic |
| Cause | Misread this fight | Misallocated the whole run |
| Target frequency | **Rare** | **The usual way to lose** |

**The metric to watch in playtesting: what fraction of losses are HP deaths.** If
it climbs, HP is too tight or fires heal too little, and the clock has quietly
become scenery.

### Why damage does not subtract from Remaining directly

The elegant-sounding version breaks three ways:

- **The layers collapse.** "Block this or eat it" (tactical) and "can I afford
  this route" (strategic) become one decision on one number, and the game loses a
  dimension it currently has for free.
- **The scale does not exist.** A fight deals maybe 30–40 total damage. As
  minutes that is noise against a 720h budget; as hours it swallows the whole
  budget in about twenty fights, leaving nothing for turns or walking. There is
  no middle value that works.
- **Defense becomes strictly correct.** If block prevents *time* loss, and time is
  the master resource, blocking dominates every other use of a turn. Attacking
  stops being justifiable.

## What advances the world clock

| Action | Cost | Notes |
|--------|------|-------|
| Battle turn | 3h (full allotment) | Flat, regardless of spend |
| Room transition | 1-3h, per corridor | Same both ways; backtracking included — see below |
| Fire | 4h rest · 2h upgrade · free convert | Buys **one** of the three |
| Shop | 1h | Spends Restored; there is no gold |
| Event | Variable | The event states its cost before you commit |

### The map is an Isaac floor, not a Spire lattice

Rooms on a grid, walked room to room, freely in any direction. **Every corridor
between two rooms has a length — one to three hours, decided when the floor is
carved** — and walking it costs that, in either direction, backtracking through
cleared rooms included.

The length belongs to the corridor, not to the rooms at its ends. That is what
makes it symmetric: A to B and B to A read the same number off the same edge,
because there is only one number. An earlier draft priced the *room being
entered* instead, which made 62% of corridors cost different amounts depending
on which side you stood on — the same doorway wearing two price tags.

**A corridor's length is known once the player has stood at either end.**
Everything further out is quoted at the base rate (`room_transition_cost`, set
to the true average), so the walk to the boss door is shown as an *estimate*,
marked as one, and it moves as the fog lifts. The number of rooms to the boss is
always exact; only the hours are a guess.

**This is what keeps the route from being solved arithmetic.** With a flat hour
the cheapest path was the shortest path and there was nothing to weigh. With
lengths that differ, a two-room detour can be cheaper than a one-room push, and
the player cannot know that until they are close enough to see it. The plan is
still worth making — it is just no longer guaranteed to survive.

**This structure fits the design better than a Slay the Spire map does.** A
lattice fixes the path length, so the player only ever chooses node *types*. This
game's central question is *how much do I farm*, which is a question about node
**count** — and that is precisely the question an Isaac floor asks: how much of
this do I clear before I open the boss door.

**It also repairs Isaac's weakest strategic point.** In Isaac, clearing the whole
floor is nearly always correct, because rooms cost nothing but real time — so the
"how much do I explore" decision is not really a decision. Here every room costs
minutes and every minute raises Threat, so the full-clear default breaks and the
question becomes live on every floor.

### What actually makes room selection a decision

**The floors must contain far more rooms than the budget can pay for.** This is
the load-bearing ratio, and everything else about the map is secondary to it.

Run the arithmetic. A fight costs about 13h of turns (4.3 turns, measured over
150 runs per greed level). Against a 720h budget, minus nine fires at 4h and the
walking — no longer a rounding error now that corridors are priced individually,
but roughly **a seventh to a fifth** of the run — that is **something like 41
fights affordable** across an entire run.

The acts hold 57 content rooms between them, of which 37 to 49 are fights. So the
budget and the content are within a few fights of each other. That is **too close
to make room selection a decision**: a player can very nearly take everything, so
*which of these do I buy* has no teeth, and what is left is not a choice about
farming but about routing.

The shape to aim for is a floor holding clearly more than the budget can pay for.
The room counts were stocked for that against a much smaller budget; the budget
has since grown to meet them.

*(An earlier version of this paragraph put the affordable count at 68 and called
the ratio inverted. That was computed on 2.3 turns a fight, which was itself an
artifact: acts two and three had no encounters, so every combat room on those
floors resolved instantly and dragged the measured average down. Both the fight
length and the room arithmetic here are the first ones taken with all three acts
fielding enemies.)*

*(An earlier draft claimed empty rooms were what stopped full-clearing from being
correct. That was wrong: Remaining already caps how much can be cleared, all on
its own. The room-to-budget ratio is what creates the decision.)*

Empty rooms were once carrying two jobs. **Corridors with real lengths have taken
the first one over, and done it better:**

- **Geometry starts to matter.** If every step between rooms costs the same, the
  path is irrelevant and the player just counts rooms. Corridors of one to three
  hours make two good rooms side by side worth more than two across the floor —
  and they do it on a scale rather than as a coin flip, so *every* pair of rooms
  is a different distance, not just the ones that happen to have dead space
  between them.
- **Wrong turns become possible.** A dead end made of rewards is not a dead end,
  it is a prize pocket. This one never needed empty rooms: a dead-end fight is a
  detour billed twice whatever is in it.

So `empty_rooms_per_act` is **0**. The count is a dial, not a rule — the cost of
setting it there is that nothing on the floor can be walked *past*. Every
unvisited room is content, so the walk to the boss door is paid in health as well
as hours, and a floor cannot be threaded. Measured, that took completion at the
rushing end from 74% to 43%. Put a few empty rooms back if the floor needs
breathing room.

And **dead ends are billed twice**, in and out, discovered only by walking in.
Reading a floor and routing it well becomes a real skill paid in the game's own
currency.

### Over-farming must not be a silent trap

The failure this design invites is: over-clear acts I and II, discover in act III
that the budget is gone. **That run was lost long before the player found out.**

This is a much worse teaching loop than the genre's norm. In Slay the Spire, the
lesson *do not take that elite at low HP* arrives immediately. Here, *do not
over-farm the first act* arrives forty minutes later, and it reads as the game
having hidden the bill.

Threat stepping upward is the main feedback channel and it helps, but it only
communicates *the world is getting worse* — never *how much you still have to
pay for*.

**Show Threat as progress against the whole run: `Threat 4 / ~30`.** A player who
knows a run is about thirty steps long can read that as a budget gauge. It turns
an invisible trap into a dashboard, and it costs one label. `Balance.validate()`
keeps the denominator honest — `expected_threat_steps` has to equal the number of
steps the budget actually holds, because the escalation curve reads it too and a
label that drifts from the curve is worse than no label.

**Backtracking is not a feature here, it is just movement.** An open map normally
wrecks roguelike pacing because players grind it; this one cannot be grinded, and
the guarantee is free: cleared rooms do not repopulate and Elapsed only ever
rises, so loitering buys nothing and makes the world worse.

**Every connection carries its own cost**, and they are real now: `Room.exits`
maps a direction to a length in minutes, written symmetrically at generation so a
corridor is the same walk in both directions. Kept as a field back when every one
of them was identical, on the same reasoning as `class_id` — free then, a
refactor later.

### Fog of war, and what "perfect information" actually requires

**Rooms adjacent to explored ones show their type** — fight, elite, shop, fire,
event, empty. Their contents stay hidden until entered. Nothing beyond the
frontier is shown.

This satisfies the pillar, and it is worth being precise about why: perfect
information means *no unpriced commitment*, not omniscience. Every room the player
can actually step into right now displays what it will cost them. What fog
removes is long-range planning, which is a different thing and is allowed to be
scarce.

**No exception. The boss door is not shown, and neither is the distance to it.**

`boss_marked_on_map` is off, the room panel quotes no distance, and the map hint
carries nothing but whether walking is allowed right now. `MapState` can still
answer how far the door is — `steps_to_boss()`, `minutes_to_boss()`,
`boss_walk_is_guess()` — but those are for the tests and the generator, and the
comment above them says so. Isaac hands the player a Compass eventually; this
floor has no Compass.

**This is a real cost and it is worth writing down rather than discovering
later.** The argument for marking the boss was that the run's central decision is
*go now, or clear more*, and that decision cannot be made blind. It is now made
blind. What the player has left to budget with is Remaining, the Threat step, and
what the frontier shows — enough to know how much run is left, not enough to know
what leaving costs. *Go now* stops being a choice that can be taken deliberately
and becomes something that happens when the door turns up.

The counterweight is that finding the door is the exploration, which is the Isaac
shape this map was chosen for in the first place, and that a floor whose exit is
signposted is a floor the player reads once and then solves. Whether that trade
is right is a playtest question, not an argument question.

**It is one line to reverse in each direction.** `boss_marked_on_map = true` puts
the door back on the map; the distance readout is a `tr()` call and a label in
[`room_view.gd`](../source/scripts/ui/room_view.gd) and
[`map_view.gd`](../source/scripts/ui/map_view.gd). If runs start ending because
the player could not see the exit coming, this is the first place to look.

*(A looser variant, if the full blackout proves too much: reveal the floor's
**shape** — blank room outlines — while still hiding types. Floor-level budgeting
returns without naming the door.)*

Fog has a price of its own, which is good: a dead end is only discovered by
walking into it, at a corridor's length each way. Tune the generator carefully —
a few dead ends are tension, many are irritation.

## Escalation

Elapsed time drives a **Threat Level**. Threat must be:

- **Stepped, not smooth.** Discrete thresholds the player can see approaching.
- **Telegraphed.** The HUD always shows current Threat and hours until the next
  step. Committing to a fight must never silently push you over a line — show
  the projected clock on every map choice before it is confirmed.
- **Back-loaded, not linear.** The multiplier is
  `1 + total * (level / steps) ^ curve` — at `curve 2.0` and `total 1.0` over
  thirty steps, enemies are 25% larger at the halfway mark and twice their
  authored size at the end. A linear ramp spends its whole budget of pressure in
  the first act, where the player has the fewest answers; a curve leaves act one
  close to what the enemies were actually authored as and puts the escalation
  where the deck exists to meet it.
- **Qualitative, not just numeric.** Pure stat bloat is boring and reads as
  punishment. The scaling above is the floor, not the whole of it; the world
  getting worse should be something you can see in enemy behavior. The hooks for
  that are already here — enemies carry per-daytime intent lists — but nothing is
  yet keyed to Threat itself.

### The farm-vs-rush tension

The whole pitch rests on this choice staying close. It will not stay close on its
own.

- If rewards scale with Threat as fast as enemies do, farming is always correct.
- If they do not scale at all, rushing is always correct.

**Rewards scale, but slower than enemies.** Farming has real but diminishing
returns. That alone is not enough, though — a single global dial will always
resolve to one dominant answer once players do the math.

Two things carry the real weight instead.

The first is that **farming buys two different things at one price.** An extra
fight costs a known number of hours and yields Restored, which is simultaneously
power (shops), life (conversion), and ending. So the player is not answering "is
farming worth it" — they are answering *which of the three* they need most right
now, and that answer changes hour to hour within a single run. A question that
keeps changing cannot be solved once on a spreadsheet and shared.

The second is archetypes.

**Split the card pool by clock preference**, so some builds want a short clock
and some want a long one:

- **속공 / Rush** — cheap, front-loaded, wants to end fights in 2–3 turns. Falls
  off hard at high Threat. Its plan is to reach the boss early.
- **엔진 / Engine** — needs turns to come online, so it *pays* time to set up and
  must earn it back. Only viable if it eventually kills faster than Rush.
- **시간 조작 / Chronomancy** — manipulates the clock itself. Refunds, rewinds,
  cost reduction. The archetype that makes the theme mechanical rather than
  decorative.

### Effective energy is worth more here than in Slay the Spire

This governs the whole Chronomancy lane, so it is worth stating before any of
those cards get written.

In Slay the Spire, taking an extra turn costs HP. Here it costs **three hours of
the run**. So a card that buys extra actions inside a turn pays out twice: once
by winning this fight, and again by ending it a turn sooner and leaving the
run's budget alone.

**When pricing refund and cost-reduction effects, expect the Slay the Spire
comparison to read low.** The arithmetic will match and the analogue will be a
rare, and the arithmetic is still missing the second payout.

Held Breath is the card to watch. At `1h → refund 2h, draw 1, Exhaust` it is
strictly weaker than Adrenaline, a rare — except that Adrenaline does not also
refund run time. It ships at the aggressive end deliberately; if the Chronomancy
lane turns out to dominate, this is the first place to look.

The lane still has to be *good* — nobody will play the game's signature
archetype if it is priced into irrelevance. The instruction is to price it
knowing the multiplier exists, not to blunt it.

Now the question is "which deck am I building" rather than "is farming
mathematically correct," and both answers can be right.

**These are three lanes inside one card pool, not three classes.** v1 ships a
single Warden with one pool of roughly 75–100 cards; a run's identity emerges
from what it is offered rather than from a pick at the start. Reasons, in order
of weight:

- The fiction demands it. Every Warden is made the same way from the same
  material for the same task — three classes would mean three kinds of Warden,
  which contradicts succession outright.
- Locking Chronomancy behind a character would mean most runs never touch the
  game's signature mechanic.
- The clock economy already supplies the run-to-run variance that classes usually
  provide. There is a second axis of variety here that most deck-builders lack.
- Three classes is roughly triple the cards, plus enemies balanced against three
  power curves, plus three unique mechanics to design. Slay the Spire itself
  entered early access with one character and added the rest over years.

**The lanes must overlap.** If each lane is a sealed set, the first three card
rewards decide the run and the player can never pivot, which reads as being
railroaded rather than as building something. A large shared core with lane
specialists layered on top is the shape to aim for.

Additional classes are the natural post-v1 expansion. To keep that cheap, put a
`class_id` on card definitions from the very first card even though every card
will carry the same value — see the [README](../README.md) systems table. Adding
the field later turns pool filtering, the unlock ledger, and starting decks into
code branches.

### The boss

The act boss scales to the clock at the moment you arrive. This is what makes the
run a race with a soft deadline rather than an open-ended grind: arrive strong
enough, but before it outgrows you.

## Card design implications

- **Instant (0-cost) cards** are flavorful and mechanically distinct: things that
  take no time. Reflexes, reactions, things already in motion.
- **Time-refund cards** (rare, powerful): return minutes to the *turn budget*.
  Nothing may ever reduce **Elapsed**, and no card should add to **Remaining** —
  conversion at a rest is the only route, and it stays that way because that one
  transaction has to remain deliberate, located, and rare to carry any weight at
  all.
- **Curses are delays.** A curse that costs an hour and does nothing is the most
  thematically honest bad card in the genre.
- **Card removal is premium**, as always, and here it has a name: cutting wasted
  minutes out of the day.
- Cards whose cost changes with time of day, or with Threat, are a natural fit.

## Risks to watch

1. **The core choice collapsing.** Hardest tuning problem in the game. Mitigated
   by Restored serving three competing needs at once, and by archetypes — not by
   numbers alone.
2. **Clock pressure vs. deck-builder pleasure.** Players come to this genre to
   watch an engine come online. A clock that punishes long fights punishes engine
   decks by default. The Engine archetype must have a genuine payoff, or the game
   quietly becomes rush-only.
3. **Hoarding.** Solved by the unspent-time rule. Do not weaken it.
4. **Anxiety.** Some players hate timers. The counter is total transparency: the
   cost of every choice is shown before it is committed, so pressure comes from
   the decision, never from a surprise.

## First-pass numbers

Unvalidated. These exist so the first prototype has something concrete to argue
with, not because they are right.

| Quantity | Starting value |
|---|---|
| Turn budget | 3h |
| Starting Remaining | 30 days (720h) |
| Max HP | 80 |
| Fire heal | 20% of max HP |
| Battle turn tick | 3h |
| Average fight | 2.3 turns → ~7h spent (measured) |
| Restored per normal fight | ~6h |
| Restored per act boss | large — the run's pulse; tune once acts exist |
| Content rooms per act | 14 / 19 / 24, split between fights and events |
| Fights per act | 10-12 / 12-16 / 15-21, rolled inside that split |
| Events per act | at least 2 / 3 / 3 |
| Elites per act | 2 / 2 / 3, placed 10h from the start and 5h apart |
| Fires per act | 2 / 3 / 4 |
| Shops per act | 1 / 2 / 2 |
| Empty rooms per act | 0 — corridors carry the dead space instead |
| Total rooms per act | 21 / 28 / 35, start and boss door included |
| Fire prices | rest 4h · upgrade 2h · convert free |
| Conversion rate | 2 Restored → 1 Remaining |
| Conversion cap | 36h of Restored per fire, yielding 18h |
| Enemy scale | both x1.0 — enemies fight as authored |
| Room transition | 1-3h per corridor, same both ways, guessed at 1.5h until walked (~26-36% of a run) |
| Threat step | every 24h **elapsed** (30 steps per run) |
| Threat curve | `1 + 1.0 * (level/30) ^ 2.0` — x1.25 at the halfway mark, x2 at the end |

The number to watch in the first playable build is **how much of a run's Restored
a competent player has to convert just to survive.** If it is near zero, the fire
never asks anything and the delivered/kept axis is inert. If it is near
everything, delivering is impossible and the axis is equally inert. Target roughly
half, so both directions stay reachable and the decision is live every time the
player sits down at a fire.

## What the simulator found

Four passes of measurement, and each one contradicted the guess before it. The
wrong answers are recorded because they were reasonable ones and will be reached
for again.

**Content was not the problem.** Going from 8 cards to 32 moved completion by
nothing at all. The deck was never the constraint.

**Neither was health supply.** Doubling it — 196 to 404 — bought one and a half
extra fights. A run that dies in act one never sees the fires of acts two and
three, so the supply on paper is not the supply anybody gets.

**Act one held more rooms than a whole run could afford.** 19 combat rooms per
act against a budget that bought eight fights meant acts two and three were
content nobody would ever reach. Nine per act, six affordable.

**The fourth pass overturned the third.** The reading at the time was that fight
*length* was the whole story, and enemy health was scaled to 0.6 on that basis.
It was an artifact of the measuring instrument — see below — and it was also a
bad idea on its own terms, because a global health multiplier turns every number
on the enemy `.tres` files into a lie. `Balance.validate()` now rejects any
`enemy_hp_scale` other than 1.0 so it cannot be reached for again. Enemy health
is authored on the enemies.

Both global scales now sit at 1.0 — `enemy_damage_scale` was 0.8 for a while and
has been returned to full. Enemies fight exactly as written, and the dials that
moved instead are the numbers on the enemies themselves and the Threat curve
above.

### The instrument was reading itself

`SimPolicy` blocked only when incoming damage exceeded its block plus 40% of its
health. Lower enemy damage far enough and the policy stopped blocking at all, so
a sweep of enemy damage measured the threshold rather than the game and reported
that damage barely mattered. Health sweeps looked trustworthy by comparison, and
that is why health got scaled.

The policy now blocks whenever an incoming hit is not already covered. The rule
is magnitude-free, so it cannot switch itself off. With it in place the damage
axis sweeps cleanly, and it is the axis that moves losses from the health bar to
the clock — which no amount of health scaling ever did.

**A policy with a threshold in it cannot be used to tune the thing the threshold
is about.** That is the transferable part.

### The health pool is what lets the clock matter

**Measured under the superseded profile: 336h, 8h fires, 3 fires an act, flat
Threat.** The sweep below is kept because its shape is the finding and the shape
is still the finding; the absolute numbers are not comparable to anything the
game currently does.

Measured at full enemy damage and full enemy health — the enemies are never
softened. Only the player's side moves. Re-measured after `SimPolicy` was fixed;
every number taken before that is void, and the two that changed sign are called
out below.

| starting hp | heal | fires | completion by greed | losses: clock / health |
|---|---|---|---|---|
| **70** | 0.40 | 3 | 64 / 32 / 18 / 2 | **0%** / 99% |
| 70 | 0.40 | 5 | 60 / 46 / 24 / 4 | 1% / 98% |
| 90 | 0.50 | 4 | 84 / 52 / 24 / 12 | 4% / 95% |
| 110 | 0.50 | 5 | 94 / 90 / 48 / 8 | 15% / 85% |
| 130 | 0.50 | 5 | 98 / 98 / 56 / 12 | 22% / 77% |
| 150 | 0.55 | 5 | 100 / 98 / 64 / 22 | **41%** / 58% |

**Hard-hitting enemies are compatible with a clock-driven game — but only with a
large health pool.** At 70hp the clock never kills anyone: every run ends on the
health bar and the clock is scenery. It does not start binding until the pool is
large enough that fights stop being what ends runs. Softening the enemies is the
other road to the same place and it costs the fights their teeth.

Nothing here was applied at the time. The shipped tuning was the top row — a hard
game that ends on the health bar.

### Where it stands now

The profile has moved a long way since: 720h instead of 336h, 80hp instead of 70,
nine fires instead of six and cheaper, corridors priced individually, Threat on a
back-loaded curve. The reading did not move with it.

| greed | finished | fell (hp) | ran out (clock) | ended in act | fights | turns/fight |
|---|---|---|---|---|---|---|
| 0.00 | **0** | 150 | 0 | 1.5 | 10.0 | 4.70 |
| 0.35 | **0** | 150 | 0 | 1.5 | 10.2 | 4.50 |
| 0.70 | **0** | 150 | 0 | 1.4 | 11.4 | 4.41 |
| 1.00 | **0** | 150 | 0 | 1.3 | 12.4 | 4.30 |

150 runs per greed level, and the first sweep in which all three acts hold
content — acts two and three borrow act one's encounters and events (see
`BORROW_FROM_ACT` in `EncounterTable` and `EventTable`), so the later floors are
act one's Askew grown by the Threat curve rather than anything authored for them.

Letting events borrow as well as encounters moved nothing: act reached 1.4 either
way, and completion stayed at zero. That is worth recording as a result rather
than a non-event — runs are ending too early to reach the content the borrow
adds, which is the same thing every other number here is saying.

**Nothing finishes.** All 600 runs end on the health bar, none on the clock, and
a run reaches 0.6 of the 9 fires it holds. Restored converted: 18%, against a
target of about half.

The previous sweep read 32-45% completion, and that number was not real. With no
encounters on the later floors, every combat room there cleared instantly and
handed out a card, so surviving act one amounted to winning. Two measurements
were inflated by the same hole:

| | with the hole | with acts filled |
|---|---|---|
| turns a fight | 2.3 | **4.3** |
| hp lost a fight | 4 | **7** |
| fights a run | 18-20 | 10-12 |

So a fight is nearly twice as long and nearly twice as costly as the numbers in
this document said a week ago, and the shortfall was never in the tuning — it was
that a third of the run was not being played.

What has *not* changed is the answer to this document's own question. Losses are
still 100% health, 0% clock. Filling the acts made the game much harder without
moving a single loss onto the clock, which says the two failure states are not
competing yet: runs end long before the budget is a constraint on anything.
