# Setting

## Tone

**Cold and sorrowful, with something wrong underneath.**

Melancholy alone goes inert — a game that is only sad stops registering after an
hour. Eerie alone goes shallow — unease with nothing under it is a haunted house.
Together they produce the register this premise actually wants: **sad wrongness.**
Things that should not be, and are not monstrous about it. Grief in a shape that
does not fit.

Practical rules, because tone is only real if it survives contact with a hundred
small decisions:

- **Nothing roars.** The Askew do not threaten. They continue.
- **No villain.** Nothing in the world below wants anything. That is the horror.
- **Understate.** The god never explains. Memories never conclude. Endings do not
  moralize. The player assembles meaning; the game declines to hand it over.
- **Low chroma, high contrast.** Desaturated everything, with the white gauge as
  nearly the only clean light on screen. The one bright thing is the time being
  taken back.
- **Silence is the default.** The score is sparse. What fills the gap is the clock.

The failure mode to watch: this tone drifts toward *dreary* if nothing warm ever
appears. There must be ordinary human warmth in the memories, or the loss has no
weight — a player cannot mourn something they were never allowed to like.

## The hourglass

A god kept the flow of time in an hourglass. It broke.

**Not dropped. Worn out.** The thing that measured how long things last did not,
itself, last. This is the right version for two reasons: a god who fumbles is
faintly comic and would fight the tone, and *even the measure of duration has a
duration* is the truest thing the premise can say.

Time spilled into the world below and pooled where it should not have, ran
backwards where it should have run forward, stopped where it should have moved.

## The god

Called **겁 (劫)** — the kalpa, an immensity of time — because the name is not
remembered. Names are among the things time erodes, and this one had longer than
most to erode. *(Provisional. If a proper name is ever needed in dialogue, the
right move is that no two characters use the same one.)*

The god is **not a character.** They appear once per Warden, at the making, and
say very little. This is a deliberate constraint: a chatty god in a hub area is
the fastest available way to destroy this tone, and the distance is itself the
characterization. The god is not cruel. The god is a steward who failed at a
scale no one can be held to, and has nothing useful left to say about it.

## 하계 — the world below

**The mortal world.** "Below" describes only where it sits relative to the god;
to everyone living in it, it is simply the world. Fantasy in register — its own
towns, roads, trades, and people — and completely ordinary to the people in it.

This is not a haunted zone or a special region set aside for the story. It is
where everybody lives, and the leak happened to it.

That ordinariness is doing real work. The eerie half of the tone needs something
mundane to push against, and grief needs the player to have liked something
first. Both come free from a world where people are having meals, waiting for
each other, and getting on with it.

**The map is smaller than the world.** The spill pooled unevenly, and a run covers
the stretch where it pooled worst. That is a production boundary, not a fact about
the setting — the player travels a route through one afflicted region, never a
tour of everything that exists.

### The three acts are how far gone the Askew are

**An act is not a place. It is how much of the moment is left.**

The Askew are moments that broke under load. Some have been broken longer than
others, and a run walks from the ones that can still be recognised toward the ones
that cannot.

| Act | The Askew there |
|---|---|
| **I** | You can tell what the moment was. A door. Footsteps. An evening. |
| **II** | Worn. Something was there and it is no longer clear what. |
| **III** | Nothing recognisable left. The mechanism, still going. |

The towns and the roads are the same all three times. **What changes is what is
standing in them.**

**Deformed does not mean bigger.** This is the rule the structure rests on, and it
is easy to break by accident. Threat already scales enemies — hp and damage, on a
back-loaded curve, driven by Elapsed. If an act scaled them as well, the two would
double-count, and the claim that the world gets worse because *the player took too
long* would quietly stop being true: act III would be hard because of where it is
rather than because of what was spent getting there. So:

| | Measures | Lives in |
|---|---|---|
| **Threat** | how big | `threat_hp_multiplier` and the curve |
| **The act** | how wrong | which Askew a floor is allowed to field |

**An act III Askew is not an act I Askew with more hp. It is a more broken one.**

**Deepen the five categories rather than adding new ones.** 되풀이, 역행, 정지,
겹침 and 노화 are what keeps a combat system with one damage type from going flat,
and a sixth would blunt that rather than sharpen it. A later act fields the same
five, further gone — a loop worn out of shape, a stilled thing that no longer
remembers to start again. The player's vocabulary keeps paying off, and the work
stays a matter of filling existing encounter slots, which is what the
meta-progression rules in the [README](../README.md) ask for anyway.

**The naming follows.** Act one names point at ordinary things — 되풀이하는 문,
겹친 발소리, 같은 저녁. By act three a name that still pointed at an object would
be lying about what is standing there.

**The order cannot be reversed.** Opening on the unrecognisable would spend the
strangeness before the player has anything to measure it against, and it would run
the Warden's arc backwards: it learns what these things were by meeting them while
they are still legible.

**Why the later acts hold worse-broken things is not explained.** The tone rules above
already say the game declines to hand meaning over, and this is a good place to
decline. If a cause is ever wanted it is an open question, not a hole.

**(The idea that acts differ by how deformed the Askew are is not mine. The
legible/worn/illegible ladder, the Threat split and the naming rule are —
removable.)**

## The Warden

Made by the god, for this, out of **what was left in the hourglass when it
broke** — the last time that did not leak.

The Warden is a purpose-built thing. No past, no home, no one waiting. That is
not a hole in the character; it is the lens the story is told through:

- **Everything is a first.** A made thing walking through an inhabited place for
  the first time, in order to end something. Every ordinary human detail lands as
  new — which is how a melancholy setting keeps registering instead of going numb.
- **The Warden is wrong too.** Made quickly, by a god not practiced at bodies,
  from material never meant to hold a shape. The Askew are not hostile to the
  Warden so much as *unsurprised by* it. They recognize kin. Do not overplay
  this — one or two moments across a run, never stated outright.

The body being a hasty vessel is also where the health bar comes from. Damage is
that vessel failing; sitting at a fire is time spent holding it together. **A
thing made of time, spending itself to stay in one piece.** Mechanically this is
why injury is paid for in hours rather than being its own way to die — see
[time-system.md](time-system.md).

### What the Warden does not know

**The Warden has no concept of time.** Not ignorance of the local calendar —
it does not understand duration, or loss, or why a finite life would matter to
anyone. It does not know what death is. It was made a few hours ago to gather
something up, and it is gathering.

This is the arc, and it is the most important thing in this document.

**The player already knows everything the Warden is about to learn.** Anyone who
has played this genre understands within a minute that the clock matters. The
Warden does not. So the character arc runs *inverse to the learning curve* — the
Warden spends the run arriving at what the player knew at the title screen. Very
few games can do this, and it costs nothing to build.

On top of that, the economy produces the tragedy without anyone writing it:

> The Warden learns what time is worth **by spending it**. It learns what death
> is **by approaching its own**. It becomes something that wants to keep living
> at exactly the point where it has the least life left.

The arc completes precisely when it is too late. That is not a scripted ending
beat — it is what the numbers do on their own.

### The trap

"A being without feeling learns to feel" is among the most worn arcs in fiction.
It is worn because it works, but it turns saccharine at the slightest push, and
saccharine would kill this tone outright. Two hard rules:

1. **The Warden does not become human.** It learns exactly enough to understand
   what it has been doing, and that understanding is horrifying rather than
   warming. Not *I can feel now, and it is beautiful.* Closer to: *I understand
   what I have been doing, I cannot stop, and there is not enough of me left to
   stop with.*
2. **The Warden never narrates its own growth.** No line where it wonders whether
   it is feeling something. Instead the change shows in **what it notices** — see
   the voice rule in [narrative.md](narrative.md). The prose register shifts
   across a run and the Warden never once remarks on it.

## The deadline

> **The Warden is the last of the unspilled time. Spend it and there is no
> Warden.**

There is no more where it came from. The hourglass is empty and broken; the god
cannot top the Warden up. The amount was fixed at the making, and someone decided
how much would be enough — a cold detail worth leaving unexplained.

This is why the run timer is not a timer. It is the protagonist's body. The
resource, the deadline, the health of the story layer, and the theme collapse
into one number the player is already watching, and no one ever has to be taught
why running out is bad.

## Succession

When a Warden is unmade, the god makes another — **out of the time the previous
Warden delivered.**

The loop closes completely. Reclaimed time that is returned becomes the next
Warden; time a Warden kept for itself does not. **What you give back becomes your
successor.**

**A Warden inherits nothing.** Each one begins knowing nothing about time, loss,
or death, so the arc runs whole every time. What accumulates across runs is the
afflicted region — more time returned means more of it working properly, so more is
possible there. Mechanically that is content unlocks and no permanent power; see
the meta-progression section of the [README](../README.md).

**Every Warden learns. The god knows this. The god keeps making them.**

Not out of cruelty — there is no other way to do the thing that has to be done,
and the god has nothing to offer about it. But it means the making is not
innocent, it means *you are not the first one they sent* carries its full weight,
and it binds the succession structure to the arc instead of leaving them as two
separate ideas. **(Addition, not part of the original premise — removable.)**

This also settles a risk worth naming. Time mechanics plus roguelike restarts
pull hard toward an explicit time loop, and that premise is badly overused right
now. Succession delivers the same structure — persistent world, accumulating
metaplot, diegetic restart — in a register of inheritance rather than repetition.
And on a creature with no memory, the strongest line the structure offers lands
harder than it would on a person: *you are not the first one they sent.*

## The Askew (어긋난 것들)

Not demons. Moments that broke under load. Each category is a mechanic first and
a creature second, which is what keeps a combat system with one damage type from
going flat:

| Category | Fiction | Mechanic hook |
|---|---|---|
| 되풀이 / Loopers | A moment repeating forever | Cycles a fixed intent sequence; must be interrupted, not killed |
| 역행 / Reversed | Running backwards | Intent list plays in reverse; certain damage sources heal it |
| 정지 / Stilled | A moment that stopped | Skips most turns entirely, then acts enormously |
| 겹침 / Overlaid | Existing at two times at once | Two instances one turn apart; damage lands on the other on delay |
| 노화 / Withered | Aging too fast | Opens overwhelming, weakens every turn — a race |

None of them attack out of malice. They are continuing. The Warden interrupts.

## The white gauge

Enemy health drains as a white gauge, not a red one. Same mechanic, opposite
reading: the player is not destroying something, they are recovering something.

**Implementation call:** health stays in abstract points, not minutes. Total
unification — an enemy "has 14 hours," cards dealing damage in minutes — reads
beautifully and produces unusable numbers. Health is points, the white gauge is
the visual, and the **Restored** time gained on defeat is derived from the
enemy's maximum health.

What is recovered does not go into the Warden. It goes into a pool being carried
back. The Warden's own clock runs one direction only, because a game about time
that lets you earn time back is a game about money.

### Memories

Reclaimed time carries traces of the lives it leaked out of. So the Warden
accumulates memories — **none of them its own, and none of them ever going to
be.** A thing with no life of its own, collecting fragments of lives it cannot
have.

This is the primary narrative delivery channel and the main source of warmth. See
[narrative.md](narrative.md).

## The conversion

At a fire, the Warden may convert reclaimed time into its own life. It is the
only way the Warden's clock ever goes up. See [time-system.md](time-system.md).

**This is not theft, and the game must never frame it as one.** Theft requires
knowing there is something to take. The Warden does not know what time is worth,
what loss is, or that the hours it is carrying came out of anyone. It cannot
transgress against a concept it does not hold.

What it actually is: **operation.** The instruction was to gather the time. The
Warden must keep working in order to keep gathering, and it uses what it must.
Nothing about this is forbidden and nothing about it is hidden. It is closer to a
machine burning some of the fuel it was sent to transport.

The weight sits entirely on the **player's** side of the screen. They are the only
one in the room who understands what the number means. The Warden is not doing
anything wrong, the game passes no judgment, and the player knows anyway. That gap
does all the work, and it does it without a word of moralizing — which is what the
tone rules demanded in the first place.

Mechanically it holds because it cannot be refused: Remaining rises by no other
means, so the question is never *should I*, only **how much do I need to finish**.
A player who fights well needs little. A player who is struggling uses more,
survives, and arrives having spent much of what they came to return.

## Endings

Two axes — one earned by play, one by choice, so that neither skill nor
decision-making is ignored:

- **Delivered vs. taken.** How much made it back, and how much is now walking
  around wearing the Warden's shape. What is delivered becomes the next Warden.
- **Memories recovered** — which is to say, **how much the Warden understood by
  the end.** The two are the same axis: memories are how it learns.

|  | **Delivered** | **Kept** |
|---|---|---|
| **Understood little** | The task done exactly as instructed by something that never grasped what it was doing. The time goes back. The god makes another. The job is finished. | It used most of what it gathered and finished anyway, never knowing there had been anything there. |
| **Understood much** | Knows by now what it is giving up, and gives it. It has learned what death is, and goes to it. | Knows by now, and continues existing regardless. **The most human outcome.** |

The bottom-right corner is the strongest, and it is not a failure state. Wanting
to keep living, once you finally understand what living is, is the least strange
thing in this entire setting.

No cell is the good ending and the game says so about none of them. It does not
narrate consequences, weigh the two axes against each other, or tell the player
which corner they should have reached. A player who rushed perfectly and a player
who saw everything arrive somewhere different; the game shows them where they are
and stops.

The final choice — give back what is left, or keep it — is offered to everyone,
but it means different things depending on where they already stand. A Warden who
took almost nothing is being asked for very little. A Warden that is mostly other
people's hours, and now understands what that means, is being asked for
everything.

## Open

- Final title.
- Whether the epithet 겁/劫 survives contact with actual dialogue.
- What the people of the world below know about any of this.
- Why the Askew further in are further gone. Deliberately unanswered for now; it
  becomes a real question only if something in the game ever has to say.

**Resolved:** what the three acts are — how far gone the Askew are, above. That
also answers what the three acts should look like: the world does not change
between them, the things standing in it do.
