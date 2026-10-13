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


func grow(stacks: int) -> EnemyIntent:
	return EnemyIntent.grow(stacks)


func drag(grip: int) -> EnemyIntent:
	return EnemyIntent.drag(grip)


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
			EnemyIntent.Kind.GROW:
				text = "성장 %d" % i.stacks
			EnemyIntent.Kind.DRAG:
				text = "해를 끈다 %d" % i.amount
			EnemyIntent.Kind.BEAR:
				text = "자신에게 %s %d" % [i.status, i.stacks]
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

	# Holds it in for two turns and then says all of it. No behaviour: the holding
	# is on the intent line, and so is what follows it. It guards while it holds,
	# because a thing that only waited was gone before it ever spoke — the guard
	# is what gets it to the third turn. Its first turn is still bare: the guard
	# goes up as that turn ends.
	write(enemy(&"swallowed_word", 32, 35,
		[block(8), block(8), attack(15)] as Array[EnemyIntent]))

	# Only there from the evening on. Through the morning and the day it has no
	# intent at all, so the same room is a free gauge at noon and a fight at
	# midnight, and three hours a turn means a fight begun late in the day does not
	# stay there. The evening is one turn long, so it gets one intent: a light
	# blow that says what the room is about to become, a turn before it does.
	write(enemy(&"tossing", 28, 31,
		[wait()] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{
			EVENING: [attack(4)],
			NIGHT: [attack(7), attack(4, 2), block(6)],
		}))

	# The first thing in the game that does something to the Warden other than hit
	# it. 물러짐 2 is one stack by the time the next blow arrives, so the 8 lands
	# as 12 and the 6 after it lands as 6: one turn of the three is the one to
	# block, and the turn it spends softening is a turn it spends not striking.
	write(enemy(&"draught", 30, 33,
		[inflict(StatusRules.SOFTENED, 2), attack(8), attack(6)] as Array[EnemyIntent]))

	print("\n1막 — 하루 (넷이 한 무리)")

	# 하루. Four moments of one day, each awake only under its own sky, written
	# into one encounter and never drawn as anybody's company. A turn is three
	# hours, so the fight walks through them: which of the four are met awake is
	# decided by the hour the room is entered, and the HUD says which is next.
	# The two whose sky lasts a single turn get one hard blow; the two whose sky
	# lasts three get a pattern. Frail one at a time on purpose — the gauge that
	# matters is all four, and that is a long normal fight.
	write(enemy(&"breakfast", 13, 15,
		[wait()] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{MORNING: [attack(12)]}))
	write(enemy(&"nap", 13, 15,
		[wait()] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{DAY: [attack(5), block(4), attack(6)]}))
	write(enemy(&"sundown", 13, 15,
		[wait()] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{EVENING: [attack(12)]}))
	write(enemy(&"supper", 13, 15,
		[wait()] as Array[EnemyIntent], null, EnemyData.Tier.NORMAL,
		{NIGHT: [attack(6), attack(4, 2), attack(6)]}))

	print("\n1막 — 모래시계 (둘이 한 무리)")

	# 모래시계. The upper bulb is the bigger gauge and the harder blow, and it is
	# emptying on its own; the lower starts small and is what the fight turns into
	# if it is left to. Neither order is free: take the upper and the lower has
	# already grown, take the lower and it is refilled while it is being emptied.
	write(enemy(&"hourglass_upper", 20, 22,
		[attack(6)] as Array[EnemyIntent], BehaviorHourglass))
	write(enemy(&"hourglass_lower", 14, 16,
		[attack(4)] as Array[EnemyIntent], BehaviorHourglass))

	print("\n1막 — 이어달리기 (셋이 한 무리)")

	# 이어달리기. Three of the same thing and one blow a turn between them: 6, 9,
	# 12, 15. Each is about one whole turn of the starting deck, so the question
	# every turn is the same one — bring down the runner holding it and the blow
	# never comes and the next starts from 6, or fall a card short and take it.
	# Guarding instead is always possible and always dearer than last turn.
	write(enemy(&"runner", 15, 17,
		[attack(6)] as Array[EnemyIntent], BehaviorRelay))

	print("\n1막 — 합창 (셋이 한 무리)")

	# 합창. Each sings 2 for every one still singing: 18 a turn with three, 8 with
	# two, 2 with one. The first turn is the worst of the fight and every one that
	# falls takes more than its share with it, so this is the group that is paid
	# for by hesitating.
	write(enemy(&"chorister", 11, 13,
		[attack(2)] as Array[EnemyIntent], BehaviorChorus))

	print("\n1막 — 도미노 (넷이 한 무리)")

	# 도미노. Ten each and a push of six, with no range on the gauge: this one is
	# arithmetic and the player should be able to do it. Anything worn to six or
	# less goes when the one in front of it does, so the cheap way through is to
	# wear the back three down and then tip the first.
	write(enemy(&"domino", 10, 10,
		[attack(3)] as Array[EnemyIntent], BehaviorDomino))

	print("\n1막 — 방패막이 (둘이 한 무리)")

	# 방패막이. The one in front does nothing but raise its guard, and is most of the
	# gauge. The one behind does all the striking and cannot be aimed at until the
	# front is down. Only a card that strikes everything reaches it early.
	write(enemy(&"shelter_front", 24, 27,
		[block(4)] as Array[EnemyIntent]))
	write(enemy(&"shelter_behind", 12, 14,
		[attack(5), attack(6)] as Array[EnemyIntent], BehaviorSheltered))

	print("\n1막 — 정예")

	# 가속. Deliberately a wall rather than a killer: it guards itself, so the
	# fight runs long, and running long is the whole cost. The player is not being
	# asked whether they can survive it but whether they can afford it.
	write(enemy(&"murphys_law", 84, 92,
		[block(12), attack(12), block(12), attack(16)] as Array[EnemyIntent],
		BehaviorQuickening, EnemyData.Tier.ELITE))

	# 흘림. The opposite question to 가속: that one cannot be blocked out of, this
	# one has to be. Mostly many small blows, because every one that gets past the
	# guard is another hour gone, so a point of block short is an hour short.
	write(enemy(&"throng", 66, 72,
		[attack(5, 3), block(10), attack(8, 2), attack(14)] as Array[EnemyIntent],
		BehaviorSpilling, EnemyData.Tier.ELITE))

	# 벽시계. Three hands on one face, each keeping its own count: every turn, every
	# second, every fourth. No behaviour — the waits are on the intent line. They
	# fall together on the fourth turn, and the whole fight is which hand is gone
	# by then: the one that never stops, or the one that lands hardest.
	write(enemy(&"second_hand", 20, 22,
		[attack(4)] as Array[EnemyIntent], null, EnemyData.Tier.ELITE))
	write(enemy(&"minute_hand", 24, 27,
		[wait(), attack(8)] as Array[EnemyIntent], null, EnemyData.Tier.ELITE))
	write(enemy(&"hour_hand", 30, 33,
		[wait(), wait(), wait(), attack(16)] as Array[EnemyIntent], null, EnemyData.Tier.ELITE))

	# 시소. The heavier end comes down. The guard is what makes it rock: the end
	# that is behind is also the end that is shielded, so the easy damage is always
	# on the one striking, and enough of it changes who strikes next. Two different
	# blows — one hard, one a flurry — so which end is left up is a real choice.
	write(enemy(&"seesaw_near", 34, 37,
		[attack(10), block(5)] as Array[EnemyIntent],
		BehaviorSeesaw, EnemyData.Tier.ELITE))
	write(enemy(&"seesaw_far", 38, 41,
		[attack(3, 3), block(5)] as Array[EnemyIntent],
		BehaviorSeesaw, EnemyData.Tier.ELITE))

	# 버팀목. Sixty of gauge at fifteen a turn is four turns and cannot be three,
	# whatever the deck. A starting hand needs all three hours to reach fifteen; a
	# better one reaches it in two and has the third to guard with, and that spare
	# hour is the whole of what a strong deck buys here. It grows once a cycle so
	# the four turns are not all the same price.
	write(enemy(&"prop", 58, 60,
		[attack(11), attack(7, 2), grow(1)] as Array[EnemyIntent],
		BehaviorBulwark, EnemyData.Tier.ELITE))

	print("\n1막 — 보스")

	# 메아리. Deals nothing it was not dealt, and does nothing that was not done.
	# Two thirds of a turn's damage comes back a turn later as a blow, two thirds
	# of the Warden's guard as its guard, and every status as it was — so the
	# gauge is worth two thirds of itself in blows whatever is done, and what the
	# player chooses is the shape those arrive in. Every card in the deck is a
	# card it has too, a turn late: 물러짐 opens it up and then opens the Warden,
	# and a turn spent only holding is a turn it spends behind a wall.
	# It opens waiting, having heard nothing.
	write(enemy(&"echo", 110, 120,
		[wait()] as Array[EnemyIntent], BehaviorEcho, EnemyData.Tier.BOSS))

	# 해를 끄는 것. Wants the night and pulls the day out from under the run to
	# get there. Each sky begins its pattern from the top, so the fight can be
	# counted:
	#   아침  one turn, and it pulls.
	#   낮    three turns, and it pulls on every one of them.
	#   저녁  one turn. It grows.
	#   밤    three turns. Everything it has.
	# A pull is broken by taking the grip's worth off its gauge in the turn it is
	# shown, and each one broken tightens the grip by four for the rest of the
	# fight: 18, 22, 26, 30. One that holds lands the run on the evening at once,
	# and the evening's growth is 1 and one more for every three hours the pull
	# took, its own turn included — 5 from the morning, then 4, 3 and 2 across the
	# day. The day's last pull moves the clock nowhere, the turn having reached
	# the evening by itself, and is still a turn it pulled.
	# By day it never strikes. The whole of what it does to the Warden is at night,
	# and how hard that is was decided before dark.
	write(enemy(&"sun_dragger", 120, 130,
		[drag(18)] as Array[EnemyIntent],
		BehaviorSunDragger, EnemyData.Tier.BOSS,
		{
			MORNING: [drag(18)],
			EVENING: [grow(1)],
			NIGHT: [attack(12), attack(8, 2), attack(14)],
		}))


func _act_two() -> void:
	print("\n2막 — 일반")

	# 좀먹음. Never touches the Warden while there is anything carried to take
	# instead, so the fight is safe and expensive: every point let through is an
	# hour that no shop and no fire will see, and its own gauge pays back about
	# seven. Authored low for that reason — a whole cycle unblocked is eleven hours.
	write(enemy(&"bottomless", 34, 38,
		[attack(5), attack(3, 2)] as Array[EnemyIntent],
		BehaviorGnawing, EnemyData.Tier.NORMAL, {}, 2))

	# 무거움. Half again as much gauge as it reads to a hand of one-hour cards, and
	# exactly what it reads to a two-hour one. Kept small for that reason: what it
	# asks is which cards, not how many turns.
	write(enemy(&"sunken", 24, 27,
		[attack(7), attack(10), block(8)] as Array[EnemyIntent],
		BehaviorHeavy, EnemyData.Tier.NORMAL, {}, 2))

	print("\n2막 — 정예")

	# 날 넘김. A day is eight turns, so walked into at midnight it is a long fight
	# with room to spare and walked into at nine in the evening it is one turn and
	# then the whole thing again. It grows once a cycle, and midnight takes that
	# back along with everything else — the one thing the reset gives the player.
	write(enemy(&"yesterday", 90, 98,
		[attack(9), block(10), attack(6, 2), grow(1)] as Array[EnemyIntent],
		BehaviorDaybound, EnemyData.Tier.ELITE, {}, 2))


func _act_three() -> void:
	pass
