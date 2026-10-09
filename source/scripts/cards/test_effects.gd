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

	print("\n-- damage hits every resolved target --")
	var ctx := RecordingEffectContext.new(0, PackedInt32Array([1, 2, 3]))
	var dmg := EffectDamage.new()
	dmg.amount = 9
	dmg.apply(ctx)
	check("one call per target", ctx.count(&"deal_damage"), 3)
	check("amount carried", ctx.calls[0]["amount"], 9)

	print("\n-- dead targets are skipped --")
	var dead_ctx := RecordingEffectContext.new(0, PackedInt32Array([1, 2, 3]))
	dead_ctx.dead = PackedInt32Array([2])
	dmg.apply(dead_ctx)
	check("only living hit", dead_ctx.count(&"deal_damage"), 2)

	print("\n-- block goes on the caster, never the target --")
	var b_ctx := RecordingEffectContext.new(0, PackedInt32Array([7]))
	var blk := EffectBlock.new()
	blk.amount = 5
	blk.apply(b_ctx)
	check("target of block", b_ctx.calls[0]["target"], 0)
	check("caster armoured", b_ctx.get_block(0), 5)
	check("enemy untouched", b_ctx.get_block(7), 0)

	print("\n-- block absorbs before damage lands --")
	var a_ctx := RecordingEffectContext.new(0, PackedInt32Array([1]))
	a_ctx.gain_block(1, 4)
	dmg.amount = 9
	dmg.apply(a_ctx)
	check("dealt after block", a_ctx.calls[1]["dealt"], 5)
	check("block consumed", a_ctx.get_block(1), 0)

	print("\n-- status can point either way --")
	var s_ctx := RecordingEffectContext.new(0, PackedInt32Array([1]))
	var st := EffectApplyStatus.new()
	st.status = &"softened"
	st.stacks = 2
	st.apply(s_ctx)
	check("landed on target", s_ctx.get_status(1, &"softened"), 2)
	st.on_self = true
	st.status = &"wound"
	st.apply(s_ctx)
	check("landed on self", s_ctx.get_status(0, &"wound"), 2)

	print("\n-- draw is clamped by the pile --")
	var d_ctx := RecordingEffectContext.new()
	d_ctx.draw_pile_size = 2
	var draw := EffectDraw.new()
	draw.count = 5
	draw.apply(d_ctx)
	check("drew what was there", d_ctx.calls[0]["drawn"], 2)
	check("pile emptied", d_ctx.draw_pile_size, 0)

	print("\n-- chronomancy refunds the turn budget only --")
	var t_ctx := RecordingEffectContext.new()
	var refund := EffectRefundTime.new()
	refund.minutes = 60
	refund.apply(t_ctx)
	check("verb used", t_ctx.verbs(), [&"refund_turn_time"])
	check("minutes", t_ctx.calls[0]["minutes"], 60)
	check("never touched Remaining or Restored", t_ctx.count(&"restore_time"), 0)

	print("\n-- generated text never disagrees with the numbers --")
	var text_dmg := EffectDamage.new()
	text_dmg.amount = 9
	check("damage", text_dmg.describe(), "Deal 9 damage.")
	text_dmg.amount = 12
	check("follows the override", text_dmg.describe(), "Deal 12 damage.")
	check("block", EffectBlock.new().describe(), "Gain 5 block.")
	check("draw singular", EffectDraw.new().describe(), "Draw 1 card.")
	var d2 := EffectDraw.new()
	d2.count = 2
	check("draw plural", d2.describe(), "Draw 2 cards.")
	check("refund reads in hours", refund.describe(), "Regain 1h this turn.")

	print("\n-- effects hold no state between uses --")
	var r1 := RecordingEffectContext.new(0, PackedInt32Array([1]))
	var r2 := RecordingEffectContext.new(0, PackedInt32Array([1]))
	text_dmg.apply(r1)
	text_dmg.apply(r2)
	check("identical outcomes", r1.calls, r2.calls)

	print("\n-- an unimplemented verb is loud, not silent --")
	var bare := EffectContext.new()
	bare.targets = PackedInt32Array([1])
	check("returns a safe default", bare.deal_damage(1, 5), 0)

	print("\n-- damage that grows with the days the run has passed --")
	var kept := EffectScalingDamage.new()
	kept.base = 4
	kept.per_card = 0
	kept.per_day = 2
	var day_zero := RecordingEffectContext.new(0, PackedInt32Array([1]))
	kept.apply(day_zero)
	check("on the day the run leaves it is only its base", day_zero.calls[0]["amount"], 4)
	var day_five := RecordingEffectContext.new(0, PackedInt32Array([1]))
	day_five.days = 5
	day_five.turn = 4
	day_five.played_this_turn = 3
	kept.apply(day_five)
	check("five midnights on it is ten more", day_five.calls[0]["amount"], 14)
	check("and the card says how it grows",
		kept.describe().contains(tr("effect.grows_per_day").format({"n": 2})), true)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
