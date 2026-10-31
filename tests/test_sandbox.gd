## Headless tests for the dev sandbox: each CLI mode builds its preset run
## on the right screen with the table_goals_v1 target, the boss picker, and
## the menu launching RunScreen.
## Run: godot --headless --path . --script res://tests/test_sandbox.gd
extends SceneTree

const S := MapRun.Screen
const NT := MapGenData.NodeType
const TARGETS := [[300, 400, 700], [1000, 1300, 2500], [2500, 3000, 3500]]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("=== Dice of the Damned: sandbox tests ===")
	var guard := ProfileGuard.begin("sandbox")
	var data := load("res://resources/map/bonfire_run.tres") as RunData
	_check(SandboxPreset.from_args(PackedStringArray(["--foo=1"])) == null, "no --sandbox flag: no preset")
	var p := SandboxPreset.from_args(PackedStringArray(["--sandbox=boss", "--boss=pit_boss", "--floor=2", "--seed=123"]))
	_check(p != null and p.event == &"boss" and p.boss_id == &"pit_boss" and p.floor_num == 2 and p.seed_value == 123, "CLI args parse")
	for f in 3:
		var kinds := {&"table": NT.TABLE, &"elite": NT.ELITE, &"boss": NT.BOSS}
		for i in 3:
			var ev: StringName = kinds.keys()[i]
			var r := SandboxPreset.from_args(PackedStringArray(["--sandbox=%s" % ev, "--floor=%d" % (f + 1), "--seed=7"])).build(data)
			_check(r.screen == S.TABLE and r.table_type == kinds[ev], "F%d %s: on the table screen" % [f + 1, ev])
			_check(r.floor_index == f and r.goal.target == TARGETS[f][i], "F%d %s: target %d" % [f + 1, ev, TARGETS[f][i]])
			_check(r.progress.dice.size() == 5 and r.table_setup().table_dice.size() == 5, "F%d %s: 5-die bag" % [f + 1, ev])
		var shop := SandboxPreset.from_args(PackedStringArray(["--sandbox=shop", "--floor=%d" % (f + 1)])).build(data)
		_check(shop.screen == S.SHOP and not shop.shop_dice.is_empty(), "F%d shop: stocked shop screen" % (f + 1))
		for id in SandboxPreset.boss_ids(data, f + 1):
			var b := SandboxPreset.from_args(PackedStringArray(["--sandbox=boss", "--boss=%s" % id, "--floor=%d" % (f + 1)])).build(data)
			_check(b.boss.resource_path.get_file().get_basename() == String(id) and b.goal.is_boss and b.rules.has(b.boss), "F%d boss picker: %s" % [f + 1, id])
	_check(SandboxPreset.boss_ids(data, 1) == [&"madame_shuffle", &"pit_boss", &"ashmouth"], "F1 boss pool")
	var a := SandboxPreset.from_args(PackedStringArray(["--sandbox=table", "--seed=5"])).build(data)
	var b2 := SandboxPreset.from_args(PackedStringArray(["--sandbox=table", "--seed=5"])).build(data)
	_check(a.table_setup().seed_value == b2.table_setup().seed_value, "same seed: same table seed")
	var menu: SandboxScreen = (load("res://scenes/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.boss_pick.item_count == 4, "menu: boss picker lists the floor's 3 bosses")
	menu.event_pick.select(2)
	menu.boss_pick.select(2)
	menu.launch(menu.current_preset())
	await process_frame
	_check(menu.run_screen != null and menu.run_screen.run.screen == S.TABLE and menu.run_screen.run.boss.id == &"pit_boss", "menu: launches the boss table")
	menu.run_screen.queue_free()
	menu.queue_free()
	await process_frame
	_check(guard.end(), "profile: the real user://profile.cfg is untouched")
	# Gate (version.cfg dev_tools): off = title, no button, --sandbox= ignored.
	var boot := PackedStringArray(["--sandbox=boss", "--boss=pit_boss"])
	_check(SandboxScreen.enabled(true) and not SandboxScreen.enabled(false), "gate: enabled only with the flag")
	_check(SandboxScreen.entry_redirect(false) == SandboxScreen.TITLE_SCENE, "flag off: sandbox scene goes to the title")
	_check(SandboxScreen.entry_redirect(true) == "", "flag on: sandbox scene stays")
	_check(SandboxScreen.boot_target(false, boot) == "", "flag off: boot ignores --sandbox=")
	_check(SandboxScreen.boot_target(true, boot) == SandboxScreen.SCENE, "flag on: boot --sandbox= opens the sandbox")
	_check(SandboxScreen.boot_target(true, PackedStringArray()) == "", "flag on: no flag, no boot jump")
	var rel_menu := VBoxContainer.new()
	var rel_title := Control.new()
	SandboxScreen.title_hook(rel_title, rel_menu, false)
	_check(rel_menu.get_child_count() == 0 and not SandboxScreen._boot_done, "flag off: no title button, no boot jump")
	rel_menu.free()
	rel_title.free()
	_check(Version.dev_tools(), "repo version.cfg: dev_tools on")
	var off := "user://sandbox_off_version.cfg"
	var f := FileAccess.open(off, FileAccess.WRITE)
	f.store_string("[version]\nmajor_minor=\"0.1\"\npatch=2\nsha=\"dev\"\ndev_tools=false\n")
	f.close()
	Version.load_file(off)
	_check(not Version.dev_tools() and SandboxScreen.boot_target(Version.dev_tools(), boot) == "", "dev_tools=false: --sandbox= ignored at boot")
	var off_title := (load("res://scenes/title.tscn") as PackedScene).instantiate() as Control
	root.add_child(off_title)
	await process_frame
	_check(off_title.find_child("SandboxButton", true, false) == null and not SandboxScreen._boot_done, "dev_tools=false: title has no SANDBOX button, no jump")
	off_title.queue_free()
	var off_menu: SandboxScreen = (load("res://scenes/sandbox.tscn") as PackedScene).instantiate()
	root.add_child(off_menu)
	await process_frame
	_check(off_menu.event_pick == null, "dev_tools=false: the sandbox scene builds no menu (redirects to the title)")
	off_menu.queue_free()
	await process_frame
	Version.load_file()
	DirAccess.remove_absolute(off)
	# Unknown event: push_error + visible fallback to a regular table.
	var bad := SandboxPreset.from_args(PackedStringArray(["--sandbox=nope"]))
	var br := bad.build(data)
	_check(bad.event == &"table" and br.screen == S.TABLE and br.table_type == NT.TABLE and br.goal.target == 300, "unknown --sandbox=: falls back to a regular table")
	var title := (load("res://scenes/title.tscn") as PackedScene).instantiate() as Control
	root.add_child(title)
	await process_frame
	_check(title.find_child("SandboxButton", true, false) != null, "title: debug build shows the SANDBOX button")
	title.queue_free()
	await process_frame
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)
