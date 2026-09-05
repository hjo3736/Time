extends SceneTree


var _failures := 0


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func _init() -> void:
	TranslationServer.set_locale("en")

	var enemies := PackedInt32Array([1, 2, 3])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var M := CardTargeting.Mode

	print("\n-- the four modes --")
	check("self", CardTargeting.resolve(M.SELF, 0, enemies), PackedInt32Array([0]))
	check("all enemies", CardTargeting.resolve(M.ALL_ENEMIES, 0, enemies), enemies)
	check("single, chosen", CardTargeting.resolve(M.SINGLE_ENEMY, 0, enemies, null, 2), PackedInt32Array([2]))
	check("random picks one", CardTargeting.resolve(M.RANDOM_ENEMY, 0, enemies, rng).size(), 1)

	print("\n-- only single-enemy waits for the player --")
	check("single", CardTargeting.requires_player_choice(M.SINGLE_ENEMY), true)
	check("all", CardTargeting.requires_player_choice(M.ALL_ENEMIES), false)
	check("self", CardTargeting.requires_player_choice(M.SELF), false)
	check("random", CardTargeting.requires_player_choice(M.RANDOM_ENEMY), false)

	print("\n-- all enemies returns a copy, not the caller's array --")
	var live := PackedInt32Array([1, 2])
	var got := CardTargeting.resolve(M.ALL_ENEMIES, 0, live)
	got.append(99)
	check("caller untouched", live, PackedInt32Array([1, 2]))

	print("\n-- bad or empty input is inert, not fatal --")
	check("no enemies, all", CardTargeting.resolve(M.ALL_ENEMIES, 0, PackedInt32Array()), PackedInt32Array())
	check("no enemies, random", CardTargeting.resolve(M.RANDOM_ENEMY, 0, PackedInt32Array(), rng), PackedInt32Array())
	check("nothing chosen", CardTargeting.resolve(M.SINGLE_ENEMY, 0, enemies), PackedInt32Array())
	check("chose a corpse", CardTargeting.resolve(M.SINGLE_ENEMY, 0, enemies, null, 9), PackedInt32Array())
	check("self works with no enemies", CardTargeting.resolve(M.SELF, 7, PackedInt32Array()), PackedInt32Array([7]))

	print("\n-- random targeting is seeded, so runs replay --")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 12345
	b.seed = 12345
	var rolls_a := []
	var rolls_b := []
	for i in 8:
		rolls_a.append(CardTargeting.resolve(M.RANDOM_ENEMY, 0, enemies, a))
		rolls_b.append(CardTargeting.resolve(M.RANDOM_ENEMY, 0, enemies, b))
	check("same seed, same picks", rolls_a, rolls_b)

	print("\n-- multi-hit without reroll piles onto the resolved target --")
	var stuck := RecordingEffectContext.new(0, PackedInt32Array([1]))
	var boomer := EffectDamage.new()
	boomer.amount = 3
	boomer.times = 3
	boomer.apply(stuck)
	check("three hits", stuck.count(&"deal_damage"), 3)
	check("all on the same enemy", stuck.calls.map(func(c): return c["target"]), [1, 1, 1])

	print("\n-- multi-hit with reroll spreads across enemies --")
	var spread := RecordingEffectContext.new(0, PackedInt32Array([1, 2, 3]))
	boomer.reroll_target_each_hit = true
	boomer.times = 12
	boomer.apply(spread)
	check("twelve hits", spread.count(&"deal_damage"), 12)
	var hit := {}
	for c in spread.calls:
		hit[c["target"]] = true
	check("more than one enemy hit", hit.size() > 1, true)

	print("\n-- reroll with everything dead is inert --")
	var corpses := RecordingEffectContext.new(0, PackedInt32Array([1, 2]))
	corpses.dead = PackedInt32Array([1, 2])
	boomer.apply(corpses)
	check("no hits", corpses.count(&"deal_damage"), 0)

	print("\n-- descriptions --")
	check("all enemies", CardTargeting.describe(M.ALL_ENEMIES), "all enemies")
	check("random", CardTargeting.describe(M.RANDOM_ENEMY), "a random enemy")
	var multi := EffectDamage.new()
	multi.amount = 3
	multi.times = 4
	check("multi-hit text", multi.describe(), "Deal 3 damage 4 times.")

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
