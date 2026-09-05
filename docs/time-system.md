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

**It does not reset between acts.** 336h covers all three, start to finish.

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
| Restored by | **Resting only** | **Conversion at a fire only** |
| At zero | Lose the current fight | The Warden is gone |
| Lives in | `RunState` | `RunClock` |

### Damage is a tax, not a cause of death

Taking a hit does not kill the player. It makes them need a fire, and a fire
costs 8 hours.

> damage taken → HP low → need a fire → 8h spent → Remaining drops

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

### The fire: one action for eight hours

Pay 8h and take **one** of:

1. **Rest** — heal roughly 30% of max HP
2. **Upgrade** — improve one card
3. **Convert** — Restored into Remaining at 2:1, capped

Slay the Spire's rest-or-smith with conversion added as a third arm. This gives
conversion a real opportunity cost beyond the exchange rate, and it produces this
design's signature squeeze: **when HP is low and time is short, the player has to
choose which way to die.**

*(Tuning risk: this may prove too tight. If so, the first thing to loosen is
allowing conversion alongside one other action, not adding a fourth option.)*

### A worked segment

Opening: Remaining 336h · HP 70/70 · Restored 0.

| Step | Remaining | HP | Restored |
|---|---|---|---|
| start | 336h | 70/70 | 0 |
| travel 2h → normal fight, 3 turns (9h), take 12 | 325h | 58/70 | 6h |
| travel 4h → **elite**, 6 turns (18h), take 26 | 303h | 32/70 | 20h |

Decision point at 32/70. A fire sits 3h away; a shop sits 1h away.

- **Fire:** 3h travel + 8h = 11h → Remaining 292h, HP 53/70. The 20h of Restored
  stays unspent, because the fire only buys one thing.
- **Shop:** 1h travel → Remaining 302h, and 20h of Restored buys cards. HP stays
  at 32, and the next bad fight ends the run.

Ten hours and a card reward against a third of the health bar. The answer differs
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
  minutes that is noise against a 336h budget; as hours it makes a run eight
  fights long. There is no middle value that works.
- **Defense becomes strictly correct.** If block prevents *time* loss, and time is
  the master resource, blocking dominates every other use of a turn. Attacking
  stops being justifiable.

## What advances the world clock

| Action | Cost | Notes |
|--------|------|-------|
| Battle turn | 3h (full allotment) | Flat, regardless of spend |
| Room transition | 1-3h, per room | Backtracking included — see below |
| Fire (rest) | 8h | Buys **one** of: heal / upgrade / convert |
| Shop | 1h | Spends Restored; there is no gold |
| Event | Variable | The event states its cost before you commit |

### The map is an Isaac floor, not a Spire lattice

Rooms on a grid, walked room to room, freely in any direction. **Every room
costs time to enter — one to three hours, decided when the floor is carved** —
including walking back through rooms already cleared.

**A room's price is known only once it has been surveyed**, meaning the player
has stood in it or in one of its neighbours. Everything further out is quoted at
the base rate (`room_transition_cost`, set to the true average), so the walk to
the boss door is shown as an *estimate*, marked as one, and it moves as the fog
lifts. The number of rooms to the boss is always exact; only the hours are a
guess.

**This is what keeps the route from being solved arithmetic.** With a flat hour
the cheapest path was the shortest path and there was nothing to weigh. With
prices that differ, a two-room detour can be cheaper than a one-room push, and
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

Run the arithmetic. A combat room costs ~10.5h of turns. Against a 336h budget,
minus six fires at 8h and roughly 60h of walking, that is **about 23 combat rooms
affordable** across an entire run — a little more once conversion is counted.
Note how much of that is travel now that rooms are priced individually: walking
is no longer a rounding error, it is roughly **a quarter to a third** of the run
(measured, 100 runs per greed level). Routing well buys rooms.

So if the three acts hold about 23 combat rooms, the player simply takes all of
them and there is no choice to make. **Stock the acts with 55–60**, and every
floor becomes *which of these do I buy*.

*(An earlier draft claimed empty rooms were what stopped full-clearing from being
correct. That was wrong: Remaining already caps how much can be cleared, all on
its own. The room-to-budget ratio is what creates the decision.)*

Two things empty rooms **do** earn:

- **Geometry starts to matter.** If every room pays out, the path between them is
  irrelevant and the player just counts rooms. With dead space in between, two
  good rooms side by side are worth more than two good rooms across the floor.
- **Wrong turns become possible.** A dead end made of rewards is not a dead end,
  it is a prize pocket.

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

**Show Threat as progress against the whole run: `Threat 4 / ~14`.** A player who
knows a run is about fourteen steps long can read that as a budget gauge. It
turns an invisible trap into a dashboard, and it costs one label.

**Backtracking is not a feature here, it is just movement.** An open map normally
wrecks roguelike pacing because players grind it; this one cannot be grinded, and
the guarantee is free: cleared rooms do not repopulate and Elapsed only ever
rises, so loitering buys nothing and makes the world worse.

**Keep a `cost_minutes` field on each connection** even while every one is 30.
Same reasoning as `class_id`: free now, a refactor later.

### Fog of war, and what "perfect information" actually requires

**Rooms adjacent to explored ones show their type** — fight, elite, shop, fire,
event, empty. Their contents stay hidden until entered. Nothing beyond the
frontier is shown.

This satisfies the pillar, and it is worth being precise about why: perfect
information means *no unpriced commitment*, not omniscience. Every room the player
can actually step into right now displays what it will cost them. What fog
removes is long-range planning, which is a different thing and is allowed to be
scarce.

**One exception: the boss room is marked from the moment the floor begins.**

The run's central decision is *go now, or clear more*, and that decision cannot be
made blind. Isaac eventually hands the player a Compass for exactly this reason;
here it is not an item but the default, because knowing where the boss sits is an
input to the core loop rather than a convenience.

*(A looser variant: reveal the floor's **shape** — blank room outlines — while
still hiding types. Floor-level budgeting returns completely, at the cost of some
of the Isaac feel. Try boss-marking alone first.)*

Fog has a price of its own, which is good: a dead end is only discovered by
walking into it, at an hour each way. Tune the generator carefully — a few
dead ends are tension, many are irritation.

## Escalation

Elapsed time drives a **Threat Level**. Threat must be:

- **Stepped, not smooth.** Discrete thresholds the player can see approaching.
- **Telegraphed.** The HUD always shows current Threat and hours until the next
  step. Committing to a fight must never silently push you over a line — show
  the projected clock on every map choice before it is confirmed.
- **Qualitative, not just numeric.** Pure stat bloat is boring and reads as
  punishment. Every threshold raises HP/damage modestly; every *third* threshold
  unlocks a new enemy ability or intent. The world getting worse should be
  something you can see in enemy behavior, not just in a health bar.

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
| Starting Remaining | ~14 days (336h) |
| Max HP | ~70 |
| Fire heal | ~30% of max HP |
| Battle turn tick | 3h |
| Average fight | 3–4 turns → 9–12h spent |
| Restored per normal fight | ~6h |
| Restored per act boss | large — the run's pulse; tune once acts exist |
| Total rooms per act | ~20 |
| Fires per act | 3, healing 40% |
| Conversion rate | 2 Restored → 1 Remaining |
| Conversion cap | 36h of Restored per fire (yields 18h; net +10h after the 8h fire) |
| Combat rooms per act | 9 available, ~6 affordable |
| Enemy scale | both x1.0 — enemies fight as authored |
| Room transition | 1-3h per room, guessed at 1.5h until surveyed (~26-31% of a run) |
| Threat step | every 48h **elapsed** (~14 steps per run) |

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
in `tool_write_enemies.gd` into a lie. `Balance.validate()` now rejects any
`enemy_hp_scale` other than 1.0 so it cannot be reached for again. Enemy health
is authored on the enemies; the tuned axis is `enemy_damage_scale`, at 0.8.

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

Nothing here is applied. The shipped tuning is the top row — a hard game that
ends on the health bar.
