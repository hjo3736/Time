# Deckbound

A single-player, story-driven deck-building roguelike in the Slay the Spire
lineage, built around a single resource: **time**.
Working title — rename freely.

- **Engine:** Godot 4.7.2 (Steam build), GDScript
- **Target:** PC (Windows first), mouse-driven, 1920x1080 base viewport
- **Status:** run state, the card layer and 32 cards implemented and tested.
  The battle loop runs end to end and all five Askew categories behave.
  Ten Askew and fifteen encounters exist, all of them act one, with Threat on a
  back-loaded curve. Floors generate and can be walked; rewards, shops, fires,
  relics and events all work. A run departs on a date the player picks — the
  date is the seed — and the hour it is drives what the world holds.
  A whole run is playable from a title screen and survives a quit mid-fight.
  **Acts two and three have no encounters yet**, so their fights resolve to
  nothing; that and art are what is missing.

## Core loop

1. Walk an Isaac-style floor of rooms (combat / elite / event / shop / fire /
   empty). Each corridor between two rooms is one to three hours long, the same
   walked either way, backtracking included.
2. Fight turn-based single-screen battles by playing cards from a hand.
3. Take a reward (new card, relic, reclaimed time) and shape the deck.
4. Open the boss door when ready — but it is not marked and its distance is not
   quoted, so finding it is part of the walk. Three acts to a run, each one
   fielding Askew further gone than the last.

Battle turn: draw to hand size, spend energy to play cards, end turn, enemies
resolve their telegraphed intents, discard hand, repeat.

## The hook

A god's hourglass wore out and broke, and time spilled into the world below. The
Warden — made for this, out of the last of the time that did not leak — is sent
down to gather it back.

Time is the card cost, the run deadline, and the difficulty curve at once. Cards
cost minutes and the Warden is made of minutes, so running out is not a game-over
screen — it is the end of the Warden. Their clock only ever goes down.

Defeating an enemy pulls time back out of the leak, but that time is not yours.
It is what you were sent to return, it is also the only currency the shops take,
and at a fire you may burn it into your own life instead. Farm long, spend
yourself, arrive strong to a world that has gotten worse; or rush ahead weak
against weak enemies. Every hour spent on power is an hour of story missed and an
hour off your own life.

The Warden does not know what time is. It has no idea what death is, or why a
finite life would matter to anyone. It learns — from the memories carried in the
time it recovers — and it learns what time is worth by spending it, and what
death is by approaching its own. The arc finishes exactly when it is too late.
The player knew all of it at the title screen.

**Tone:** cold and sorrowful, with something wrong underneath. Nothing roars,
nothing wants anything, and nothing is explained.

See [docs/setting.md](docs/setting.md), [docs/time-system.md](docs/time-system.md),
and [docs/narrative.md](docs/narrative.md).

## Design pillars

- **The deck is the character.** Starting deck is deliberately weak; the run is
  about finding a combo and committing to it.
- **Perfect information.** Enemy intents, draw pile counts, and every number are
  visible. Losses are planning failures, not surprises.
- **Removal matters.** Adding cards is easy, removing them is scarce. Deck size
  is a resource.
- **Time is never wasted quietly.** Unspent time still passes. The player is
  never punished for acting, only for taking too long.
- **Everything is billed in hours.** Injury does not kill the Warden; it sends
  them to a fire, and resting at one costs four hours. Whatever goes wrong, it is
  paid for in the one currency the game is about.

## Meta-progression

**Unlocks only. No permanent stats, ever.** New cards, relics, enemy variants, and
events enter the pools as the player encounters things. Nothing carries power
between runs.

This is Slay the Spire's model rather than Hades', and the reason is **run
integrity**: every run is winnable from the first one, and no run is ever lost to
insufficient grinding. A stat-based meta is a difficulty ramp wearing a
progression costume, and it lets balance problems hide behind accumulated power.
Content unlocks are a *variety* ramp, which has none of that.

Two rules that are easy to get wrong:

- **The base enemy roster ships complete at run 1.** Unlocking the core bestiary
  makes early runs the least varied ones — exactly when a player is deciding
  whether to keep playing. Unlocks add **variants and elites into existing
  encounter slots**: the number of fights stays the same, the possibilities
  inside them grow.
- **Unlock by encounter, never by virtue.** Meet an Askew and its associated cards
  open; reach a new act and that act's pool opens; recover a memory and the
  relic tied to that person opens. Tying unlocks to *delivered vs. taken* would
  quietly score the moral axis, which contradicts the endings design — no corner
  of that grid is supposed to be the right one.

Unlock pacing should be front-loaded: the first several runs open a lot, then it
tapers.

Note this also settles what a succeeding Warden inherits: **nothing.** Every
Warden begins knowing nothing, so the arc stays intact every run. What accumulates
is the world, not the Warden — more time returned to the afflicted region means more
working, which means more is possible.

## Systems to build (rough order)

| # | System | Notes |
|---|--------|-------|
| 0 | `Balance` + `RunClock` + `RunState` | Every tunable number in `balance.tres`; Remaining / Elapsed / Restored / Threat in the clock; HP, deck, relics, room position in the state |
| 1 | Card data model | `Resource` definitions in `source/data/cards/`; include `class_id` from card one |
| 2 | Battle state machine | done — piles, turn budget, intents, win/lose, hp handoff |
| 3 | Effect resolution | done — `BattleEffectContext`; status vocabulary still minimal |
| 4 | Hand & pile UI | prototype done — click to play, intents shown, no art yet |
| 5 | Enemy AI | done for act 1 — five behaviours, ten Askew, weighted encounters, per-daytime intents; acts 2-3 have no encounters at all |
| 6 | Run map | done — seeded Isaac floors, symmetric 1-3h corridors revealed by walking, typed-frontier fog, boss door neither marked nor priced |
| 7 | Rewards & shop | card picks, shop stock and removal done; relic sales wait on relics |
| 8 | Relics | done — four relics; hooks reach the map and the clock, not just battle |
| 9 | Save / resume | done — whole run incl. the fight in progress, JSON in `user://`; unlock ledger still to come |
| 10 | Content pass | the one class: ~75-100 cards across 3 lanes, ~20 enemies, ~40 relics |

## Open questions

- Final title, and the god's name (currently the epithet 겁/劫).
- What the people of the world below know about any of this.
- Whether a departure date should also be a *shared* seed — the date-as-seed
  screen answers the daily-seed question diegetically, but nothing yet suggests a
  date to the player or compares runs that left on the same one.
- Run length is 30 in-game days. Whether that is the right number waits on acts
  two and three existing.


## Localization

**Korean is the source language. English is a maintained pivot.** Every other
language is translated from English, because KO→X translators are scarce and
EN→X translators are not.

Strings live in [`source/data/localization/strings.csv`](source/data/localization/strings.csv)
as `keys,ko,en`. Adding a language adds a column and nothing else — no code
changes, because the code never holds a display string.

Rules, in order of how expensive they are to break:

- **Keys are explicit** (`card.take.name`), never the source text itself.
  Using Korean strings as keys reads nicely right up until someone rewords a
  line and silently orphans every other language.
- **English never lags Korean.** Treat the `en` cell as part of finishing a
  string, not as a later task. The moment it drifts, every language added
  afterwards inherits stale text and nobody can tell which cell is current.
- **Never put a Korean particle straight after a number placeholder.** 을/를,
  이/가 and 은/는 are chosen by how the digit is *read aloud* — 2 is 이 and takes
  를, 8 is 팔 and takes 을 — so no template can pick correctly. Rephrase:
  `{amount}의 방어도를 얻습니다`, not `방어도 {amount}를 얻습니다`.
- **Author narrative text in Korean.** Memories, fire scenes and endings are
  carrying the tone, and tone written in a second language arrives flat. Once it
  is flat in the pivot it is flat in every language downstream.

## Naming: descriptive mechanics, flavoured cards

**A keyword has to describe its own effect.** Block is Block (방어도). Softened
(물러짐) takes more damage; Blunted (무뎌짐) deals less. These words were not
chosen for atmosphere — they were chosen so that a player reads one once and
never has to remember it. A game whose central pillar is *the cost of a choice is
legible before it is committed* cannot afford keywords that need memorising.

**That test is the rule, not the genre's vocabulary.** An earlier pass renamed
Block to "Hold" and Vulnerable to "Unwound"; it read better and played worse,
because neither word says what it does — "Unwound" could mean anything at all.
물러짐 and 무뎌짐 pass exactly where "Unwound" failed: a soft thing takes damage
easily and a blunt edge cuts poorly, so the mechanic is legible off the word.
Rename a keyword only when the replacement is at least as self-describing as what
it replaces, and never because it sounds better. Block keeps its plain name for
that reason and no other — 방어도 is already the most descriptive thing a number
that absorbs damage can be called.

**Card names carry the flavour**, because they carry no mechanical load: the
rules text sits directly beneath them. `무르게` above `적 하나에게 물러짐 2
부여합니다` is unambiguous and does not read as someone else's game.

**One word for both sides of the exchange.** 힘 sits on the attacker, whoever the
attacker is: on an Askew it presses harder into the vessel, on the Warden it
empties the white gauge faster. Those read as opposite things, and it is still
one word, because a player who has learned what a number does should not have to
learn it again from the other end. The cost is that its wording has to stay
neutral — `status.strength.help` says *every blow it strikes*, not *damage dealt*
and not *time taken*, because the moment it picks a side it is wrong for the
other one. Split a shared stat in two only if the two halves stop behaving the
same, never because they are described differently.

**Rules text may re-describe an effect. It may never restate the number.**
`EffectDamage` carries a `text_key`, so 거두기 reads `적으로부터 6만큼의 시간을
가져옵니다` rather than `6의 피해를 줍니다` — the white gauge is a recovery and not
a wound, and the starting card is where that has to land. The 6 is still the 6,
in the same place, in the same digits. Use the override where the fiction of a
number is genuinely not damage; do not use it to make a line read better.

## Layout

```
source/
  scenes/    .tscn scene files
    main_scene.tscn  the title and the panels over it
    ui/      one scene per view. game_screen.tscn places the run's views as
             instances; card_node.tscn takes a CardData, one enemy_panel.tscn
             per Askew. The overlays (pause, relics, settings, compendium,
             date) inherit overlay_view.tscn. Where a view's contents come
             from data -- the floor in map_view, a room's doors, a
             compendium tab -- the frame is the scene and the contents are
             built in code. Build every view with its create(), not .new()
  scripts/   .gd scripts
    balance.gd     every tunable number, as a Resource
    run/           run_clock.gd, run_state.gd, run_controller.gd, tests
    cards/         card_data.gd, card_upgrade.gd, card_targeting.gd,
                   card_database.gd, effect_context.gd, card_effect.gd,
                   effects/, tests
    battle/        battle_state.gd, stats.gd, battle_piles.gd,
                   status_rules.gd, enemy_intent.gd, battle_effect_context.gd,
                   enemy_behavior.gd, behaviors/, enemy_data.gd, enemy_database.gd,
                   encounter_data.gd, encounter_table.gd
    map/           room.gd, map_generator.gd, map_state.gd
    rewards/       card_reward.gd, shop.gd
    relics/        relic.gd, relic_database.gd, relics/
  data/
    balance.tres   the default tuning profile — edit this, not the code
    cards/         card definitions (.tres) — the pool; see Content data
    cards_shelved/ out of the pool, read by the tests
    cards_fixtures/ test-only cards
    localization/  strings.csv — ko is source, en is the pivot
    enemies/       Askew definitions (.tres)
    encounters/    which Askew share a room
    relics/
    events/
  assets/    art and audio
    theme/   ui_theme.tres — font, boxes, palette, card frames
docs/        design notes
tools/
  retired_generators/  the old tool_write_*.gd, archived; .gdignore'd
```

## Balance

All tunable numbers live in [`source/data/balance.tres`](source/data/balance.tres)
and are read through `Balance`. Nothing else should hold a magic number.

`Balance.validate()` encodes the design rules that are easy to break while
retuning, and the tests assert the shipped profile passes them. Every one of
these is a mistake this project actually made:

- a conversion cap so low it rounds down to nothing, so a fire spends the run's
  time and hands back zero — which silently kills the delivered-versus-kept axis;
- an act promising more guaranteed fights and events than it has rooms to put
  them in;
- `expected_threat_steps` drifting from the number of steps the budget actually
  holds, which is not just a wrong HUD label: the escalation curve divides by it;
- a global `enemy_hp_scale` other than 1.0, which turns every number authored on
  the enemy `.tres` files into a lie.

Add an invariant here whenever a design rule turns out to depend on a number.

## Content data

**The `.tres` files are the source of truth.** Cards, Askew, encounters, events
and relics are authored in `source/data/` and edited in the Godot inspector.
Nothing regenerates them. They used to be written out by `tool_write_*.gd`
scripts, which meant an inspector edit lasted only until the next run of the
tool; those scripts are archived in
[`tools/retired_generators/`](tools/retired_generators/) and Godot does not load
them.

What the generators checked, `validate()` and the tests still check: run the
suite after editing data, not just the game.

Card directories:

- `cards/` — the pool the game loads.
- `cards_shelved/` — taken out of the pool, kept for the tests. Moving a card
  back is moving its file.
- `cards_fixtures/` — not cards; test cases for the machinery, ids `fixture_*`.

## Running

Open the project folder in Godot 4.7 and press F5. The game boots to the title
screen; 내려간다 rolls a seed and starts a run. Runs are still a pure function of
their seed, so tests and the simulator pin one through `RootScreen.begin()` or
`GameScreen.start_run()`.

## Tests

```
godot --headless --editor --quit --path .
godot --headless --path . --script source/scripts/run/test_run_clock.gd
godot --headless --path . --script source/scripts/run/test_run_state.gd
godot --headless --path . --script source/scripts/cards/test_effects.gd
godot --headless --path . --script source/scripts/cards/test_targeting.gd
godot --headless --path . --script source/scripts/cards/test_card_data.gd
godot --headless --path . --script source/scripts/cards/test_card_database.gd
godot --headless --path . --script source/scripts/battle/test_battle.gd
godot --headless --path . --script source/scripts/battle/test_enemy_behaviors.gd
godot --headless --path . --script source/scripts/battle/test_enemy_roster.gd
godot --headless --path . --script source/scripts/battle/test_encounters.gd
godot --headless --path . --script source/scripts/map/test_map.gd
godot --headless --path . --script source/scripts/rewards/test_rewards.gd
godot --headless --path . --script source/scripts/relics/test_relics.gd
godot --headless --path . --script source/scripts/ui/test_ui.gd
godot --headless --path . --script source/scripts/run/test_run_controller.gd
```

The first line is not optional on a clean checkout, and must be re-run after
adding any new `class_name` script: `--script` resolves `class_name` globals from
`.godot/global_script_class_cache.cfg`, and only an editor pass writes that file.
Without it every `class_name` reference fails to parse.

## Simulation

```
godot --headless --path . --script source/scripts/sim/tool_simulate.gd -- 200
```

Plays runs headlessly at four levels of greed — 0.0 walks to the boss door, 1.0
clears the floor — and reports against the targets written down in
[docs/time-system.md](docs/time-system.md). Farm-versus-rush is the design's
central tension, so it is a dial in the simulator rather than an assumption.

The policy in `sim/sim_policy.gd` is deliberately competent rather than clever.
A policy that plays too well hides bad tuning; one that plays badly reports on
itself instead of on the game.

**The first run of this found the design failing its own central test.** See the
findings section of [docs/time-system.md](docs/time-system.md).

## Playing it

```
godot --path .
```

Or open the folder in Godot 4.7 and press F5.

A prototype UI. Exploring puts you in a room with doors out of it; the map is an
overlay you open with **M** or from the top right, at any time, including
mid-fight; **D** shows the deck the same way. It opens centred on the Warden, zooms on the wheel about the pointer,
and pans by dragging empty space. Fights
put the hand along the bottom and enemy intents on show, and rewards, fires,
shops and endings share one screen. No art yet — colours and text only, on the
palette from `source/assets/art/warden_pixel_study.svg`.

**The font is bundled and it is a pixel font.** `source/assets/font/DungGeunMo.ttf`
(둥근모꼴), the default font of the theme, so a build draws Hangul on a machine
that is not this one. The default Godot font has no Hangul at all, so without a
bundled face every string in the game is a row of boxes.

**The look is a resource.** [`source/assets/theme/ui_theme.tres`](source/assets/theme/ui_theme.tres)
holds the font, the button and panel boxes, and the palette (under the `Palette`
type), and is edited in the inspector. `UiTheme` only reads it: `UiTheme.GOLD`
and the rest are that palette, read once at load. The theme's own boxes hold
their colours as literals, so retuning a palette colour does not retint them —
change both.

**The view layer holds no display strings.** Every word the UI draws is a key in
strings.csv, which is what makes the language setting real rather than
half-working. It was not always so: 112 Korean literals lived in the view files,
and a locale switch would have translated card and enemy names while leaving
every button around them in Korean. The one deliberate exception is the language
picker itself, whose options read 한국어 and English in their own language --
someone who cannot read the current setting has to be able to find the way out.

Being a pixel font has one consequence that reaches the whole UI. 둥근모꼴 is a
16-pixel bitmap face in a TrueType wrapper: it is sharp at 16, 32 and 48 and
mush at every size in between, because at 20px the renderer has to invent four
rows of pixels nobody drew. So `UiTheme.size_for()` snaps every requested size to
that grid, and the thirteen sizes the UI used to ask for now resolve to two.
Ask for the size the layout wants and let the snap happen; it is one function to
delete if an outline face ever replaces this one.

Antialiasing, hinting and subpixel positioning are all switched off for the same
reason — they exist to make a curve look smooth at a size it was not drawn for,
and on glyphs that are already exactly the right pixels they only blur edges that
were correct. They are set on the font's import (`DungGeunMo.ttf.import`), so
the editor draws it the way the game does; `test_ui` fails if they come back.

**Licence: public domain.** 둥근모꼴 is released into the public domain, as are the
faces it derives from (둥근모꼴 and Fixedsys Excelsior). Redistribution,
modification and commercial use are all clear -- nothing to track here.

## Saving

One slot, `user://run.save`, written as JSON by
[`SaveGame`](source/scripts/run/save_game.gd). Two decisions in it are worth
keeping.

**The fight in progress is in the file, as it stood when the fight began.**
Combatants, statuses, enemy behaviour state, the pile *order* and the battle
rng's `state` all go out, so a resumed fight is the same fight from the top.

A resume does not drop the player into the middle of a turn with cards already
spent and a budget already half gone. It restarts the whole fight. The cost is
large and worth naming: quitting mid-fight undoes every turn of it, and because
the rng state is the one the fight opened with, the replay is identical -- so a
player who quits a losing fight refights it already knowing what the enemy does.
That is a bigger concession than the turn-level restart it replaced, and it was
asked for deliberately.

The snapshot is taken in `RunController._snapshot_fight()` and returned by
`save_state()`. Everything it holds has to be *copied*: `Array(x)` on something
that is already an Array hands back the same object, and a snapshot that shares
its arrays with the live game is not a snapshot. That was the first version of
this and the test caught it.

The autosave is on `GameScreen.refresh()` rather than on chosen checkpoints, so
outside a fight there is no gap between a decision and the save to quit into.

**It is JSON, not a `Resource`.** `ResourceLoader` on a user-writable file will
instantiate whatever script the file names, which turns a save into an execution
vector as soon as one is shared or edited. The worst a corrupted JSON save can do
is fail to parse — and a save that will not parse, or that carries a version this
build does not know, is ignored rather than raised, because to the player all
three cases are the same thing: no run to continue.

**Tests write to their own files.** `SaveGame.path` and `Settings.path` are vars
rather than consts so each suite can point them at a scratch name and delete it
on the way out. They were consts, and running the suite therefore deleted
whatever run the player had in progress and overwrote the window size they had
chosen — a memorable way to lose the thing the tests exist to protect. Anything
added here that writes to `user://` should get the same treatment.

**The UI keys are checked, not trusted.** `test_ui` reads every `ui.*` row out of
strings.csv and resolves it in both languages; a key that translates to itself is
a missing cell, and what the player would see is the key printed on a button.
That check is what makes adding a string a two-file job rather than a two-file
job someone forgets half of.

**The canvas is not scaled to a base resolution.** `window/stretch/mode` is
`disabled`, which is unusual and is forced by the font. The default
`canvas_items` stretch draws the UI at 1920x1080 and scales it to the window, so
a 1280x720 window means a 0.67x canvas — and 0.67x of a 16-pixel bitmap face is
the renderer being asked to delete two pixel rows out of every three. The text
went illegible before it went small.

With stretch off, a smaller window means *less room*, not smaller text. That only
works if the layout reflows, so anything measured in cards counts how many fit
rather than assuming: `CompendiumView._columns_for()` is that count, shared with
the card reader. The test drives the smallest offered window and checks the grid
still fits inside it.

The cost is that a 4K screen gets a physically small UI. The fix for that is an
integer UI scale in Settings — 1x/2x, nothing between — and it is not built yet.

One consequence for the tests: a headless run has a 64x64 viewport with stretch
disabled, where before it inherited the 1920x1080 base. `test_ui` sets
`root.size` itself now. Any new test that measures a layout needs a screen to
measure against.

## Shortcuts

Bindings, not literals. `Keybinds` owns four actions — end turn, map, deck,
pause — with Space / M / D / Escape as defaults, persisted to
`user://keys.cfg` and rebindable in Settings under the 단축키 tab.

Taking a key that another action already holds **swaps** the two rather than
leaving one unbound: a rebinding screen that can silently strip an action of its
key is one a player can walk out of with no way to end a turn.

Escape is never captured while rebinding, and `OverlayView` handles it directly
rather than through a binding, so no arrangement of keys can leave a player
unable to close a panel.

Keys are not printed on the buttons. A label that says `지도 (M)` is a lie the
moment the binding changes, and the place to look up a shortcut is the screen
that sets it.

## Events

`Room.Kind.EVENT` was a label with nothing behind it — the map never placed one
and the controller had no branch for it. Both are filled in now, drawn from
`source/data/events/` and never repeated inside a run.

**Fights and events come out of one pool of rooms.** An act holds
`fights_and_events_per_act` content rooms; the fights are rolled inside that
count and the events are whatever is left, with `events_min_per_act` as the
floor. So a floor heavy with events is a floor light on fights, which is a
difference the player can feel before knowing why.

An event is `EventData` — title, body, and two or more `EventChoice`. A choice
holds `EventOutcome` resources, which are the run-level counterpart to
`CardEffect`: spend time, gain or lose health, gain or lose Restored, add a card,
recover a memory. Adding a sixth kind of outcome is one new class, the same rule
the cards and relics follow.

Two rules the linter enforces:

- **Every event offers a way to walk away**, and walking away costs nothing
  extra — because the hour spent reaching the room is already gone. Declining is
  a real choice in a game where unspent time is lost, not a wasted screen.
- **At least one choice has to do something.** An event where every option is
  free is a message, not an event.

The act-one events follow the curriculum in
[docs/narrative.md](docs/narrative.md): sensation and ordinary life, nothing at
stake, nothing explained. The Warden's early voice is measurements — eleven
hours, sixteen glances, food for nine — and no adjectives about anyone.
