extends SceneTree


const OUT_DIR := "res://source/data/cards"

const K := CardData.Kind
const R := CardData.Rarity
const L := CardData.Lane
const T := CardTargeting.Mode
const KW := CardData.Keyword

var _written := 0


func dmg(amount: int, times: int = 1, reroll: bool = false,
		text_key: StringName = &"") -> EffectDamage:
	var e := EffectDamage.new()
	e.amount = amount
	e.times = times
	e.reroll_target_each_hit = reroll
	e.text_key = text_key
	return e


func blk(amount: int) -> EffectBlock:
	var e := EffectBlock.new()
	e.amount = amount
	return e


func status(id: StringName, stacks: int, on_self: bool = false) -> EffectApplyStatus:
	var e := EffectApplyStatus.new()
	e.status = id
	e.stacks = stacks
	e.on_self = on_self
	return e


func draw(count: int) -> EffectDraw:
	var e := EffectDraw.new()
	e.count = count
	return e


func refund(hours: int) -> EffectRefundTime:
	var e := EffectRefundTime.new()
	e.minutes = hours * 60
	return e


func grow_dmg(base: int, per_card: int = 0, per_turn: int = 0,
		per_day: int = 0) -> EffectScalingDamage:
	var e := EffectScalingDamage.new()
	e.base = base
	e.per_card = per_card
	e.per_turn = per_turn
	e.per_day = per_day
	return e


func grow_blk(base: int, per_card: int = 0, per_turn: int = 0) -> EffectScalingBlock:
	var e := EffectScalingBlock.new()
	e.base = base
	e.per_card = per_card
	e.per_turn = per_turn
	return e


func per_hour(amount: int) -> EffectVariableDamage:
	var e := EffectVariableDamage.new()
	e.per_hour = amount
	return e


func reclaimed(hours: int) -> EffectRestoreTime:
	var e := EffectRestoreTime.new()
	e.hours = hours
	return e


func card(
	id: StringName,
	kind: CardData.Kind,
	rarity: CardData.Rarity,
	cost: int,
	targeting: CardTargeting.Mode,
	effects: Array[CardEffect],
	lanes: Array = [],
	keywords: int = 0,
) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name_key = StringName("card.%s.name" % id)
	c.kind = kind
	c.rarity = rarity
	c.cost_hours = cost
	c.targeting = targeting
	c.effects = effects
	c.lanes.assign(lanes)
	c.keywords = keywords
	return c


func upgrade(
	c: CardData,
	effects: Array[CardEffect] = [],
	cost: int = CardUpgrade.INHERIT,
	add_keywords: int = 0,
	remove_keywords: int = 0,
) -> CardData:
	var u := CardUpgrade.new()
	u.effects = effects
	u.cost_hours = cost
	u.add_keywords = add_keywords
	u.remove_keywords = remove_keywords
	c.upgrade = u
	return c


func write(c: CardData) -> void:
	var problems := c.validate()
	if not problems.is_empty():
		print("  LINT  %s: %s" % [c.id, problems])
	var err := ResourceSaver.save(c, "%s/%s.tres" % [OUT_DIR, c.id])
	if err == OK:
		_written += 1
	print("  %s  %-4s %-14s %s" % [
		"ok  " if err == OK else "FAIL", c.cost_text(), c.display_name(), c.rules_text()])


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("writing cards to %s\n" % OUT_DIR)

	_starters()
	_core()
	_rush()
	_engine()
	_chronomancy()
	_curses()

	print("\n%d cards" % _written)
	quit(0)


func _starters() -> void:
	print("시작 카드")
	write(upgrade(
		card(&"take", K.ATTACK, R.STARTER, 1, T.SINGLE_ENEMY,
			[dmg(6, 1, false, &"effect.take")]),
		[dmg(9, 1, false, &"effect.take")]))
	write(upgrade(
		card(&"brace", K.SKILL, R.STARTER, 1, T.SELF, [blk(5)]),
		[blk(8)]))


func _core() -> void:
	print("\n공용")
	write(upgrade(
		card(&"soften", K.SKILL, R.COMMON, 1, T.SINGLE_ENEMY, [status(StatusRules.SOFTENED, 2)]),
		[status(StatusRules.SOFTENED, 3)]))
	write(upgrade(
		card(&"blunt", K.SKILL, R.COMMON, 1, T.SINGLE_ENEMY, [status(StatusRules.BLUNTED, 2)]),
		[status(StatusRules.BLUNTED, 3)]))
	write(upgrade(
		card(&"unmake", K.ATTACK, R.COMMON, 1, T.SINGLE_ENEMY, [dmg(5), status(StatusRules.BLUNTED, 1)]),
		[dmg(7), status(StatusRules.BLUNTED, 1)]))
	write(upgrade(
		card(&"bulwark", K.SKILL, R.COMMON, 2, T.SELF, [blk(12)]),
		[blk(16)]))
	write(upgrade(
		card(&"gather", K.SKILL, R.COMMON, 1, T.SELF, [draw(2)], [], KW.EXHAUST),
		[draw(3)]))
	write(upgrade(
		card(&"sever", K.ATTACK, R.UNCOMMON, 2, T.SINGLE_ENEMY,
			[dmg(9), status(StatusRules.SOFTENED, 2)]),
		[dmg(12), status(StatusRules.SOFTENED, 2)]))
	write(upgrade(
		card(&"harden", K.SKILL, R.UNCOMMON, 1, T.ALL_ENEMIES,
			[blk(6), status(StatusRules.BLUNTED, 1)]),
		[blk(9), status(StatusRules.BLUNTED, 1)]))
	write(upgrade(
		card(&"stillness", K.SKILL, R.UNCOMMON, 1, T.SELF, [blk(10)], [], KW.EXHAUST),
		[blk(14)]))


func _rush() -> void:
	print("\n속공")
	write(upgrade(
		card(&"quick_cut", K.ATTACK, R.COMMON, 0, T.SINGLE_ENEMY, [dmg(3)], [L.RUSH]),
		[dmg(5)]))
	write(upgrade(
		card(&"double_cut", K.ATTACK, R.COMMON, 1, T.SINGLE_ENEMY, [dmg(4, 2)], [L.RUSH]),
		[dmg(5, 2)]))
	write(upgrade(
		card(&"press", K.ATTACK, R.COMMON, 2, T.SINGLE_ENEMY, [dmg(12)], [L.RUSH]),
		[dmg(16)]))
	write(upgrade(
		card(&"disperse", K.ATTACK, R.COMMON, 2, T.ALL_ENEMIES, [dmg(5)], [L.RUSH]),
		[dmg(8)]))
	write(upgrade(
		card(&"scatter", K.ATTACK, R.UNCOMMON, 1, T.RANDOM_ENEMY, [dmg(3, 3, true)], [L.RUSH]),
		[dmg(3, 4, true)]))
	write(upgrade(
		card(&"flurry", K.ATTACK, R.UNCOMMON, 2, T.RANDOM_ENEMY, [dmg(4, 4, true)], [L.RUSH]),
		[dmg(4, 5, true)]))
	write(upgrade(
		card(&"spend_it", K.ATTACK, R.RARE, CardData.COST_VARIABLE, T.SINGLE_ENEMY,
			[per_hour(5)], [L.RUSH]),
		[per_hour(7)]))
	write(upgrade(
		card(&"all_at_once", K.ATTACK, R.RARE, 3, T.ALL_ENEMIES, [dmg(14)], [L.RUSH]),
		[dmg(19)]))


func _engine() -> void:
	print("\n엔진")
	write(upgrade(
		card(&"steady", K.SKILL, R.COMMON, 1, T.SELF, [blk(4), draw(1)], [L.ENGINE]),
		[blk(6), draw(1)]))
	write(upgrade(
		card(&"wear_down", K.ATTACK, R.COMMON, 2, T.ALL_ENEMIES,
			[dmg(4), status(StatusRules.SOFTENED, 1)], [L.ENGINE]),
		[dmg(6), status(StatusRules.SOFTENED, 1)]))
	write(upgrade(
		card(&"momentum", K.ATTACK, R.UNCOMMON, 1, T.SINGLE_ENEMY,
			[grow_dmg(4, 3)], [L.ENGINE]),
		[grow_dmg(4, 4)]))
	write(upgrade(
		card(&"long_hour", K.SKILL, R.UNCOMMON, 2, T.SELF,
			[grow_blk(6, 0, 3)], [L.ENGINE]),
		[grow_blk(8, 0, 3)]))
	write(upgrade(
		card(&"unspool", K.SKILL, R.UNCOMMON, 2, T.ALL_ENEMIES,
			[status(StatusRules.SOFTENED, 2)], [L.ENGINE]),
		[status(StatusRules.SOFTENED, 3)]))
	write(upgrade(
		card(&"regather", K.SKILL, R.RARE, 2, T.SELF, [blk(8), draw(2)], [L.ENGINE], KW.EXHAUST),
		[], CardUpgrade.INHERIT, 0, KW.EXHAUST))
	write(upgrade(
		card(&"the_long_way", K.SKILL, R.RARE, 1, T.SELF,
			[grow_blk(4, 0, 4)], [L.ENGINE], KW.RETAIN),
		[grow_blk(6, 0, 4)]))


func _chronomancy() -> void:
	print("\n시간 조작")
	write(upgrade(
		card(&"held_breath", K.SKILL, R.UNCOMMON, 1, T.SELF,
			[refund(2), draw(1)], [L.CHRONOMANCY], KW.EXHAUST),
		[], 0))
	write(upgrade(
		card(&"rewind", K.SKILL, R.UNCOMMON, 1, T.SELF,
			[refund(1), draw(2)], [L.CHRONOMANCY], KW.EXHAUST),
		[refund(2), draw(2)]))
	write(upgrade(
		card(&"unwind", K.SKILL, R.RARE, 2, T.SELF,
			[refund(4)], [L.CHRONOMANCY], KW.EXHAUST),
		[refund(5)]))
	write(upgrade(
		card(&"hourglass", K.SKILL, R.RARE, 2, T.SELF,
			[refund(2), draw(3)], [L.CHRONOMANCY], KW.EXHAUST),
		[refund(3), draw(3)]))
	write(upgrade(
		card(&"reclaim", K.ATTACK, R.RARE, 2, T.SINGLE_ENEMY,
			[dmg(8), reclaimed(2)], [L.CHRONOMANCY], KW.EXHAUST),
		[dmg(10), reclaimed(3)]))
	# Two hours for one 거두기 on the day the run leaves, and level
	# with two of them six days on. The one card that pays for being late, the same
	# lateness Threat charges for.
	write(upgrade(
		card(&"long_kept", K.ATTACK, R.RARE, 2, T.SINGLE_ENEMY,
			[grow_dmg(6, 0, 0, 1)], [L.CHRONOMANCY]),
		[grow_dmg(6, 0, 0, 2)]))


func _curses() -> void:
	print("\n저주")
	var delay := card(&"delay", K.CURSE, R.SPECIAL, 1, T.SELF, [])
	delay.text_key = &"card.delay.text"
	write(delay)

	var drag := card(&"drag", K.CURSE, R.SPECIAL, 0, T.SELF, [], [], KW.UNPLAYABLE)
	drag.text_key = &"card.drag.text"
	write(drag)
