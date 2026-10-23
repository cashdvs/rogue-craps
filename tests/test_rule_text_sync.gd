## Rule text drift guard (QA on #137): every boss cheat and Elite twist in
## TableRules.INFO must say exactly what its resources/map/rules/<id>.tres
## description says (both follow design/strings_v1.md). A .tres "{hands}"
## is compared as 4 (Short Table, CUT in strings_v1, keeps INFO "4 hands.").
## Skipped: a .tres whose id is another handler's (madame_shuffle runs on
## pit_boss as a stopgap).
##   godot --headless --path . --script res://tests/test_rule_text_sync.gd
extends SceneTree

const RULES := "res://resources/map/rules/"
var _passed: int = 0
var _failed: int = 0


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var seen := 0
	for id in TableRules.INFO:
		var info: Array = TableRules.INFO[id]
		var path := RULES + String(id) + ".tres"
		if not ResourceLoader.exists(path):
			continue
		var r := load(path) as RunRuleData
		_check(r != null, "%s loads" % path)
		if r == null or r.id != id:
			continue  # stopgap on another handler (madame_shuffle -> pit_boss)
		seen += 1
		_check(r.description.replace("{hands}", "4") == info[1], "%s: INFO %s == .tres %s" % [id, info[1], r.description])
	_check(seen >= 14, "covered %d cheats + twists" % seen)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
