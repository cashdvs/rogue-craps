## Headless test: every Dealer event has lines, and the picker never repeats
## the same line twice in a row.
##
## Run:
##   godot --headless --path /workspace/dice/game --script res://tests/test_dealer_lines.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== The Gambler's Descent: dealer lines tests ===")
	var dl := DealerLines.from_json_file("res://resources/dealer/dealer_lines.json", 42)
	_check(dl != null, "lines: dealer_lines.json loads")
	if dl == null:
		quit(1)
		return
	for event in DealerLines.EVENTS:
		_check(dl.has_event(event) and dl.lines[event].size() >= 2, "lines: '%s' has at least 2 lines" % event)
		var prev := ""
		var no_repeat := true
		var seen := {}
		for i in 200:
			var line := dl.pick(event)
			if line == prev or line == "":
				no_repeat = false
			prev = line
			seen[line] = true
		_check(no_repeat, "picker: '%s' never repeats back-to-back over 200 picks" % event)
		_check(seen.size() == dl.lines[event].size(), "picker: '%s' uses every line" % event)
	_check(dl.pick(&"no_such_event") == "", "picker: unknown event returns an empty line")
	var a := DealerLines.from_json_file("res://resources/dealer/dealer_lines.json", 7)
	var b := DealerLines.from_json_file("res://resources/dealer/dealer_lines.json", 7)
	var same := true
	for i in 30:
		if a.pick(&"seven_out") != b.pick(&"seven_out"):
			same = false
	_check(same, "picker: same seed gives the same lines")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS  ", name)
	else:
		_failed += 1
		print("FAIL  ", name, ("  -> " + detail) if detail != "" else "")
