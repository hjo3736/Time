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
) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.name_key = StringName("enemy.%s.name" % id)
	e.tier = tier
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

	_teaching()
	_askew()
	_elites()
	_boss()

	print("\n%d enemies  ([ ] = 되풀이의 브레이크 윈도우)" % _written)
	quit(0)


func _teaching() -> void:
	print("일반 — 기본")

	write(enemy(&"afterimage", 20, 24,
		[attack(5), attack(5), attack(9)] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{
			MORNING: [attack(3)],
			EVENING: [block(6)],
			NIGHT: [attack(3), attack(3), attack(3), attack(12)],
		}))

	write(enemy(&"pacing", 26, 32,
		[attack(6), block(8), attack(6)] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{
			MORNING: [wait()],
			EVENING: [attack(9)],
			NIGHT: [block(12), attack(11)],
		}))


func _askew() -> void:
	print("\n일반 — 어긋난 것들")

	write(enemy(&"crumbling", 30, 36,
		[attack(14)] as Array[EnemyIntent], BehaviorWithered))

	write(enemy(&"echo", 16, 20,
		[attack(6), window(attack(4))] as Array[EnemyIntent], BehaviorLooper))

	write(enemy(&"late_one", 14, 18,
		[attack(7), block(4)] as Array[EnemyIntent], BehaviorReversed))

	write(enemy(&"stood_still", 28, 34,
		[wait(), attack(11), wait(), attack(11)] as Array[EnemyIntent], BehaviorStilled))

	write(enemy(&"footsteps", 18, 22,
		[attack(4), attack(4), inflict(StatusRules.BLUNTED, 1)] as Array[EnemyIntent],
		BehaviorOverlaid))


func _elites() -> void:
	print("\n엘리트")

	write(enemy(&"long_standing", 58, 66,
		[wait(), wait(), attack(18), block(10)] as Array[EnemyIntent],
		BehaviorStilled, EnemyData.Tier.ELITE))

	write(enemy(&"repeating_door", 34, 40,
		[attack(12), window(attack(6)), window(attack(6))] as Array[EnemyIntent],
		BehaviorLooper, EnemyData.Tier.ELITE))


func _boss() -> void:
	print("\n보스")

	write(enemy(&"first_crack", 106, 118,
		[attack(10), wait(), inflict(StatusRules.SOFTENED, 2), attack(14), wait(), attack(20)]
			as Array[EnemyIntent],
		BehaviorStilled, EnemyData.Tier.BOSS))
