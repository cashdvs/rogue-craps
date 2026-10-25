## GameSettings window logic (playtest bugs: game minimizes after Play,
## window flips fullscreen/windowed on its own). Saving a hint or the
## tutorial flag must not re-apply the window mode.
##   godot --headless --path . --script res://tests/test_window_mode.gd
extends SceneTree

const GS := preload("res://scripts/settings/game_settings.gd")

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	# Only a real change of a display option re-applies the window.
	check(GS.needs_display_apply(&"fullscreen", false, true), "fullscreen change applies")
	check(GS.needs_display_apply(&"vsync", true, false), "vsync change applies")
	check(not GS.needs_display_apply(&"fullscreen", true, true), "same fullscreen value: no apply")
	check(not GS.needs_display_apply(&"hints_seen", {}, {"a": 1}), "hint save: no apply")
	check(not GS.needs_display_apply(&"tutorial_seen", false, true), "tutorial flag: no apply")
	check(not GS.needs_display_apply(&"sfx_volume", 1.0, 0.5), "volume: no apply")
	# Window mode decisions.
	var W := DisplayServer.WINDOW_MODE_WINDOWED
	var F := DisplayServer.WINDOW_MODE_FULLSCREEN
	check(GS.window_mode_to_set(false, DisplayServer.WINDOW_MODE_MAXIMIZED) == -1, "maximized counts as windowed")
	check(GS.window_mode_to_set(true, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN) == -1, "exclusive counts as fullscreen")
	check(GS.window_mode_to_set(true, DisplayServer.WINDOW_MODE_MINIMIZED) == -1, "minimized left alone")
	check(GS.window_mode_to_set(false, DisplayServer.WINDOW_MODE_MINIMIZED) == -1, "minimized left alone (windowed)")
	check(GS.window_mode_to_set(true, W) == F, "windowed -> fullscreen")
	check(GS.window_mode_to_set(false, F) == W, "fullscreen -> windowed")
	check(GS.window_mode_to_set(false, W) == -1, "already windowed")
	set_option_flow()
	print("test_window_mode: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Through the real set_option: only Fullscreen / VSync changes touch the
## window. Fails if set_option goes back to calling apply() every time.
func set_option_flow() -> void:
	var gs: Node = GS.new()
	gs.path = "user://test_window_mode.cfg"  # never the player's settings
	var rec := DisplayRecorder.new()
	gs.display_stub = rec
	gs.set_option(&"tutorial_seen", true)
	gs.set_option(&"hints_seen", {"pot": 1})
	gs.set_option(&"tutorial_enabled", true)
	gs.set_option(&"sfx_volume", 0.5)
	check(rec.calls.is_empty(), "hint / tutorial / volume saves: no window calls (%s)" % str(rec.calls))
	gs.set_option(&"fullscreen", true)
	check(rec.calls == [["set_mode", DisplayServer.WINDOW_MODE_FULLSCREEN], ["set_vsync", true]], "fullscreen on: one mode change (%s)" % str(rec.calls))
	rec.calls.clear()
	rec.mode = DisplayServer.WINDOW_MODE_MINIMIZED
	gs.set_option(&"vsync", false)
	check(rec.calls == [["set_vsync", false]], "vsync while minimized: no mode change (%s)" % str(rec.calls))
	gs.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_window_mode.cfg"))


## Records window calls instead of making them.
class DisplayRecorder:
	var calls: Array = []
	var mode: int = DisplayServer.WINDOW_MODE_WINDOWED

	func get_mode() -> int:
		return mode

	func set_mode(m: int) -> void:
		calls.append(["set_mode", m])
		mode = m

	func set_vsync(on: bool) -> void:
		calls.append(["set_vsync", on])
