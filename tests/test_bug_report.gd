## BugReport: the mailto, its body with and without a run, the bag text, the
## screenshot path, and the pause menu's Report a bug button.
##   godot --headless --path . --script res://tests/test_bug_report.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	var m := BugReport.build_mailto("Bug report - v0.1.2 (abc1234)", "What happened:\n\nx & y")
	check(m.begins_with("mailto:tinyanvilgames@mail.grokbot.com?subject="), "address (%s)" % m)
	check(m.contains("subject=Bug%20report%20-%20v0.1.2%20%28abc1234%29"), "subject encoded (%s)" % m)
	check(m.contains("&body=What%20happened%3A%0A%0Ax%20%26%20y"), "body encoded (%s)" % m)
	check(m.count("&") == 1 and not m.contains(" ") and not m.contains("\n"), "no raw space / newline / extra &")
	check(BugReport.build_mailto(Version.bug_subject(), "").contains(Version.bug_subject().uri_encode()), "uses Version.bug_subject()")
	# No run: just the header lines.
	var b := BugReport.build_body("v0.1.2 (dev)", "Linux headless")
	var lines := b.split("\n")
	check(lines[0] == "What happened:" and lines[1] == "" and lines[2] == "", "blank What happened first (%s)" % str(lines))
	check(b.contains("Version: v0.1.2 (dev)") and b.contains("Platform: Linux headless"), "version + platform")
	check(not b.contains("Seed:") and not b.contains("Bag:"), "no run: run lines omitted")
	# A live run.
	var run := MapRun.new(load("res://resources/map/bonfire_run.tres") as RunData, 4242)
	check(BugReport.current_run() == run, "MapRun registers itself")
	run.progress.dice[0].faces[2] = &"heavy"
	var rb := BugReport.build_body("v0.1.2 (dev)", "Linux", run)
	check(rb.contains("Seed: 4242"), "seed (%s)" % rb)
	check(rb.contains("Table: Floor 1"), "floor")
	check(rb.contains("Boss: " + run.boss_name()), "boss")
	check(rb.contains("Embers: %d / Soul: %d of %d" % [run.progress.embers, run.progress.soul, run.progress.max_soul]), "embers / soul")
	check(rb.contains("Bag: ") and rb.contains("[heavy]"), "bag with mods (%s)" % rb)
	check(BugReport.bag_text([]) == "none", "empty bag")
	BugReport.set_run(null)
	check(BugReport.current_run() == null, "cleared run")
	var p := BugReport.shot_path({"year": 2026, "month": 10, "day": 31, "hour": 9, "minute": 5, "second": 7})
	check(p == "user://bug_reports/20261031-090507.png", "shot path (%s)" % p)
	# Pause menu: one Report a bug button.
	var pm := PauseMenu.new()
	root.add_child(pm)
	var found := 0
	for n in pm.find_children("*", "Button", true, false):
		if (n as Button).text == BugReport.BUTTON:
			found += 1
	check(found == 1, "pause menu has one Report a bug button (%d)" % found)
	var t := BugReport.toast(pm, BugReport.SAVED % "/tmp/x.png")
	check(t.text == "Screenshot saved, attach it: /tmp/x.png", "toast text")
	pm.queue_free()
	await process_frame
	print("test_bug_report: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
