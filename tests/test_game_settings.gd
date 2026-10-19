## GameSettings (autoload script): save/load round trip via ConfigFile,
## clamping, bad-file fallback, buses and volume apply.
##   godot --headless --path . --script res://tests/test_game_settings.gd
extends SceneTree

const GS := preload("res://scripts/settings/game_settings.gd")
const PATH := "user://test_settings_roundtrip.cfg"

var _passed: int = 0
var _failed: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var a := GS.new()
	a.path = PATH
	check(not a.load_settings(), "no file yet: load returns false, defaults kept")
	check(a.throw_sensitivity == 1.0 and a.vsync and not a.fullscreen, "defaults")
	a.set_option(&"master_volume", 0.6)
	a.set_option(&"sfx_volume", 0.3)
	a.set_option(&"music_volume", 0.0)
	a.set_option(&"fullscreen", true)
	a.set_option(&"vsync", false)
	a.set_option(&"throw_sensitivity", 1.7)
	check(FileAccess.file_exists(PATH), "set_option saves to the config file")
	var b := GS.new()
	b.path = PATH
	check(b.load_settings(), "load finds the file")
	check(is_equal_approx(b.master_volume, 0.6) and is_equal_approx(b.sfx_volume, 0.3) and b.music_volume == 0.0, "volumes round-trip")
	check(b.fullscreen and not b.vsync and is_equal_approx(b.throw_sensitivity, 1.7), "fullscreen, vsync, sensitivity round-trip")
	b.set_option(&"throw_sensitivity", 9.0)
	check(b.throw_sensitivity == 2.0, "sensitivity clamps to 0.5-2.0")
	b.set_option(&"sfx_volume", -1.0)
	check(b.sfx_volume == 0.0, "volume clamps to 0..1")
	# Buses and apply.
	check(AudioServer.get_bus_index(&"SFX") != -1 and AudioServer.get_bus_index(&"Music") != -1, "SFX and Music buses exist")
	b.set_option(&"sfx_volume", 0.5)
	var sfx := AudioServer.get_bus_index(&"SFX")
	check(absf(AudioServer.get_bus_volume_db(sfx) - linear_to_db(0.5)) < 0.01 and not AudioServer.is_bus_mute(sfx), "SFX volume applied to the bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music at 0 mutes its bus")
	check(AudioServer.get_bus_send(sfx) == &"Master", "SFX routes to Master")
	# A broken value falls back to the default.
	var cf := ConfigFile.new()
	cf.set_value("options", "throw_sensitivity", "lots")
	cf.set_value("options", "vsync", true)
	cf.save(PATH)
	var c := GS.new()
	c.path = PATH
	c.load_settings()
	check(c.throw_sensitivity == 1.0 and c.vsync, "a bad value loads as the default")
	check(GS.can_quit(), "Quit allowed on this desktop build")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	a.free()
	b.free()
	c.free()
	print("test_game_settings: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
