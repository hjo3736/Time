# Narrative

Story-driven, which in a roguelike means solving one problem first: the player
will see the opening of the run dozens of times.

## The synergy worth building the whole story around

Time is already the economy. Spend it on the story instead of on power, and the
theme stops being decoration:

> **Every hour spent getting stronger is an hour of story you do not get to see —
> and an hour off your own life.**

Concretely:

- **Expiring nodes.** Some map nodes vanish after a clock time. Take the elite
  detour and the person waiting at the crossroads is gone when you arrive.
- **Time-of-day gating.** Characters exist in windows. Someone is only at the
  tavern in the evening; someone else only walks the road at dawn.
- **Arrival-time endings.** The final scene branches on *when* you get there, not
  only on whether you win.

This gives the game deliberate missable content, which is the strongest replay
driver a story roguelike has — and unlike most missable content, missing it is a
choice the player consciously made and can see the price of.

## The repetition problem

Three viable structures:

1. **Diegetic loop (Hades model).** Dying is part of the fiction; the world
   remembers. Persistent NPCs, dialogue that advances per run, a metaplot that
   only resolves after many attempts. Strongest fit for a story-first design.
2. **Anthology.** Each run is a different character on a different day. No
   continuity to violate, but no accumulating investment either.
3. **Knowledge-only continuity.** The world resets; the *player's* knowledge does
   not. Puzzle-ish, demanding to write, very strong when it lands.

**Resolved: option 1, via succession rather than a loop.** Each run is a new
Warden, made out of the time the last one delivered. What you give back becomes
your successor. See [setting.md](setting.md).

This is worth restating because it was a real risk that got dodged: time
mechanics plus roguelike restarts pull hard toward an explicit time loop, and
that premise is badly overused right now. Succession delivers everything the loop
would have — persistent NPCs, accumulating metaplot, a diegetic restart — in a
register that is inheritance rather than repetition. The mechanics needed a
deadline and a reason time matters. They never needed a loop.

## Delivering story through combat

Reclaimed time carries traces of the lives it leaked out of, so defeating an
Askew returns **a memory that is not the Warden's and never will be**. A made
thing with no life of its own, accumulating fragments of lives it cannot have.

This is the primary narrative delivery channel, and it is worth being deliberate
about why:

- It puts story on the critical path without interrupting it. No cutscene gate,
  no "press E to read lore."
- It scales with content naturally — every new enemy is a place to put a memory.
- It makes the Restored counter *mean* something beyond arithmetic. The player is
  not watching a resource, they are watching an accumulation.
- It gives every fire its weight. Converting Restored into the Warden's own life
  is, in the fiction, keeping the hours these memories came from. The player is
  spending named people to stay alive, and the game does not editorialize.

Keep memories short. A paragraph, a fragment of a scene, no exposition. The
restraint is what makes them land.

### Memories are the arc, not decoration

The Warden begins with no concept of time, loss, or death (see
[setting.md](setting.md)). Memories are **how it learns.** That makes their
content an ordered curriculum rather than a pool of flavor text:

| Act | What the memories are about |
|---|---|
| **I** | Sensation and ordinary life. A meal. Cold hands. Waiting for someone who is only late. Nothing is at stake and nothing is explained. |
| **II** | Duration. Things that took a long time, things that were too short, someone counting days. The first memories where the *length* of something is the point. |
| **III** | Loss. Goodbyes, endings, the deaths of people the player has already met in earlier fragments. |

The third act only works if the first two did their job. A death fragment lands
because the player met that person eating breakfast six hours ago, and it lands on
the Warden because by then it has enough pieces to understand what is being
described. **Never open with grief.** A player cannot mourn someone they were
never given a chance to like — that is also the specific failure mode that turns
this tone dreary.

### The voice rule

The Warden's narration changes across the run, and **the Warden never remarks on
it.** This is the entire technique for showing the arc without stating it.

- **Early:** measurements. Distances, counts, hours remaining. People are
  described by position and number. No adjectives about anyone.
- **Middle:** it begins recording details with no operational value. It does not
  explain why it recorded them.
- **Late:** it lingers. It describes faces. It notes what someone was doing before
  it arrived, and it stays a sentence longer than it needs to.

One line of the Warden wondering whether it is feeling something would undo all of
this. There must never be such a line. The register shifts; nothing acknowledges
the shift; the player notices on their own.

### The fire, specifically

When the player converts Restored into Remaining at a rest, **name whose hours
they are taking.** One line, a person already met in a memory, no commentary.

**The fire text learns, and the rule does not.** This is the cheapest strong
scene in the game: the mechanic is byte-identical from the first fire to the
last, and only the text around it changes.

- **Early:** the Warden does not register that a name is a person. It states the
  transaction. This is not callousness — it does not know there is anything
  there.
- **Late:** it reads the name. It pauses. It converts anyway, because it has to.

The pause is recognition, **not guilt.** The Warden is following the instruction
it was made for and has done nothing wrong; it has simply learned, by then, that
there was someone there. Do not write remorse into these scenes. Do not have it
apologize, hesitate morally, or refuse. It notices, and it continues, and the
player supplies everything else.

The tempting stronger version is to have conversion *consume* the memory
outright — burn a person to keep walking. It is a better sentence than it is a
mechanic: it deletes narrative content the player worked for, and it will make
players refuse to convert, which breaks the survival pressure the whole economy
depends on. Naming costs nothing and lands most of the hit.

## Open

- Tone: how bleak. The premise supports anything from melancholy to warm, and
  that choice governs art direction more than any other decision here.
- Whether story beats are authored per-act or drawn from a pool.

**Resolved:** a succeeding Warden remembers nothing. Meta-progression is content
unlocks only, so the arc runs whole every time and the writing never has to
account for a protagonist who already knows the ending of its own story.
