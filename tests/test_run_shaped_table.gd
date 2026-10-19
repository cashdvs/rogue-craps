## #50 QA blocker regression: the real Bonfire table (run mode) with a Powder
## Keg and a Ferryman's Coin in the bag must run frames and a throw with no
## SCRIPT ERROR. The table runs in a child process (tests/support/
## shaped_table_child.gd) so its stderr can be grepped.
##   godot --headless --path . --script res://tests/test_run_shaped_table.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _initialize() -> void:
	var out: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/support/shaped_table_child.gd"], out, true)
	var log: String = "".join(out)
	var errors: PackedStringArray = []
	for line in log.split("\n"):
		if line.contains("SCRIPT ERROR") or line.contains("Parse Error"):
			errors.append(line)
		if line.begins_with("CHILD_OK") or line.begins_with("CHILD_FAIL"):
			_check(line.begins_with("CHILD_OK"), line.trim_prefix("CHILD_FAIL "))
	_check(code == 0 and log.contains("CHILD_DONE"), "table child ran to the end (exit %d)" % code)
	_check(errors.is_empty(), "no SCRIPT ERROR with a Keg / Coin on the table (%d)" % errors.size())
	for e in errors.slice(0, 5):
		print("  ", e)
	if _failed > 0:
		print(log)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
