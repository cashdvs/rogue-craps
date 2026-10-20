## strings_v1.md data and labels: the details tooltip line on dice and mods,
## SealText, the bounty names on every floor, and no "burn" on the table HUD.
##   godot --headless --path . --script res://tests/test_strings_v1.gd
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
	var cracked := load("res://resources/dice/special/cracked.tres") as SpecialDieData
	check(cracked.details == "A shattered die is gone for the run.", "cracked details (%s)" % cracked.details)
	check(cracked.tooltip() == cracked.description + "\n" + cracked.details, "tooltip = description + details")
	var mirror := load("res://resources/dice/special/mirror.tres") as SpecialDieData
	check(mirror.description == "After it lands, it copies the nearest other die." and mirror.details == "Alone, it keeps its own roll.", "mirror text")
	var kindling := load("res://resources/mods/kindling.tres") as FaceModData
	check(kindling.details == "Used up by your next throw.", "kindling details")
	var heavy := load("res://resources/mods/heavy.tres") as FaceModData
	check(heavy.details == "" and heavy.tooltip() == heavy.description, "no details: tooltip is the description")
	check(SealText.describe(&"trips") == "Levels up Trips: +15 base and +1 mult.", "Seal text")
	check(SealText.describe(&"black") == "+1 level to the combo you have banked most this run.", "rare Seal text")
	check(SealText.describe(&"nope") == "", "unknown Seal: empty")
	check(SealText.SEALS.size() == 9 and SealText.RARE.size() == 3, "9 Seals, 3 rare Seals")
	for f in ["floor_1", "floor_2", "floor_3"]:
		var txt := FileAccess.get_file_as_string("res://resources/map/%s.tres" % f)
		check(not txt.contains("Pot three in a row") and not txt.contains("Pot four in a row") and not txt.contains("pot four in a row"), "%s: 'numbers in a row'" % f)
		check(not txt.contains("\"Triple\"") and not txt.contains("\"Two Pairs\""), "%s: Trips / Two Pair" % f)
	check(BustRisk.prompt(3, {"text": "1 in 12"}) == "3 cold dice: 1 in 12 chance nothing lights", "rethrow prompt")
	check(BustRisk.prompt(1, {"text": BustRisk.odds_text(1.0)}) == "1 cold die: a sure bust", "sure bust")
	# Can't bust: "it" for one die, "they" for more.
	check(BustRisk.prompt(1, {"text": BustRisk.odds_text(0.0)}) == "1 cold die: it can't bust", "can't bust, 1 die: 'it' (%s)" % BustRisk.prompt(1, {"text": BustRisk.odds_text(0.0)}))
	check(BustRisk.prompt(2, {"text": BustRisk.odds_text(0.0)}) == "2 cold dice: they can't bust", "can't bust, 2 dice: 'they' (%s)" % BustRisk.prompt(2, {"text": BustRisk.odds_text(0.0)}))
	# The bust status line (sentence case; the big BUST callout art stays caps).
	check(FileAccess.get_file_as_string("res://scripts/bonfire/bonfire_3d.gd").contains("\"Nothing lit. Bust: pot of %d lost, -%d Soul.\""), "bust line text")
	# Pause menu leave-confirm line (strings_v1, exact).
	check(FileAccess.get_file_as_string("res://scripts/ui/pause_menu.gd").contains("\"The hand in play is lost. Every unclaimed bounty costs Soul, like running out of hands.\""), "pause leave-confirm text")
	# The table HUD after a throw: no player-facing "burn" anywhere.
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.tutorial_override = 0
	s.test_speed = 10.0
	root.add_child(s)
	await process_frame
	await process_frame
	var bad: Array[String] = []
	for n in s.find_children("*", "Label", true, false) + s.find_children("*", "Button", true, false):
		var tx := String(n.get("text")).to_lower()
		if tx.contains("burn") or tx.contains("catch fire") or tx.contains("ignite"):
			bad.append(tx)
	check(bad.is_empty(), "no burn wording on the table (%s)" % str(bad))
	check(s.bhud.throw_button.text.begins_with("Throw") and s.bhud.bank_button.text == "Bank" and s.bhud.leave_button.text == "Leave table", "button labels (%s / %s / %s)" % [s.bhud.throw_button.text, s.bhud.bank_button.text, s.bhud.leave_button.text])
	s.queue_free()
	await process_frame
	print("test_strings_v1: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
