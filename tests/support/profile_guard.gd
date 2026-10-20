## Test helper: points RunProfile at a scratch user://test_profile_<name>.cfg
## and checks the real user://profile.cfg is untouched afterwards.
##   var guard := ProfileGuard.begin("run_screen")  ...  guard.end() -> bool
class_name ProfileGuard
extends RefCounted

var scratch: String = ""
var _before: String = ""


## Snapshot the real profile file and switch RunProfile to a fresh scratch file.
static func begin(name: String) -> ProfileGuard:
	var g := ProfileGuard.new()
	g._before = snapshot()
	g.scratch = "user://test_profile_%s.cfg" % name
	RunProfile.path = g.scratch
	g.wipe()
	return g


## The real file's state: "absent", or its modified time and MD5.
static func snapshot() -> String:
	if not FileAccess.file_exists(RunProfile.REAL_PATH):
		return "absent"
	return "%d:%s" % [FileAccess.get_modified_time(RunProfile.REAL_PATH), FileAccess.get_md5(RunProfile.REAL_PATH)]


## Delete the scratch file (if any).
func wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))


## Delete the scratch file, reset RunProfile.path; true if the real file is untouched.
func end() -> bool:
	wipe()
	RunProfile.path = ""
	return snapshot() == _before
