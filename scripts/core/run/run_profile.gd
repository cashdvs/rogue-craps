## Per-profile run flags that outlive a run (design/first_time_clarity_v1.md
## §1): for now, whether the map key has opened by itself once. Saved to
## user://profile.cfg (ConfigFile, section "first_time"); a file of its own
## because GameSettings rewrites user://settings.cfg whole on every save.
class_name RunProfile
extends RefCounted

const SECTION := "first_time"
## Tests point this at a scratch file.
static var path: String = "user://profile.cfg"


## Has the map key already opened by itself on this profile?
static func map_key_seen() -> bool:
	var cf := ConfigFile.new()
	return cf.load(path) == OK and bool(cf.get_value(SECTION, "map_key_seen", false))


## Remember that the map key has opened once (keeps other keys in the file).
static func mark_map_key_seen() -> Error:
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value(SECTION, "map_key_seen", true)
	return cf.save(path)
