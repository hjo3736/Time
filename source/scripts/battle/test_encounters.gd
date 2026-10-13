extends SceneTree


var _failures := 0
var _b: Balance
var _enemies: EnemyDatabase
var _table: EncounterTable


## What the table holds today, while the bestiary is being rebuilt. Editing this
## is the deliberate act that comes with adding an encounter.
##
## Targets for the finished game: an opening encounter per act, elites >= 2,
## a boss per act, and enough normals that a floor does not repeat itself.
const HELD_NOW := {"all": 19, "normal": 11, "elite": 5, "boss": 2, "opening": 1}

## Complaints the linter is expected to make while the bestiary is unfinished.
## Act one has its teaching fight now, so there are none left.
static func known_gaps() -> PackedStringArray:
	return PackedStringArray([])


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func fresh_table() -> EncounterTable:
	var t := EncounterTable.new()
	t.load_from()
	return t


## Any encounter of a tier, so the machinery checks below do not have to name one.
func some(tier: EnemyData.Tier, act: int = 1) -> EncounterData:
	var pool := _table.candidates(act, tier)
	return pool[0] if not pool.is_empty() else null


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_table = fresh_table()

	print("\n-- the table loads, and the linter reports only what is known missing --")
	check("problems", _table.validate(_enemies), known_gaps())
	var ids := _table.candidates(1, EnemyData.Tier.NORMAL).map(
		func(e: EncounterData) -> String: return String(e.id))
	check("sorted by id", ids, ids.duplicate())

	print("\n-- what the table holds while it is being rebuilt --")
	check("encounters", _table.size(), HELD_NOW["all"])
	check("normals", _table.candidates(1, EnemyData.Tier.NORMAL).size(), HELD_NOW["normal"])
	check("elites", _table.candidates(1, EnemyData.Tier.ELITE).size(), HELD_NOW["elite"])
	check("bosses", _table.candidates(1, EnemyData.Tier.BOSS).size(), HELD_NOW["boss"])
	check("openers", _table.candidates(1, EnemyData.Tier.NORMAL, true).size(),
		HELD_NOW["opening"])

	print("\n-- an encounter may not mix acts --")
	var mixed := EncounterData.new()
	mixed.id = &"test_mixed"
	mixed.act = 2
	mixed.members.assign([_enemies.of_act(1)[0].id])
	var complaint := mixed.validate(_enemies)
	check("the linter catches a later act fielding act one's Askew",
		complaint.size() > 0, true)
	check("and says which", String(complaint[0]).contains("act 1"), true)

	print("\n-- acts with nothing of their own borrow act one's, and say so --")
	check("acts two and three are still unwritten",
		_table.borrowed_acts(_b.acts_per_run), [2, 3])
	check("so a later act still fields normals",
		_table.candidates(3, EnemyData.Tier.NORMAL).is_empty(), false)
	check("and an elite, which is what puts elites on a later floor",
		_table.candidates(3, EnemyData.Tier.ELITE).is_empty(), false)
	check("act one borrows from nobody",
		_table.borrowed_acts(_b.acts_per_run).has(1), false)
	var lent := _table.pick(rng(1), 2, EnemyData.Tier.NORMAL)
	check("act 2 fights something", lent != null, true)
	check("and what it fields is act one's", lent.act, 1)
	check("but a combination act one never authored is still null",
		_table.pick(rng(1), 2, EnemyData.Tier.BOSS, true), null)

	print("\n-- a room with company fields its own enemy and enough of the rest --")
	var mix_lone := _table.get_encounter(&"a1_lone_squabble")
	var mix_company: Array[StringName] = [&"squabble", &"doorsill", &"draught"]
	var mix_pair := _table.mixed(mix_lone, mix_company, 2)
	check("two stand in it", mix_pair.members.size(), 2)
	check("the room's own enemy first", mix_pair.members[0], &"squabble")
	check("and the first of its company that is not the same one", mix_pair.members[1], &"doorsill")
	check("the authored encounter was not touched", mix_lone.members.size(), 1)
	check("and the mix is not in the table", _table.size(), HELD_NOW["all"])
	var mix_none: Array[StringName] = []
	check("with no company it is the encounter as written", _table.mixed(mix_lone, mix_none, 2), mix_lone)
	var mix_group := EncounterData.new()
	mix_group.id = &"test_group"
	mix_group.members.assign([&"squabble", &"squabble"])
	check("and a group is never added to", _table.mixed(mix_group, mix_company, 3), mix_group)
	check("spawned, it is two combatants",
		_table.spawn(mix_pair, _enemies, _b, rng(4)).size(), 2)

	# A mixed fight's gauges are cut by the profile's figure; an authored one's
	# are not. Same seed both times, so the only difference is the scale.
	var cut := _table.mixed(mix_lone, mix_company, 2, 0.5)
	var whole_hp := _table.spawn(mix_pair, _enemies, _b, rng(4)).map(
		func(c: Combatant) -> int: return c.max_hp)
	var cut_hp := _table.spawn(cut, _enemies, _b, rng(4)).map(
		func(c: Combatant) -> int: return c.max_hp)
	check("a mixed fight can be given smaller gauges",
		cut_hp, whole_hp.map(func(hp: int) -> int: return roundi(hp * 0.5)))
	check("and what they are worth shrinks with them",
		_table.spawn(cut, _enemies, _b, rng(4))[0].restored_value,
		roundi(cut_hp[0] * _b.restored_minutes_per_hp))
	check("an authored encounter is never scaled", mix_lone.hp_scale, 1.0)
	check("the profile's figure is a cut, not a boost", _b.mixed_fight_hp_scale <= 1.0, true)

	var mix_drawn := _table.draw_companions(rng(9), 1, 3)
	check("company is drawn all different", mix_drawn.size(), 3)
	var mix_unique := {}
	for id in mix_drawn:
		mix_unique[id] = true
	check("so three drawn are three kinds", mix_unique.size(), 3)
	check("and the draw replays", _table.draw_companions(rng(9), 1, 3), mix_drawn)
	check("it cannot draw more kinds than stand alone",
		_table.draw_companions(rng(9), 1, 99).size(), _table.mixable(1).size())
	check("a room that must be alone is given one enemy",
		_table.pick(rng(2), 1, EnemyData.Tier.NORMAL, false, -1, true).members.size(), 1)

	print("\n-- picking is seeded and replays --")
	var a := fresh_table()
	var b := fresh_table()
	var ra := rng(4242)
	var rb := rng(4242)
	var seq_a := []
	var seq_b := []
	for i in 10:
		seq_a.append(String(a.pick(ra, 1, EnemyData.Tier.NORMAL).id))
		seq_b.append(String(b.pick(rb, 1, EnemyData.Tier.NORMAL).id))
	check("identical sequences", seq_a, seq_b)

	print("\n-- history keeps the same fight from coming twice in a row --")
	var repeats := 0
	for i in range(1, seq_a.size()):
		if seq_a[i] == seq_a[i - 1]:
			repeats += 1
	# The history can only hold a repeat off while there is something else to
	# offer. With a pool no larger than the history, pick() falls back to the whole
	# table on purpose rather than returning nothing, so repeats are correct here.
	var pool_size := _table.candidates(1, EnemyData.Tier.NORMAL).size()
	if pool_size > _b.encounter_history_length:
		check("no back-to-back repeats", repeats, 0)
	else:
		check("the pool is too small for history to bite, and it says so",
			pool_size <= _b.encounter_history_length, true)

	print("\n-- every encounter in the pool turns up --")
	var counts := {}
	var t := fresh_table()
	var r := rng(9)
	for i in 400:
		var id := String(t.pick(r, 1, EnemyData.Tier.NORMAL).id)
		counts[id] = int(counts.get(id, 0)) + 1
	check("all of them", counts.size(), _table.candidates(1, EnemyData.Tier.NORMAL).size())

	print("\n-- spawning builds what the encounter says --")
	var one := some(EnemyData.Tier.NORMAL)
	check("there is something to spawn", one != null, true)
	var group := _table.spawn(one, _enemies, _b, rng(3))
	check("one combatant per member", group.size(), one.members.size())
	var spawned_keys := group.map(func(c: Combatant) -> StringName: return c.name_key)
	var authored_keys := one.members.map(
		func(m: StringName) -> StringName: return _enemies.get_enemy(m).name_key)
	check("in the authored order", spawned_keys, authored_keys)
	check("no threat scaling at level 0", group[0].outgoing_multiplier, _b.enemy_damage_scale)

	print("\n-- Threat makes them worse, in one place, and late rather than early --")
	var base := _table.spawn(one, _enemies, _b, rng(11), 0)
	var early := _table.spawn(one, _enemies, _b, rng(11), 5)
	var last := _table.spawn(one, _enemies, _b, rng(11), _b.expected_threat_steps)
	# The curve is back-loaded by design, so a fifth of the way in it has barely
	# moved. Asserting growth at an early step would be asserting a linear ramp.
	check("five steps in, a small Askew is close to what was authored",
		early[0].max_hp, roundi(base[0].max_hp * _b.threat_hp_multiplier(5)))
	check("by the last step it is far from it", last[0].max_hp > base[0].max_hp, true)
	check("about twice, which is the total the curve is given",
		last[0].max_hp, roundi(base[0].max_hp * _b.threat_hp_multiplier(_b.expected_threat_steps)))
	check("and it hits harder on the way",
		last[0].outgoing_multiplier > early[0].outgoing_multiplier, true)
	check("worth more time too", last[0].restored_value,
		last[0].max_hp * _b.restored_minutes_per_hp)

	print("\n-- the definition is never touched by scaling --")
	var named: StringName = one.members[0]
	var authored := _enemies.get_enemy(named)
	var hp_before := authored.hp_min
	var intents_before := authored.intents.size()
	_table.spawn(one, _enemies, _b, rng(11), 20)
	check("hp range intact", _enemies.get_enemy(named).hp_min, hp_before)
	check("intents intact", _enemies.get_enemy(named).intents.size(), intents_before)

	print("\n-- a scaled enemy actually hits harder in a fight --")
	var cards := CardDatabase.new()
	cards.load_from()
	var hits := []
	for level in [0, 10]:
		var run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
		for i in 8:
			run.add_card(&"take")
		# Named rather than taken from the top of the table: the blow has to be large
		# enough for a tenth more of it to round up, and a 4 is not.
		var group2 := _table.spawn(_table.get_encounter(&"a1_lone_squabble"), _enemies, _b, rng(2), level)
		var bt := BattleState.new(run, cards, group2, rng(2))
		bt.end_turn()
		hits.append(_b.starting_max_hp - bt.warden().hp)
	check("threat 10 hurts more than threat 0", hits[1] > hits[0], true)

	print("\n-- link_pairs binds twins for 겹침 --")
	var overlaid := EncounterData.new()
	overlaid.id = &"test_pair"
	overlaid.members.assign([named, named])
	overlaid.link_pairs = true
	var twins := _table.spawn(overlaid, _enemies, _b, rng(1))
	check("first points at second", twins[0].link, 2)
	check("second points at first", twins[1].link, 1)
	check("and the linter wants an even number",
		EncounterData.new().validate(_enemies).size() > 0, true)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
