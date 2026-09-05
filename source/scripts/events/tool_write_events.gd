extends SceneTree

const ROOT := "res://source/data/events"


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))

	write(event(&"a1_the_kettle", 1, 12, [
		choice(&"event.a1_the_kettle.wait", [time(2), memory(&"the-kettle")]),
		choice(&"event.a1_the_kettle.leave", []),
	]))

	write(event(&"a1_cold_hands", 1, 12, [
		choice(&"event.a1_cold_hands.warm", [time(1), heal(6), memory(&"cold-hands")]),
		choice(&"event.a1_cold_hands.pass", []),
	]))

	write(event(&"a1_the_late_one", 1, 12, [
		choice(&"event.a1_the_late_one.wait", [time(3), restored(4), memory(&"the-late-one")]),
		choice(&"event.a1_the_late_one.go", []),
	]))

	write(event(&"a1_the_long_table", 1, 10, [
		choice(&"event.a1_the_long_table.eat", [time(1), heal(10)]),
		choice(&"event.a1_the_long_table.take", [card(&"quick_cut")]),
		choice(&"event.a1_the_long_table.leave", []),
	]))

	write(event(&"a1_the_stopped_clock", 1, 10, [
		choice(&"event.a1_the_stopped_clock.wind", [hurt(6), restored(6)]),
		choice(&"event.a1_the_stopped_clock.leave", []),
	]))

	write(event(&"a1_the_debt", 1, 8, [
		choice(&"event.a1_the_debt.pay", [restored(-6), heal(14)], 6),
		choice(&"event.a1_the_debt.refuse", []),
	]))

	var table := EventTable.new()
	table.load_from()
	print("\n%d events" % table.size())
	for problem in table.validate():
		print("  PROBLEM  %s" % problem)
	for e in table.all():
		print("  %-22s act %d  w%-3d %s" % [e.id, e.act, e.weight, e.title()])
		for c in e.choices:
			print("      %-28s %s" % [c.label(), c.detail()])
	quit()


func event(id: StringName, act: int, weight: int, choices: Array) -> EventData:
	var e := EventData.new()
	e.id = id
	e.act = act
	e.weight = weight
	e.title_key = StringName("event.%s.title" % id)
	e.body_key = StringName("event.%s.body" % id)
	e.choices.assign(choices)
	return e


func choice(label_key: StringName, outcomes: Array, needs_restored := 0) -> EventChoice:
	var c := EventChoice.new()
	c.label_key = label_key
	c.outcomes.assign(outcomes)
	c.needs_restored_hours = needs_restored
	return c


func time(hours: int) -> OutcomeSpendTime:
	var o := OutcomeSpendTime.new()
	o.hours = hours
	return o


func heal(amount: int) -> OutcomeHealth:
	var o := OutcomeHealth.new()
	o.amount = amount
	return o


func hurt(amount: int) -> OutcomeHealth:
	var o := OutcomeHealth.new()
	o.amount = -amount
	return o


func restored(hours: int) -> OutcomeRestored:
	var o := OutcomeRestored.new()
	o.hours = hours
	return o


func card(card_id: StringName) -> OutcomeCard:
	var o := OutcomeCard.new()
	o.card_id = card_id
	return o


func memory(memory_id: StringName) -> OutcomeMemory:
	var o := OutcomeMemory.new()
	o.memory_id = memory_id
	return o


func write(e: EventData) -> void:
	var path := "%s/%s.tres" % [ROOT, e.id]
	var err := ResourceSaver.save(e, path)
	if err != OK:
		print("  FAIL  %s (%d)" % [path, err])
