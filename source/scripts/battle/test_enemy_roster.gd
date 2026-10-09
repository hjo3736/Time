extends SceneTree


var _failures := 0
var _b: Balance
var _db: EnemyDatabase


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func rng(seed_value: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## The roster is being rebuilt from nothing, so these are what it holds today, not
## what the finished game wants. Adding an enemy turns this red on purpose: the
## number here is meant to be edited deliberately, the way borrowed_acts() is.
##
## Targets for the finished game, for when that day comes:
##   ~20 enemies, normals >= 6, elites >= 2, a boss per act, and every one of the
##   five Askew behaviours fielded by some boss.
const HELD_NOW := {"all": 7, "normal": 4, "elite": 3, "boss": 0}

const ASKEW := ["BehaviorLooper", "BehaviorReversed", "BehaviorStilled",
	"BehaviorOverlaid", "BehaviorWithered"]


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_db = EnemyDatabase.new()
	_db.load_from()

	print("\n-- the roster loads and passes its own linter --")
	check("problems", _db.validate(), PackedStringArray())
	var ids := _db.all().map(func(e: EnemyData) -> String: return String(e.id))
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	check("sorted by id", ids, sorted_ids)

	print("\n-- what the roster holds while it is being rebuilt --")
	check("enemies", _db.size(), HELD_NOW["all"])
	check("normals", _db.of_tier(EnemyData.Tier.NORMAL).size(), HELD_NOW["normal"])
	check("elites", _db.of_tier(EnemyData.Tier.ELITE).size(), HELD_NOW["elite"])
	check("bosses", _db.of_tier(EnemyData.Tier.BOSS).size(), HELD_NOW["boss"])
	var met := {}
	for e in _db.all():
		if e.behavior_script != null:
			met[e.behavior_script.get_global_name()] = true
	var askew_met := ASKEW.filter(func(name: String) -> bool: return met.has(name))
	check("and none of the five Askew behaviours is fielded yet", askew_met, [])

	print("\n-- every act's pool is its own, and the acts are split --")
	var by_act := {}
	for e in _db.all():
		by_act[e.act] = int(by_act.get(e.act, 0)) + 1
	check("acts present", _db.acts_present(), [1, 2])
	check("and of_act agrees with the count",
		_db.of_act(1).size(), int(by_act.get(1, 0)))
	check("act two holds its first three", _db.of_act(2).size(), 3)
	check("nothing authored for act three yet", _db.of_act(3).size(), 0)

	print("\n-- nothing in act one dies to the starting deck's best opening turn --")
	# An Askew that can be taken in one turn never gets to show what it does: 성장
	# lands at the end of its turn, and a thing that dies first has no end of turn.
	# Measured by playing the real cards through a real battle, not by adding up
	# numbers, so 끊어내기's 물러짐 boosting the 거두기 after it is counted.
	var burst := _best_opening_turn()
	check("the starting deck's best opening turn was measured", burst > 0, true)
	var too_frail := []
	for e in _db.of_act(1):
		if e.hp_min <= burst:
			too_frail.append("%s (%d)" % [e.id, e.hp_min])
	check("every act one Askew outlives a %d-damage opening" % burst, too_frail, [])

	print("\n-- hp rolls inside the authored range, and replays --")
	# Generic over the roster: whatever is in it, the rules hold for all of it.
	var out_of_range := 0
	var unrepeatable := 0
	for e in _db.all():
		for i in 12:
			var c := e.spawn(_b, rng(i))
			if c.max_hp < e.hp_min or c.max_hp > e.hp_max:
				out_of_range += 1
		if e.spawn(_b, rng(3)).max_hp != e.spawn(_b, rng(3)).max_hp:
			unrepeatable += 1
	check("there is a roster to roll", _db.size() > 0, true)
	check("no roll fell outside its range", out_of_range, 0)
	check("and the same seed always rolls the same", unrepeatable, 0)

	print("\n-- Restored is derived from hp, never authored --")
	var mis_derived := 0
	for e in _db.all():
		var c := e.spawn(_b, rng(1))
		var want := roundi(c.max_hp * _b.restored_minutes_per_hp * e.restored_multiplier)
		if c.restored_value != want:
			mis_derived += 1
	check("every one of them", mis_derived, 0)

	print("\n-- a spawn owns its own intents and its own behaviour --")
	# Both of these were real bugs: a fight that rewrote the definition, and two
	# of a kind ageing on one shared counter.
	var shared_intents := 0
	var shared_behaviour := 0
	for e in _db.all():
		var before := e.intents.size()
		var one := e.spawn(_b, rng(1))
		one.intents.clear()
		if e.intents.size() != before:
			shared_intents += 1
		if e.behavior_script == null:
			continue
		var two := e.spawn(_b, rng(2))
		var three := e.spawn(_b, rng(3))
		if two.behavior == three.behavior:
			shared_behaviour += 1
	check("clearing a spawn's intents leaves the definition alone", shared_intents, 0)
	check("and no two spawns share one behaviour object", shared_behaviour, 0)

	print("\n-- a behaviour carries its own state, and a copy carries it too --")
	var ageing := BehaviorWithered.new()
	ageing.on_turn_end(null, 0)
	ageing.on_turn_end(null, 0)
	var fixture := EnemyData.new()
	fixture.id = &"test_ageing"
	fixture.name_key = &"enemy.test_ageing.name"
	fixture.hp_min = 30
	fixture.hp_max = 30
	fixture.intents = [EnemyIntent.attack(20)] as Array[EnemyIntent]
	fixture.behavior_script = BehaviorWithered
	var spawned := fixture.spawn(_b, rng(3))
	(spawned.behavior as BehaviorWithered).on_turn_end(null, 0)
	var copied := Combatant.from_dict(spawned.to_dict())
	check("the behaviour came back", copied.behavior != null, true)
	check("with the count it had", (copied.behavior as BehaviorWithered).turns_elapsed(), 1)
	check("and a fresh spawn is not ageing with it",
		(fixture.spawn(_b, rng(3)).behavior as BehaviorWithered).turns_elapsed(), 0)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


## The most damage the unupgraded starting deck can deal on turn one, assuming the
## best possible hand. Tries every hand the deck could deal that fits the budget,
## in every order, because order matters once a card applies a status.
func _best_opening_turn() -> int:
	var cards := CardDatabase.new()
	cards.load_from()
	var counts := {}
	for id in _b.starting_deck:
		counts[id] = int(counts.get(id, 0)) + 1
	var best := 0
	for hand in _hands(counts.keys(), counts, 0, [], cards):
		for order in _orders(hand):
			best = maxi(best, _damage_of(order, cards))
	return best


func _hands(ids: Array, counts: Dictionary, at: int, so_far: Array,
		cards: CardDatabase) -> Array:
	if so_far.size() > 5:
		return []
	var cost := 0
	for id in so_far:
		cost += cards.get_card(id).cost_minutes()
	if cost > _b.turn_cost:
		return []
	if at == ids.size():
		return [so_far.duplicate()]
	var out := []
	var id: StringName = ids[at]
	for take in int(counts[id]) + 1:
		var next := so_far.duplicate()
		for i in take:
			next.append(id)
		out.append_array(_hands(ids, counts, at + 1, next, cards))
	return out


func _orders(hand: Array) -> Array:
	if hand.size() <= 1:
		return [hand]
	var out := []
	var tried := {}
	for i in hand.size():
		if tried.has(hand[i]):
			continue
		tried[hand[i]] = true
		var rest := hand.duplicate()
		rest.remove_at(i)
		for tail in _orders(rest):
			out.append([hand[i]] + tail)
	return out


func _damage_of(order: Array, cards: CardDatabase) -> int:
	if order.is_empty():
		return 0
	var run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
	for id in order:
		run.add_card(id)
	var dummy := Combatant.new()
	dummy.max_hp = 999
	dummy.hp = 999
	dummy.intents = [EnemyIntent.wait()] as Array[EnemyIntent]
	var bt := BattleState.new(run, cards, [dummy] as Array[Combatant], rng(1))
	for id in order:
		var played := false
		for i in bt.piles().hand.size():
			if bt.card_at(i).id == id and bt.play_card(i, 1):
				played = true
				break
		if not played:
			break
	return 999 - dummy.hp
