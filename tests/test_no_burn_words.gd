## strings_v1 (Game Designer): no burn or fire words in player-facing text.
## Scans every string literal in the game scripts and resources for the
## whole words burn / burns / burned / fire / flame. Skipped (not player
## text): comments, StringName ids (&"..."), file and node paths, node
## names (`name = "..."`, get_node / find_child), and one-word ids
## (snake_case or lower case: shader params, signal names, props such as
## the bonfire / brazier pieces). A one-word label like "Burn" or "BURN"
## (starts with a capital) IS player text and is checked (QA nit).
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
## Content names the Game Designer keeps (the Twin Flame die), not prose.
const NAMES := ["Twin Flame"]
## Still to rename, owned by Systems Dev (run data): the Heavy Burn twist's
## display name. Only these exact spots are let through; remove them once
## it is renamed.
const PENDING := {
	"res://resources/map/rules/heavy_burn.tres": "Heavy Burn",
	"res://scripts/core/rules/table_rules.gd": "Heavy Burn",
}
## Lines that name a node, not show text.
const NODE_NAME := "(\\bname\\s*=|get_node|find_child|has_node|NodePath|\\$\")"
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
	var node_line := RegEx.create_from_string(NODE_NAME)
	# A one-word label: starts with a capital (Burn, BURN), letters only.
	var label_word := RegEx.create_from_string("^[A-Z][A-Za-z]*[!.]?$")
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
						# One word: an id / path / node name, unless it reads
						# like a label ("Burn") on a line that isn't naming a node.
						if label_word.search(s) == null or node_line.search(code) != null:
							continue
					if PENDING.get(path, "") == s:
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
