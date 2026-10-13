extends SceneTree


const OUT_DIR := "res://source/data/encounters"

var _written := 0


func encounter(
	id: StringName,
	weight: int,
	members: Array,
	tier: EnemyData.Tier = EnemyData.Tier.NORMAL,
	opening: bool = false,
	link_pairs: bool = false,
	act: int = 1,
) -> EncounterData:
	var e := EncounterData.new()
	e.id = id
	e.act = act
	e.tier = tier
	e.weight = weight
	e.members.assign(members)
	e.opening_only = opening
	e.link_pairs = link_pairs
	return e


func write(e: EncounterData, enemies: EnemyDatabase) -> void:
	var problems := e.validate(enemies)
	if not problems.is_empty():
		print("  LINT  %s: %s" % [e.id, problems])
	var err := ResourceSaver.save(e, "%s/%s.tres" % [OUT_DIR, e.id])
	if err == OK:
		_written += 1
	var names := PackedStringArray()
	for m in e.members:
		var data := enemies.get_enemy(m)
		names.append(tr(data.name_key) if data != null else "<%s?>" % m)
	print("  %s  a%d w%-3d %s%s" % [
		"ok  " if err == OK else "FAIL", e.act, e.weight, " + ".join(names),
		"   (첫 전투 전용)" if e.opening_only else ("   (연결됨)" if e.link_pairs else ""),
	])


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var enemies := EnemyDatabase.new()
	enemies.load_from()
	print("writing encounters to %s\n" % OUT_DIR)

	# Emptied along with the bestiary. Encounters name enemies, so there is
	# nothing to write until there are enemies to name. Acts are a parameter now
	# rather than hardcoded to 1 — see the act ladder in docs/setting.md.
	_act_one(enemies)
	_act_two(enemies)
	_act_three(enemies)

	print("\n%d encounters" % _written)
	quit(0)


func _act_one(enemies: EnemyDatabase) -> void:
	print("1막 — 첫 전투")
	write(encounter(&"a1_opening_lone_squabble", 10, [&"squabble"],
		EnemyData.Tier.NORMAL, true), enemies)

	print("1막 — 일반")
	write(encounter(&"a1_lone_squabble", 10, [&"squabble"]), enemies)
	write(encounter(&"a1_lone_doorsill", 10, [&"doorsill"]), enemies)
	write(encounter(&"a1_lone_swallowed_word", 10, [&"swallowed_word"]), enemies)
	write(encounter(&"a1_lone_tossing", 10, [&"tossing"]), enemies)
	write(encounter(&"a1_lone_draught", 10, [&"draught"]), enemies)

	print("1막 — 무리")
	write(encounter(&"a1_group_day", 10,
		[&"breakfast", &"nap", &"sundown", &"supper"]), enemies)
	write(encounter(&"a1_group_hourglass", 10, [&"hourglass_upper", &"hourglass_lower"],
		EnemyData.Tier.NORMAL, false, true), enemies)
	write(encounter(&"a1_group_relay", 10, [&"runner", &"runner", &"runner"]), enemies)
	write(encounter(&"a1_group_chorus", 10,
		[&"chorister", &"chorister", &"chorister"]), enemies)
	write(encounter(&"a1_group_domino", 10,
		[&"domino", &"domino", &"domino", &"domino"]), enemies)
	write(encounter(&"a1_group_shelter", 10, [&"shelter_front", &"shelter_behind"],
		EnemyData.Tier.NORMAL, false, true), enemies)

	print("1막 — 정예")
	write(encounter(&"a1_elite_murphys_law", 10, [&"murphys_law"],
		EnemyData.Tier.ELITE), enemies)
	write(encounter(&"a1_elite_throng", 10, [&"throng"],
		EnemyData.Tier.ELITE), enemies)
	write(encounter(&"a1_elite_wall_clock", 10,
		[&"second_hand", &"minute_hand", &"hour_hand"], EnemyData.Tier.ELITE), enemies)
	write(encounter(&"a1_elite_seesaw", 10, [&"seesaw_near", &"seesaw_far"],
		EnemyData.Tier.ELITE, false, true), enemies)
	write(encounter(&"a1_elite_prop", 10, [&"prop"],
		EnemyData.Tier.ELITE), enemies)

	print("1막 — 보스")
	write(encounter(&"a1_boss_echo", 10, [&"echo"], EnemyData.Tier.BOSS), enemies)
	write(encounter(&"a1_boss_sun_dragger", 10, [&"sun_dragger"],
		EnemyData.Tier.BOSS), enemies)


func _act_two(_enemies: EnemyDatabase) -> void:
	pass


func _act_three(_enemies: EnemyDatabase) -> void:
	pass
