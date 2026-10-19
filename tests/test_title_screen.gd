## Title screen: splash -> title -> Play reaches the run map; Options panel;
## Esc pause menu in Bonfire (Resume / Quit to title).
##   godot --headless --path . --script res://tests/test_title_screen.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	check(str(ProjectSettings.get_setting("boot/next_scene", "")) == "res://scenes/title.tscn", "splash continues to the title")
	check(TitleScreen.play_scene_path() == "res://scenes/run.tscn", "Play target is the run (map) scene")
	var t := (load("res://scenes/title.tscn") as PackedScene).instantiate() as TitleScreen
	root.add_child(t)
	current_scene = t
	await _frames(2)
	check(t.play_button.visible and t.options_button.visible, "Play and Options shown")
	check(t.quit_button.visible == (not (OS.has_feature("web") or OS.has_feature("mobile"))), "Quit only on desktop")
	t.open_options()
	check(t.options.visible and not t.menu.visible, "Options opens")
	check(t.options.sliders.size() == 4 and t.options.fullscreen_check != null and t.options.vsync_check != null, "volume x3 + sensitivity sliders, fullscreen and vsync toggles")
	t.options.back_button.pressed.emit()
	check(not t.options.visible and t.menu.visible, "Back closes Options")
	t.play()
	await _frames(4)
	check(current_scene is RunScreen, "Play loads the run map (%s)" % str(current_scene))
	# The Esc pause menu lives in the Bonfire table scene.
	change_scene_to_file("res://scenes/bonfire.tscn")
	await _frames(4)
	var b := current_scene as Bonfire3D
	check(b != null, "Bonfire loads (%s)" % str(current_scene))
	if b != null:
		await _frames(2)
		check(b.can_throw() == "" and b.run != null, "Bonfire is playable")
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		b._unhandled_input(esc)
		check(paused and b.pause_menu.visible, "Esc pauses with the menu")
		b.pause_menu.close()
		check(not paused and not b.pause_menu.visible, "Resume unpauses")
		b.pause_menu.open()
		b.pause_menu.quit_to_title()
		await _frames(4)
		check(current_scene is TitleScreen and not paused, "Quit to title returns to the title")
	print("test_title_screen: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
