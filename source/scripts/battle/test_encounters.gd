extends SceneTree


var _failures := 0
var _b: Balance
var _enemies: EnemyDatabase
var _table: EncounterTable


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


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_table = fresh_table()

	print("\n-- the table loads and passes its own linter --")
	check("problems", _table.validate(_enemies), PackedStringArray())
	check("a real table", _table.size() >= 12, true)
	check("elites are stocked", _table.candidates(1, EnemyData.Tier.ELITE).size() >= 2, true)
	check("and so is the boss", _table.candidates(1, EnemyData.Tier.BOSS).size() >= 1, true)

	print("\n-- the first fight comes from its own pool --")
	var opener := _table.pick(rng(1), 1, EnemyData.Tier.NORMAL, true)
	check("an opener exists", opener != null, true)
	check("it is the teaching one", opener.id, &"a1_opening_lone_afterimage")
	check("one enemy only", opener.members.size(), 1)
	var general_ids := _table.candidates(1, EnemyData.Tier.NORMAL).map(
		func(e: EncounterData) -> String: return String(e.id))
	check("opener is not in the general pool", general_ids.has("a1_opening_lone_afterimage"), false)
	check("plenty of general encounters", general_ids.size() >= 10, true)

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
	check("no back-to-back repeats", repeats, 0)
	check("but the pool is still varied", Array(seq_a).size() > 0 and seq_a.count(seq_a[0]) < seq_a.size(), true)

	print("\n-- weights are respected --")
	var counts := {}
	var t := fresh_table()
	var r := rng(9)
	for i in 400:
		var id := String(t.pick(r, 1, EnemyData.Tier.NORMAL).id)
		counts[id] = int(counts.get(id, 0)) + 1
	check("everything in the pool turns up", counts.size(),
		_table.candidates(1, EnemyData.Tier.NORMAL).size())
	check("the common one beats the rare one",
		int(counts["a1_afterimage_pair"]) > int(counts["a1_crumbling_afterimage"]), true)

	print("\n-- an empty pool says so instead of guessing --")
	check("elites now exist", _table.pick(rng(1), 1, EnemyData.Tier.ELITE) != null, true)
	check("no act 2 yet", _table.pick(rng(1), 2, EnemyData.Tier.NORMAL), null)

	print("\n-- spawning builds what the encounter says --")
	var pair := _table.get_encounter(&"a1_afterimage_pacing")
	var group := _table.spawn(pair, _enemies, _b, rng(3))
	check("two of them", group.size(), 2)
	check("in the authored order", [group[0].name_key, group[1].name_key],
		[&"enemy.afterimage.name", &"enemy.pacing.name"])
	check("no threat scaling at level 0", group[0].outgoing_multiplier, _b.enemy_damage_scale)

	print("\n-- Threat makes them worse, in one place --")
	var base := _table.spawn(_table.get_encounter(&"a1_lone_pacing"), _enemies, _b, rng(11), 0)
	var late := _table.spawn(_table.get_encounter(&"a1_lone_pacing"), _enemies, _b, rng(11), 5)
	check("tougher", late[0].max_hp > base[0].max_hp, true)
	check("hits harder", late[0].outgoing_multiplier > base[0].outgoing_multiplier, true)
	check("hp scaled by the balance value", late[0].max_hp,
		roundi(base[0].max_hp * _b.threat_hp_multiplier(5)))
	check("worth more time too", late[0].restored_value,
		late[0].max_hp * _b.restored_minutes_per_hp)

	print("\n-- the definition is never touched by scaling --")
	check("act-one hp range intact", _enemies.get_enemy(&"pacing").hp_min, 26)
	check("intents intact", _enemies.get_enemy(&"pacing").intents.size(), 3)

	print("\n-- a scaled enemy actually hits harder in a fight --")
	var cards := CardDatabase.new()
	cards.load_from()
	var hits := []
	for level in [0, 10]:
		var run := RunState.new(_b, 1)
		for i in 8:
			run.add_card(&"interrupt")
		var group2 := _table.spawn(_table.get_encounter(&"a1_lone_pacing"), _enemies, _b, rng(2), level)
		var bt := BattleState.new(run, cards, group2, rng(2))
		bt.end_turn()
		hits.append(_b.starting_max_hp - bt.warden().hp)
	check("threat 10 hurts more than threat 0", hits[1] > hits[0], true)
	check("scaled by the balance values", hits[1], roundi(6 * _b.enemy_damage_scale
		* _b.threat_damage_multiplier(10)))

	print("\n-- link_pairs binds twins for 겹침 --")
	var overlaid := EncounterData.new()
	overlaid.id = &"test_pair"
	overlaid.members.assign([&"afterimage", &"afterimage"])
	overlaid.link_pairs = true
	var twins := _table.spawn(overlaid, _enemies, _b, rng(1))
	check("first points at second", twins[0].link, 2)
	check("second points at first", twins[1].link, 1)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
