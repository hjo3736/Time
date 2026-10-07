extends SceneTree


const OUT_DIR := "res://source/data/enemies"

const MORNING := RunClock.Daytime.MORNING
const DAY := RunClock.Daytime.DAY
const EVENING := RunClock.Daytime.EVENING
const NIGHT := RunClock.Daytime.NIGHT

var _written := 0


func attack(amount: int, times: int = 1) -> EnemyIntent:
	return EnemyIntent.attack(amount, times)


func block(amount: int) -> EnemyIntent:
	return EnemyIntent.block(amount)


func wait() -> EnemyIntent:
	return EnemyIntent.wait()


func inflict(status: StringName, stacks: int) -> EnemyIntent:
	return EnemyIntent.inflict(status, stacks)


func window(intent: EnemyIntent) -> EnemyIntent:
	intent.is_break_window = true
	return intent


func enemy(
	id: StringName,
	hp_min: int,
	hp_max: int,
	intents: Array[EnemyIntent],
	behavior: Script = null,
	tier: EnemyData.Tier = EnemyData.Tier.NORMAL,
	by_sky: Dictionary = {},
	act: int = 1,
) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.name_key = StringName("enemy.%s.name" % id)
	e.tier = tier
	e.act = act
	e.hp_min = hp_min
	e.hp_max = hp_max
	e.intents = intents
	e.behavior_script = behavior
	for sky in by_sky:
		var written: Array[EnemyIntent] = []
		written.assign(by_sky[sky])
		match sky:
			MORNING:
				e.morning_intents = written
			DAY:
				e.day_intents = written
			EVENING:
				e.evening_intents = written
			NIGHT:
				e.night_intents = written
	return e


func write(e: EnemyData) -> void:
	var problems := e.validate()
	if not problems.is_empty():
		print("  LINT  %s: %s" % [e.id, problems])
	var err := ResourceSaver.save(e, "%s/%s.tres" % [OUT_DIR, e.id])
	if err == OK:
		_written += 1
	print("  %s  %-16s hp %3d-%-3d  %s" % [
		"ok  " if err == OK else "FAIL", tr(e.name_key), e.hp_min, e.hp_max,
		_cycle(e.intents)])
	for pair in [["아침", e.morning_intents], ["낮", e.day_intents],
			["저녁", e.evening_intents], ["밤", e.night_intents]]:
		var list: Array = pair[1]
		if not list.is_empty():
			print("        %-4s %s" % [pair[0], _cycle(list)])


func _cycle(intents: Array) -> String:
	var out := PackedStringArray()
	for i in intents:
		var text := ""
		match i.kind:
			EnemyIntent.Kind.ATTACK:
				text = "공격 %d%s" % [i.amount, "" if i.times <= 1 else " x%d" % i.times]
			EnemyIntent.Kind.BLOCK:
				text = "방어 %d" % i.amount
			EnemyIntent.Kind.STATUS:
				text = "%s %d" % [i.status, i.stacks]
			EnemyIntent.Kind.WAIT:
				text = "대기"
		out.append(("[%s]" % text) if i.is_break_window else text)
	return " → ".join(out)


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("writing enemies to %s\n" % OUT_DIR)

	# The bestiary is being rebuilt from nothing. The two vocabularies are
	# deliberately separate: a normal's gimmick is read off its intent line and
	# needs no tell, while an elite's changes a rule of the exchange and carries
	# one. If a normal needs explaining, it belongs a tier up.
	_act_one()
	_act_two()
	_act_three()

	print("\n%d enemies  ([ ] = 브레이크 윈도우)" % _written)
	quit(0)


func _act_one() -> void:
	print("1막 — 일반")

	write(enemy(&"squabble", 22, 25,
		[attack(6), attack(9), block(7)] as Array[EnemyIntent]))

	write(enemy(&"doorsill", 32, 35,
		[attack(5)] as Array[EnemyIntent], BehaviorTwilit))

	print("\n1막 — 정예")

	# 가속. Deliberately a wall rather than a killer: it guards itself, so the
	# fight runs long, and running long is the whole cost. The player is not being
	# asked whether they can survive it but whether they can afford it.
	write(enemy(&"murphys_law", 78, 86,
		[block(12), attack(10), block(12), attack(14)] as Array[EnemyIntent],
		BehaviorQuickening, EnemyData.Tier.ELITE))

	# 흘림. The opposite question to 가속: that one cannot be blocked out of, this
	# one has to be. Mostly many small blows, because every one that gets past the
	# guard is another hour gone, so a point of block short is an hour short.
	write(enemy(&"throng", 60, 66,
		[attack(4, 3), block(10), attack(7, 2), attack(12)] as Array[EnemyIntent],
		BehaviorSpilling, EnemyData.Tier.ELITE))


func _act_two() -> void:
	pass


func _act_three() -> void:
	pass
