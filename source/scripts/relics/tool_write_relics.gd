extends SceneTree


const OUT_DIR := "res://source/data/relics"


func write(r: Relic, id: StringName, rarity: Relic.Rarity) -> void:
	r.id = id
	r.name_key = StringName("relic.%s.name" % id)
	r.text_key = StringName("relic.%s.text" % id)
	r.rarity = rarity
	var problems := r.validate()
	if not problems.is_empty():
		print("  LINT  %s: %s" % [r.id, problems])
	var err := ResourceSaver.save(r, "%s/%s.tres" % [OUT_DIR, r.id])
	print("  %s  %-9s %-14s %s" % [
		"ok  " if err == OK else "FAIL",
		Relic.Rarity.keys()[rarity].to_lower(), r.display_name(), r.description()])


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("writing relics to %s\n" % OUT_DIR)

	# Always on.
	write(RelicSettledDust.new(), &"settled_dust", Relic.Rarity.COMMON)
	write(RelicBrokenMainspring.new(), &"broken_mainspring", Relic.Rarity.UNCOMMON)
	write(RelicGleaning.new(), &"gleaning", Relic.Rarity.UNCOMMON)
	write(RelicWornShoes.new(), &"worn_shoes", Relic.Rarity.RARE)
	write(RelicStoppedWatch.new(), &"stopped_watch", Relic.Rarity.RARE)

	# Keyed to the hour of the day.
	write(RelicSundial.new(), &"sundial", Relic.Rarity.COMMON)
	write(RelicLongShadow.new(), &"long_shadow", Relic.Rarity.COMMON)
	write(RelicNightBell.new(), &"night_bell", Relic.Rarity.UNCOMMON)
	write(RelicMorningFrost.new(), &"morning_frost", Relic.Rarity.UNCOMMON)

	# Front-loaded: worth most to a deck that means to finish early.
	write(RelicHeldStone.new(), &"held_stone", Relic.Rarity.COMMON)
	write(RelicFirstLight.new(), &"first_light", Relic.Rarity.COMMON)
	write(RelicQuickHand.new(), &"quick_hand", Relic.Rarity.UNCOMMON)
	write(RelicShortRope.new(), &"short_rope", Relic.Rarity.UNCOMMON)

	# Back-loaded: worth nothing to that deck, and a great deal to an engine.
	write(RelicSlowKettle.new(), &"slow_kettle", Relic.Rarity.UNCOMMON)
	write(RelicPracticedHand.new(), &"practiced_hand", Relic.Rarity.UNCOMMON)

	# Keyed to how the run itself is going.
	write(RelicBorrowedCoat.new(), &"borrowed_coat", Relic.Rarity.COMMON)
	write(RelicLastEmber.new(), &"last_ember", Relic.Rarity.UNCOMMON)
	write(RelicCountedDays.new(), &"counted_days", Relic.Rarity.RARE)
	write(RelicFullPockets.new(), &"full_pockets", Relic.Rarity.RARE)

	# Two-sided.
	write(RelicThinIce.new(), &"thin_ice", Relic.Rarity.RARE)

	# Boss relics. Handed out by act bosses and rolled nowhere else, so they are
	# allowed to change a rule rather than a number.
	write(RelicEquality.new(), &"equality", Relic.Rarity.BOSS)

	quit(0)
