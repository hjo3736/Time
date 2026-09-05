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
) -> EncounterData:
	var e := EncounterData.new()
	e.id = id
	e.act = 1
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
		names.append(tr(enemies.get_enemy(m).name_key))
	print("  %s  w%-3d %s%s" % [
		"ok  " if err == OK else "FAIL", e.weight, " + ".join(names),
		"   (첫 전투 전용)" if e.opening_only else ("   (연결됨)" if e.link_pairs else ""),
	])


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var enemies := EnemyDatabase.new()
	enemies.load_from()
	print("writing encounters to %s\n" % OUT_DIR)

	print("첫 전투")
	write(encounter(&"a1_opening_lone_afterimage", 10, [&"afterimage"],
		EnemyData.Tier.NORMAL, true), enemies)

	print("\n일반 — 배운 것들")
	write(encounter(&"a1_afterimage_pair", 10, [&"afterimage", &"afterimage"]), enemies)
	write(encounter(&"a1_lone_pacing", 8, [&"pacing"]), enemies)
	write(encounter(&"a1_afterimage_pacing", 8, [&"afterimage", &"pacing"]), enemies)

	print("\n일반 — 처음 만나는 분류 (단독)")
	write(encounter(&"a1_lone_crumbling", 7, [&"crumbling"]), enemies)
	write(encounter(&"a1_lone_echo", 7, [&"echo"]), enemies)
	write(encounter(&"a1_lone_late_one", 6, [&"late_one"]), enemies)
	write(encounter(&"a1_lone_stood_still", 6, [&"stood_still"]), enemies)
	write(encounter(&"a1_footsteps_pair", 6, [&"footsteps", &"footsteps"],
		EnemyData.Tier.NORMAL, false, true), enemies)

	print("\n일반 — 섞인 것들")
	write(encounter(&"a1_pacing_echo", 5, [&"pacing", &"echo"]), enemies)
	write(encounter(&"a1_afterimage_late_one", 5, [&"afterimage", &"late_one"]), enemies)
	write(encounter(&"a1_crumbling_afterimage", 4, [&"crumbling", &"afterimage"]), enemies)

	print("\n엘리트")
	write(encounter(&"a1_elite_long_standing", 10, [&"long_standing"],
		EnemyData.Tier.ELITE), enemies)
	write(encounter(&"a1_elite_repeating_door", 10, [&"repeating_door"],
		EnemyData.Tier.ELITE), enemies)

	print("\n보스")
	write(encounter(&"a1_boss_first_crack", 10, [&"first_crack"],
		EnemyData.Tier.BOSS), enemies)

	print("\n%d encounters" % _written)
	quit(0)
