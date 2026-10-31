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
		if (n as Button).text == "REPORT A BUG":
			found += 1
	check(found == 1, "pause menu has one Report a bug button (%d)" % found)
	var t := BugReport.toast(pm, BugReportStrings.get_text("bug_report_saved").format({"path": "/tmp/x.png"}))
	check(t.text == "Screenshot saved, attach it: /tmp/x.png", "toast text")
	# strings_v1 golden rows, loaded by id.
	check(BugReportStrings.get_text("bug_report_button") == "REPORT A BUG", "bug_report_button")
	check(BugReportStrings.get_text("bug_report_what") == "What happened:", "bug_report_what")
	check(BugReportStrings.get_text("bug_report_saved") == "Screenshot saved, attach it: {path}", "bug_report_saved")
	check(BugReportStrings.get_text("bug_report_no_mail") == "No mail app: report copied, email it to tinyanvilgames@mail.grokbot.com", "bug_report_no_mail")
	check(BugReportStrings.get_text("nope") == "", "unknown id: empty")
	# send(): success opens the mailto and copies nothing.
	var opened: Array[String] = []
	var copied: Array[String] = []
	BugReport.clipboard = func(tx: String) -> void: copied.append(tx)
	BugReport.opener = func(url: String) -> int:
		opened.append(url)
		return OK
	check(BugReport.send(pm, "Subj", "Body") == OK and opened.size() == 1 and opened[0] == BugReport.build_mailto("Subj", "Body") and copied.is_empty(), "send ok: opens, no copy")
	# Failure: copies address + subject + body and toasts NO_MAIL.
	BugReport.opener = func(_url: String) -> int: return ERR_CANT_OPEN
	check(BugReport.send(pm, "Subj", "What happened:\n\nBody") == ERR_CANT_OPEN, "send fail returns error")
	check(copied.size() == 1 and copied[0] == "To: tinyanvilgames@mail.grokbot.com\nSubject: Subj\n\nWhat happened:\n\nBody", "fail: report copied (%s)" % str(copied))
	var toasts := root.find_children("BugReportToast", "Label", true, false)
	var hit := false
	for l in toasts:
		hit = hit or (l as Label).text == "No mail app: report copied, email it to tinyanvilgames@mail.grokbot.com"
	check(hit, "fail: no-mail toast shown")
	# report() headless: no frame wait, returns "" (no shot) and calls the opener.
	opened.clear()
	BugReport.opener = func(url: String) -> int:
		opened.append(url)
		return OK
	var shot: String = await BugReport.report(pm)
	check(shot == "" and opened.size() == 1 and opened[0].begins_with("mailto:tinyanvilgames@mail.grokbot.com?subject=" + Version.bug_subject().uri_encode()), "report() completes headless and opens the mailto (%s)" % str(opened))
	BugReport.opener = Callable()
	BugReport.clipboard = Callable()
	for l in toasts:
		l.get_parent().queue_free()
	pm.queue_free()
	await process_frame
	print("test_bug_report: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
