class_name PauseView
extends OverlayView


const SCENE := preload("res://source/scenes/ui/pause_view.tscn")


## Always make one through here, never PauseView.new(): new() is the script
## without the scene it shares with the other overlays.
static func create() -> PauseView:
	return SCENE.instantiate() as PauseView


signal resume_requested
signal title_requested
signal settings_requested
signal abandon_requested

var _confirming := false


func show_pause() -> void:
	_confirming = false
	_rebuild()


func _rebuild() -> void:
	set_compact(true, OverlayView.PAUSE_PLATE)
	clear_body()

	if _confirming:
		heading(tr("ui.pause.abandon_confirm"))
		body().add_child(_entry(tr("ui.pause.abandon_yes"),
			func() -> void: abandon_requested.emit()))
		body().add_child(_entry(tr("ui.pause.abandon_no"), func() -> void:
			_confirming = false
			_rebuild()))
		return

	heading(tr("ui.pause.title"))
	body().add_child(_entry(tr("ui.pause.resume"), func() -> void: resume_requested.emit()))
	body().add_child(_entry(tr("ui.pause.settings"), func() -> void: settings_requested.emit()))
	body().add_child(_entry(tr("ui.pause.to_title"), func() -> void: title_requested.emit()))
	body().add_child(_entry(tr("ui.pause.abandon"), func() -> void:
		_confirming = true
		_rebuild()))


func _entry(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 52)
	button.pressed.connect(action)
	return button
