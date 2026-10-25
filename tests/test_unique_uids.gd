## Headless test: every uid in the project's .import and .uid files is unique (issue #173). A duplicate uid
## makes Godot load the wrong resource (e.g. Collector's GLBs carried Straight Man's uids before #169).
##
## Run:
##   godot --headless --path . --script res://tests/test_unique_uids.gd
extends SceneTree

const SKIP_DIRS := [".godot", ".git", "addons/.git"]

var _seen := {}
var _files := 0


func _init() -> void:
	print("=== Dice of the Damned: unique uid check ===")
	_scan("res://")
	var dupes := 0
	for uid: String in _seen:
		var paths: Array = _seen[uid]
		if paths.size() > 1:
			dupes += 1
			print("  FAIL duplicate %s in %s" % [uid, ", ".join(paths)])
	if dupes == 0:
		print("  ok %d .import/.uid files, %d uids, all unique" % [_files, _seen.size()])
	print("=== %d passed, %d failed ===" % [1 if dupes == 0 else 0, dupes])
	quit(0 if dupes == 0 else 1)


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	for sub in d.get_directories():
		var p := dir.path_join(sub)
		if p.trim_prefix("res://") in SKIP_DIRS or sub.begins_with("."):
			continue
		_scan(p)
	for f in d.get_files():
		var p := dir.path_join(f)
		var uid := ""
		if f.ends_with(".import"):
			for line in FileAccess.get_file_as_string(p).split("\n"):
				if line.begins_with("uid="):
					uid = line.trim_prefix("uid=").strip_edges().trim_prefix("\"").trim_suffix("\"")
					break
		elif f.ends_with(".uid"):
			uid = FileAccess.get_file_as_string(p).strip_edges()
		else:
			continue
		_files += 1
		if uid.begins_with("uid://"):
			_seen.get_or_add(uid, []).append(p.trim_prefix("res://"))
