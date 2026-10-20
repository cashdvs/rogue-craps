## Per-profile run flags that outlive a run (design/first_time_clarity_v1.md
## §1): for now, whether the map key has opened by itself once. Saved to
## user://profile.cfg (ConfigFile, section "first_time"); a file of its own
## because GameSettings rewrites user://settings.cfg whole on every save.
##
## Tests and tools never touch the real file: set `path` to a scratch
## user://test_profile_*.cfg (tests/support/profile_guard.gd does this and
## cleans up). Any run started with --script (a test or tool main loop)
## that doesn't set `path` keeps the flags in memory and writes no file.
class_name RunProfile
extends RefCounted

const SECTION := "first_time"
## The player's real profile file.
const REAL_PATH := "user://profile.cfg"
## Override for tests and tools ("" = automatic, see file_path()).
static var path: String = ""
## The in-memory profile of a --script run without `path`.
static var _memory: Dictionary = {}


## The file in use: `path` if set; "" (memory only) when the main loop is a
## script (godot --script, i.e. tests and tools); else REAL_PATH.
static func file_path() -> String:
	if path != "":
		return path
	var ml := Engine.get_main_loop()
	return "" if ml != null and ml.get_script() != null else REAL_PATH


## Has the map key already opened by itself on this profile?
static func map_key_seen() -> bool:
	var p := file_path()
	if p == "":
		return bool(_memory.get("map_key_seen", false))
	var cf := ConfigFile.new()
	return cf.load(p) == OK and bool(cf.get_value(SECTION, "map_key_seen", false))


## Remember that the map key has opened once (keeps other keys in the file).
static func mark_map_key_seen() -> Error:
	var p := file_path()
	if p == "":
		_memory["map_key_seen"] = true
		return OK
	var cf := ConfigFile.new()
	cf.load(p)
	cf.set_value(SECTION, "map_key_seen", true)
	return cf.save(p)
