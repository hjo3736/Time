extends SceneTree


const OUT_DIR := "res://source/data/relics"


func write(r: Relic) -> void:
	var problems := r.validate()
	if not problems.is_empty():
		print("  LINT  %s: %s" % [r.id, problems])
	var err := ResourceSaver.save(r, "%s/%s.tres" % [OUT_DIR, r.id])
	print("  %s  %-12s %s" % ["ok  " if err == OK else "FAIL", r.display_name(), r.description()])


func _init() -> void:
	TranslationServer.set_locale("ko")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("writing relics to %s\n" % OUT_DIR)

	var mainspring := RelicBrokenMainspring.new()
	mainspring.id = &"broken_mainspring"
	mainspring.name_key = &"relic.broken_mainspring.name"
	mainspring.text_key = &"relic.broken_mainspring.text"
	write(mainspring)

	var shoes := RelicWornShoes.new()
	shoes.id = &"worn_shoes"
	shoes.name_key = &"relic.worn_shoes.name"
	shoes.text_key = &"relic.worn_shoes.text"
	write(shoes)

	var gleaning := RelicGleaning.new()
	gleaning.id = &"gleaning"
	gleaning.name_key = &"relic.gleaning.name"
	gleaning.text_key = &"relic.gleaning.text"
	write(gleaning)

	var watch := RelicStoppedWatch.new()
	watch.id = &"stopped_watch"
	watch.name_key = &"relic.stopped_watch.name"
	watch.text_key = &"relic.stopped_watch.text"
	write(watch)

	quit(0)
