## Autoload "GameSettings": player options, saved to user://settings.cfg
## (ConfigFile) and applied on boot: Master / SFX / Music volume (0..1),
## fullscreen, VSync, throw sensitivity (multiplies flick speed), the Table 1
## tutorial toggle and whether it has been seen.
## Buses: default_bus_layout.tres has Master -> SFX, Music; missing buses are
## created at runtime (SfxManager does the same for SFX) so an existing
## layout from the Sound Designer is never replaced.
extends Node

signal changed(key: StringName)

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "options"
const BUSES := {&"master_volume": &"Master", &"sfx_volume": &"SFX", &"music_volume": &"Music"}
const SENSITIVITY_RANGE := Vector2(0.5, 2.0)

var path: String = DEFAULT_PATH
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var fullscreen: bool = false
var vsync: bool = true
var throw_sensitivity: float = 1.0
## Options toggle: show the Table 1 tutorial (turning it on again resets
## tutorial_seen so it plays once more).
var tutorial_enabled: bool = true
var tutorial_seen: bool = false
## Debug throw overlay on the Bonfire table (flick px/s, launch m/s, curve).
## Session only, never saved. Also on with the user arg `-- --throw-debug`.
var throw_debug: bool = false


func _ready() -> void:
	throw_debug = OS.get_cmdline_user_args().has("--throw-debug")
	ensure_buses()
	load_settings()
	apply()


const KEYS: Array[StringName] = [&"master_volume", &"sfx_volume", &"music_volume", &"fullscreen", &"vsync", &"throw_sensitivity",
	&"tutorial_enabled", &"tutorial_seen"]


func defaults() -> Dictionary:
	return {&"master_volume": 1.0, &"sfx_volume": 1.0, &"music_volume": 0.8, &"fullscreen": false, &"vsync": true, &"throw_sensitivity": 1.0,
		&"tutorial_enabled": true, &"tutorial_seen": false}


func reset_to_defaults() -> void:
	var d := defaults()
	for k in KEYS:
		set(k, d[k])


## Sets one option, applies it and saves.
func set_option(key: StringName, value: Variant) -> void:
	if not KEYS.has(key):
		return
	if key == &"throw_sensitivity":
		value = clampf(float(value), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
	elif BUSES.has(key):
		value = clampf(float(value), 0.0, 1.0)
	set(key, value)
	if key == &"tutorial_enabled" and bool(value):
		tutorial_seen = false
	apply()
	save_settings()
	changed.emit(key)


func save_settings() -> Error:
	var cf := ConfigFile.new()
	for k in KEYS:
		cf.set_value(SECTION, String(k), get(k))
	return cf.save(path)


## Loads saved options (keeps defaults for anything missing). False if no file.
func load_settings() -> bool:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return false
	var d := defaults()
	for k in KEYS:
		var v: Variant = cf.get_value(SECTION, String(k), d[k])
		if typeof(v) != typeof(d[k]) and not (typeof(d[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
			v = d[k]
		set(k, v)
	throw_sensitivity = clampf(throw_sensitivity, SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
	return true


func apply() -> void:
	ensure_buses()
	for k: StringName in BUSES:
		var idx := AudioServer.get_bus_index(BUSES[k])
		if idx < 0:
			continue
		var v := float(get(k))
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not OS.has_feature("web") and not is_mobile():
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


static func ensure_buses() -> void:
	for bus: StringName in [&"SFX", &"Music"]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, &"Master")


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


## Quit makes sense only on desktop builds.
static func can_quit() -> bool:
	return not (OS.has_feature("web") or is_mobile())


## Fullscreen toggle is meaningless on mobile.
static func can_window() -> bool:
	return not is_mobile()
