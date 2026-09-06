extends SceneTree


const RUNS_PER_LEVEL := 150
const GREEDS := [0.0, 0.35, 0.7, 1.0]

var _b: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_encounters = EncounterTable.new()
	_encounters.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()

	var runs := RUNS_PER_LEVEL
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		runs = args[0].to_int()

	print("\n%d runs per greed level\n" % runs)
	print("greed   done   fell  timeout |   act  fights  turns/fight |  travel%   fires  conv%")
	print("------  -----  -----  ------- |  ----  ------  ----------- |  -------  -----  -----")

	var rows := []
	for greed in GREEDS:
		rows.append(_batch(greed, runs))

	print("")
	_verdict(rows)
	quit(0)


func _batch(greed: float, runs: int) -> Dictionary:
	var totals := {
		"greed": greed, "finished": 0, "fell": 0, "timeout": 0,
		"fights": 0.0, "turns": 0.0, "travel": 0.0, "fires": 0.0,
		"converted": 0.0, "restored_total": 0.0, "deck": 0.0, "acts": 0.0, "hp_lost": 0.0,
	}

	for i in runs:
		var r := _play(greed, i * 7919 + int(greed * 1000))
		match r["outcome"]:
			RunController.Outcome.FINISHED:
				totals["finished"] = int(totals["finished"]) + 1
			RunController.Outcome.FELL:
				totals["fell"] = int(totals["fell"]) + 1
			_:
				totals["timeout"] = int(totals["timeout"]) + 1
		for key in ["fights", "turns", "travel", "fires", "converted", "restored_total", "deck", "acts", "hp_lost"]:
			totals[key] = float(totals[key]) + float(r[key])

	var n := float(runs)
	var restored_total: float = maxf(1.0, float(totals["restored_total"]))
	print("%5.2f  %5d  %5d  %7d |  %4.1f  %6.1f  %11.2f |  %6.1f%%  %5.1f  %4.0f%%" % [
		greed,
		int(totals["finished"]), int(totals["fell"]), int(totals["timeout"]),
		float(totals["acts"]) / n,
		float(totals["fights"]) / n,
		float(totals["turns"]) / maxf(1.0, float(totals["fights"])),
		100.0 * float(totals["travel"]) / maxf(1.0, float(totals["travel"]) + _elapsed_total(totals)),
		float(totals["fires"]) / n,
		100.0 * float(totals["converted"]) / restored_total,
	])
	return totals


func _elapsed_total(totals: Dictionary) -> float:
	return float(totals["turns"]) * 180.0 + float(totals["fires"]) * 480.0


func _play(greed: float, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var policy := SimPolicy.new(greed, rng, _cards)
	var rc := RunController.new(_b, _cards, _enemies, _encounters, _relics, seed_value)

	var fights := 0
	var turns := 0
	var fires := 0
	var guard := 0
	var hp_lost := 0
	var hp_was := rc.run.hp

	while not rc.is_over() and guard < 4000:
		guard += 1
		match rc.phase:
			RunController.Phase.BATTLE:
				var before := rc.battle.turn
				var hp_before := rc.battle.warden().hp
				policy.take_turn(rc)
				turns += maxi(1, rc.battle.turn - before) if rc.battle != null else 1
				var hp_after: int = rc.battle.warden().hp if rc.battle != null else rc.run.hp
				hp_lost += maxi(0, hp_before - hp_after)
			RunController.Phase.REWARD:
				fights += 1
				policy.at_reward(rc)
			RunController.Phase.FIRE:
				var spent: int = rc.run.clock.spent_by_source()[RunClock.Source.FIRE]
				policy.at_fire(rc, _b)
				if int(rc.run.clock.spent_by_source()[RunClock.Source.FIRE]) > int(spent):
					fires += 1
			RunController.Phase.EVENT:
				policy.at_event(rc)
			RunController.Phase.SHOP:
				policy.at_shop(rc)
			RunController.Phase.ACT_CLEARED:
				rc.advance_act()
			RunController.Phase.EXPLORING:
				if not _step(rc, policy):
					break
			_:
				break

	var spent: Dictionary = rc.run.clock.spent_by_source()
	return {
		"outcome": rc.outcome,
		"fights": fights,
		"turns": turns,
		"travel": float(spent[RunClock.Source.TRAVEL]),
		"fires": fires,
		"converted": float(rc.run.total_kept),
		"restored_total": float(rc.run.total_kept + rc.run.clock.restored),
		"deck": float(rc.run.deck.size()),
		"acts": float(rc.run.act),
		"hp_lost": float(hp_lost),
	}


func _step(rc: RunController, policy: SimPolicy) -> bool:
	var fights := 0
	var cleared := 0
	var target_kinds: Array = []
	for coord in rc.map.rooms:
		var room: Room = rc.map.rooms[coord]
		if room.kind != Room.Kind.COMBAT:
			continue
		fights += 1
		if room.cleared:
			cleared += 1
	var want := roundi(policy.greed * fights)

	if cleared < want:
		target_kinds = [Room.Kind.FIRE, Room.Kind.SHOP, Room.Kind.COMBAT]
	else:
		target_kinds = [Room.Kind.BOSS]

	for kind in target_kinds:
		var step: Variant = _toward(rc, kind)
		if step != null:
			return rc.move_to(step)

	var to_boss: Variant = _toward(rc, Room.Kind.BOSS)
	return rc.move_to(to_boss) if to_boss != null else false


func _toward(rc: RunController, kind: Room.Kind) -> Variant:
	var came := {rc.map.current: rc.map.current}
	var spent := {rc.map.current: 0}
	var queue := [rc.map.current]
	var best: Variant = null
	var best_cost := 0
	while not queue.is_empty():
		queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(spent[a]) < int(spent[b]))
		var at: Vector2i = queue.pop_front()
		var room: Room = rc.map.at(at)
		if at != rc.map.current and room.kind == kind and not room.is_spent():
			if best == null or int(spent[at]) < best_cost:
				best = at
				best_cost = int(spent[at])
			continue
		for n in rc.map.neighbours(at):
			var through := int(spent[at]) + rc.map.guessed_cost_between(at, n)
			if not spent.has(n) or through < int(spent[n]):
				spent[n] = through
				came[n] = at
				queue.append(n)
	if best == null:
		return null
	var node: Vector2i = best
	while came[node] != rc.map.current:
		node = came[node]
	return node


func _verdict(rows: Array) -> void:
	print("what the design said, and what happened")
	print("")

	var by_greed := {}
	for row in rows:
		by_greed[float(row["greed"])] = row

	var fell := 0
	var timeout := 0
	for row in rows:
		fell += int(row["fell"])
		timeout += int(row["timeout"])
	var losses := maxi(1, fell + timeout)
	print("  losses by cause          %d%% clock / %d%% health   (target: the clock dominates)"
		% [100 * timeout / losses, 100 * fell / losses])

	var spread := []
	for g in GREEDS:
		var row: Dictionary = by_greed[float(g)]
		spread.append("%.0f%%" % (100.0 * float(row["finished"]) / maxf(1.0, float(row["finished"] + row["fell"] + row["timeout"]))))
	print("  completion by greed      %s   (target: not all the same)" % [" / ".join(spread)])

	var high: Dictionary = by_greed[1.0]
	print("  fights at greed 1.0      %.1f   (target: ~23 across a run)"
		% (float(high["fights"]) / maxf(1.0, float(high["finished"] + high["fell"] + high["timeout"]))))

	var converted := 100.0 * float(high["converted"]) / maxf(1.0, float(high["restored_total"]))
	print("  Restored converted       %.0f%%   (target: about half)" % converted)

	var fires_total := 0
	for act in range(1, _b.acts_per_run + 1):
		fires_total += _b.fires_in(act)
	var hp_supply := _b.starting_max_hp + fires_total * roundi(_b.starting_max_hp * _b.fire_heal_fraction)
	var per_fight := float(high["hp_lost"]) / maxf(1.0, float(high["fights"]))
	print("")
	print("  hp available per run     %d  (%d starting + %d fires at %d)"
		% [hp_supply, _b.starting_max_hp, fires_total, roundi(_b.starting_max_hp * _b.fire_heal_fraction)])
	var fires_used := float(high["fires"]) / maxf(1.0, float(high["finished"] + high["fell"] + high["timeout"]))
	var reachable := float(_b.starting_max_hp) + fires_used * roundi(_b.starting_max_hp * _b.fire_heal_fraction)
	print("  hp actually lost a fight %.0f  (measured, not assumed)" % per_fight)
	print("  fires actually reached   %.1f of %d" % [fires_used, fires_total])
	print("  so a run affords         %d fights on paper, %d in practice"
		% [roundi(float(hp_supply) / maxf(1.0, per_fight)), roundi(reachable / maxf(1.0, per_fight))])
	print("")
	print("  Anything far from its target is a number to change in balance.tres,")
	print("  not a system to rewrite. That was the point of putting them there.")
