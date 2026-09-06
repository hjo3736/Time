extends SceneTree


var _failures := 0
var _b: Balance


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func _init() -> void:
	_b = Balance.default()

	print("\n-- damage does not end the run, only the fight --")
	var s := RunState.new(_b)
	check("starts full", s.hp, 70)
	check("survives a hit", s.damage(30), false)
	check("hp", s.hp, 40)
	check("clock untouched by damage", s.clock.remaining, _b.starting_remaining)
	check("lethal hit reported", s.damage(40), true)
	check("hp floors at 0", s.hp, 0)
	check("run clock still fine", s.clock.remaining, _b.starting_remaining)

	print("\n-- a fire buys exactly one action --")
	var f := RunState.new(_b)
	f.damage(40)
	var before := f.clock.remaining
	check("rest works", f.use_fire(RunState.FireAction.REST), true)
	check("healed by the balance fraction", f.hp, 30 + f.fire_heal_amount())
	check("charged 8h once", before - f.clock.remaining, 480)
	check("logged as fire", f.clock.spent_by_source()[RunClock.Source.FIRE], 480)

	print("\n-- a fire refuses actions that would do nothing --")
	var n := RunState.new(_b)
	var full := n.clock.remaining
	check("rest at full hp refused", n.use_fire(RunState.FireAction.REST), false)
	check("nothing charged", n.clock.remaining, full)
	check("convert with no restored refused", n.use_fire(RunState.FireAction.CONVERT), false)
	check("still nothing charged", n.clock.remaining, full)
	check("upgrade with empty deck refused", n.use_fire(RunState.FireAction.UPGRADE, 0), false)
	check("still nothing charged", n.clock.remaining, full)

	var odd := RunState.new(_b)
	odd.defeat_askew(60)
	var odd_before := odd.clock.remaining
	check("an hour of restored converts to nothing, so it is refused",
		odd.use_fire(RunState.FireAction.CONVERT), false)
	check("the 8h fire was not charged", odd.clock.remaining, odd_before)
	check("and the hour is still on hand", odd.clock.restored, 60)

	print("\n-- upgrading marks one card --")
	var u := RunState.new(_b)
	u.add_card(&"strike")
	u.add_card(&"guard")
	check("upgrade ok", u.use_fire(RunState.FireAction.UPGRADE, 1), true)
	check("target upgraded", u.deck[1]["upgrades"], 1)
	check("neighbour untouched", u.deck[0]["upgrades"], 0)

	print("\n-- converting at a fire feeds the ending ledger --")
	var c := RunState.new(_b)
	c.defeat_askew(_b.conversion_cap, &"the-baker")
	var start := c.clock.remaining
	check("convert ok", c.use_fire(RunState.FireAction.CONVERT), true)
	check("kept ledger in restored-minutes", c.total_kept, 36 * 60)
	check("gained 18h, paid 8h, net +10h", c.clock.remaining - start, 10 * 60)
	check("delivered is what is left", c.delivered(), 0)

	print("\n-- dying with a pocket full of time --")
	var poor := RunState.new(_b)
	poor.clock.advance(_b.starting_remaining - 6 * 60, RunClock.Source.TRAVEL)
	poor.defeat_askew(_b.conversion_cap)
	check("remaining", poor.clock.remaining, 6 * 60)
	check("restored on hand", poor.clock.restored, 36 * 60)
	check("cannot afford the fire", poor.can_use_fire(), false)
	check("so conversion is refused", poor.use_fire(RunState.FireAction.CONVERT), false)

	print("\n-- memories are the second ending axis, and dedupe --")
	var m := RunState.new(_b)
	var heard := []
	m.memory_recovered.connect(func(id: StringName) -> void: heard.append(id))
	m.defeat_askew(360, &"the-baker")
	m.defeat_askew(360, &"the-baker")
	m.defeat_askew(360, &"the-ferryman")
	check("unique memories", m.memories.size(), 2)
	check("signal per new memory", heard.size(), 2)
	check("restored still counted every time", m.clock.restored, 1080)

	print("\n-- walking a room with no price of its own costs the base rate --")
	var w := RunState.new(_b)
	w.enter_room(&"a3")
	w.enter_room(&"a4")
	check("position", String(w.room_id), "a4")
	check("two transitions", w.clock.elapsed, 2 * _b.room_transition_cost)

	print("\n-- deck edits --")
	var d := RunState.new(_b)
	d.add_card(&"strike")
	d.add_card(&"strike")
	d.add_relic(&"cracked-glass")
	d.add_relic(&"cracked-glass")
	check("relics dedupe", d.relics.size(), 1)
	check("remove out of range refused", d.remove_card(9), false)
	check("remove ok", d.remove_card(0), true)
	check("deck size", d.deck.size(), 1)

	print("\n-- round-trip --")
	var r := RunState.new(_b, 12345)
	r.damage(25)
	r.add_card(&"strike")
	r.use_fire(RunState.FireAction.UPGRADE, 0)
	r.add_relic(&"cracked-glass")
	r.defeat_askew(720, &"the-baker")
	r.enter_room(&"b2")
	r.act = 2
	var back := RunState.from_dict(r.to_dict(), _b)
	check("hp", back.hp, r.hp)
	check("seed", back.seed, 12345)
	check("act", back.act, 2)
	check("room", String(back.room_id), "b2")
	check("deck", back.deck, r.deck)
	check("relics", back.relics, r.relics)
	check("memories", back.memories, r.memories)
	check("clock remaining", back.clock.remaining, r.clock.remaining)
	check("clock restored", back.clock.restored, r.clock.restored)
	check("kept ledger", back.total_kept, r.total_kept)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
