class_name SaveGame
extends RefCounted


static var path := "user://run.save"


static func has_save() -> bool:
	return FileAccess.file_exists(path)


static func save(rc: RunController) -> bool:
	if rc == null or rc.run == null:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("could not write %s: %s" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(rc.save_state()))
	file.close()
	return true


static func load_run(
	balance: Balance,
	cards: CardDatabase,
	enemies: EnemyDatabase,
	encounters: EncounterTable,
	relics: RelicDatabase,
) -> RunController:
	if not has_save():
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("save file did not parse; ignoring it")
		return null
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != RunController.SAVE_VERSION:
		push_warning("save file is version %s, this build reads %d; ignoring it"
			% [data.get("version", "?"), RunController.SAVE_VERSION])
		return null
	return RunController.from_dict(data, balance, cards, enemies, encounters, relics)


static func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
