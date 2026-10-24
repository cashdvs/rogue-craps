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
	print("test_window_mode: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
