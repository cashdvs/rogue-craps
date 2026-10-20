## strings_v1 (Game Designer): no burn or fire words in player-facing text.
## Scans every string literal in the game scripts and resources for the
## whole words burn / burns / burned / fire / flame. Skipped (not player
## text): comments, StringName ids (&"..."), node paths and file paths, and
## single-word ids with no space (shader params, signal names, props such
## as the bonfire / brazier pieces).
##   godot --headless --path . --script res://tests/test_no_burn_words.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
## The Bonfire game's code and content. Not scanned: the older POC / greybox
## tables (scripts/table, scripts/table3d, poc_table.gd), which the run
## doesn't use.
const DIRS := ["res://scripts/bonfire", "res://scripts/core", "res://scripts/data",
	"res://scripts/map", "res://scripts/ui", "res://resources"]
const SKIP_FILES := ["res://scripts/core/poc_table.gd"]
## Content names the Game Designer keeps (a die and a twist), not prose.
const NAMES := ["Twin Flame", "Heavy Burn"]
## Known prose still to reword, reported to the Game Designer (not in
## strings_v1's list). Keep this empty once it is reworded.
const KNOWN := ["The ink burns into your skin."]
const WORDS := "\\b(burn|burns|burned|burning|fire|flame|flames)\\b"


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	var word := RegEx.create_from_string("(?i)" + WORDS)
	# A string literal that isn't a StringName: "..." not preceded by & or ^.
	var lit := RegEx.create_from_string("(?<![&^])\"((?:[^\"\\\\]|\\\\.)*)\"")
	var hits: Array[String] = []
	var files := 0
	for d in DIRS:
		for path in _files(d):
			if SKIP_FILES.has(path):
				continue
			files += 1
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				var line := lines[i].strip_edges()
				if line.begins_with("#"):
					continue  # a comment
				var code := lines[i]
				for m in lit.search_all(code):
					var s := m.get_string(1)
					if not s.contains(" "):
						continue  # an id, path or prop name, not a sentence
					if KNOWN.has(s):
						continue
					for n in NAMES:
						s = s.replace(n, "")
					if word.search(s) != null:
						hits.append("%s:%d %s" % [path, i + 1, s])
	check(files > 50, "scanned %d files" % files)
	check(hits.is_empty(), "no burn / fire words in player text:\n  %s" % "\n  ".join(hits))
	print("test_no_burn_words: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Every .gd and .tres file under dir (recursive).
func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for sub in da.get_directories():
		out.append_array(_files(dir + "/" + sub))
	for f in da.get_files():
		if f.ends_with(".gd") or f.ends_with(".tres"):
			out.append(dir + "/" + f)
	return out
