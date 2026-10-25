## Boss dealer swap (BonfireDealerArt) on the real Bonfire3D table:
## a boss table shows that boss at Smiles' spot and no Smiles; a normal
## table shows Smiles; Ashmouth's puffs follow Reduced motion and his scene
## outlives a swap until ~1.75 s into his taunt.
##   godot --headless --path . --script res://tests/test_boss_dealer_swap.gd
extends "res://tests/onboarding_test_base.gd"

const RULES := "res://resources/map/rules/%s.tres"
## Boss rule file -> art folder it must show.
const BOSSES := {
	"pit_boss": "pit_boss", "madame_shuffle": "shuffle", "ashmouth": "ashmouth",
	"straight_man": "straight_man", "collector": "collector", "bloodletter": "bloodletter",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	await _normal_table_shows_smiles()
	await _elite_twist_keeps_smiles()
	for rule: String in BOSSES:
		await _boss_table_swaps(rule, BOSSES[rule])
	await _floor3_boss_without_art_keeps_smiles()
	await _ashmouth_reduced_motion()
	await _taunt_plays_clip()
	await _ashmouth_kept_alive_on_swap()
	print("test_boss_dealer_swap: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## A table set up the way the run does it: RunRuleData -> RunTableSetup.rule_entries().
func _table_with(rule_files: Array) -> Bonfire3D:
	var st := TableSetup.sandbox(t, 5)
	var rts := RunTableSetup.new()
	for f: String in rule_files:
		rts.rules.append(load(RULES % f) as RunRuleData)
	st.rules = rts.rule_entries()
	return await make_table(0, st)


## Every dealer scene (Smiles or boss) under the table, by scene file.
func _dealer_scenes(s: Node) -> Array:
	return s.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool:
		return n.scene_file_path.begins_with("res://art/models/characters/") and n.scene_file_path.ends_with(".tscn"))


func _check_only(s: Bonfire3D, folder: String, label: String) -> void:
	var scenes := _dealer_scenes(s)
	check(scenes.size() == 1, "%s: exactly one dealer scene (%d)" % [label, scenes.size()])
	if scenes.is_empty():
		return
	var n := scenes[0] as Node3D
	check(n.scene_file_path.get_file().get_basename().trim_suffix("_mobile") == folder, "%s: shows %s (%s)" % [label, folder, n.scene_file_path])
	check(n.position.is_equal_approx(BonfireDealerArt.DEALER_SPOT), "%s: stands at the dealer spot (%s)" % [label, n.position])
	check(n.is_visible_in_tree(), "%s: dealer scene visible" % label)
	var smiles_shown := scenes.any(func(x: Node) -> bool: return x.scene_file_path.contains("/smiles/"))
	check(smiles_shown == (folder == "smiles"), "%s: Smiles shown only on non-boss tables" % label)
	# The greybox bust is hidden (never a second dealer); the rake stays.
	check(not s.dealer.head.visible, "%s: greybox bust hidden" % label)
	check(s.dealer.rake.visible, "%s: rake still on the rail" % label)
	check(s.dealer_art.art_id == folder, "%s: art_id %s (%s)" % [label, folder, s.dealer_art.art_id])


func _normal_table_shows_smiles() -> void:
	var s := await _table_with([])
	_check_only(s, "smiles", "normal table")
	s.queue_free()
	await process_frame


func _elite_twist_keeps_smiles() -> void:
	var s := await _table_with(["cold_hands"])
	_check_only(s, "smiles", "Elite (Cold Hands)")
	s.queue_free()
	await process_frame


func _boss_table_swaps(rule: String, folder: String) -> void:
	var s := await _table_with([rule])
	_check_only(s, folder, "boss " + rule)
	s.queue_free()
	await process_frame


## Baron Vig (floor 3) has no dealer scene yet: Smiles keeps the table.
func _floor3_boss_without_art_keeps_smiles() -> void:
	var s := await _table_with(["baron_vig"])
	_check_only(s, "smiles", "boss baron_vig (no art yet)")
	s.queue_free()
	await process_frame


func _ashmouth_reduced_motion() -> void:
	var s := await _table_with(["ashmouth"])
	var fx := s.dealer_art.puff_fx as AshmouthPuffFx
	check(fx != null, "Ashmouth: AshmouthPuffFx found")
	if fx != null:
		s.set_reduced_motion(true)
		await process_frame
		check(fx.reduced_motion, "Ashmouth: puff reduced_motion on with the table")
		s.set_reduced_motion(false)
		await process_frame
		check(not fx.reduced_motion, "Ashmouth: puff reduced_motion off with the table")
	s.queue_free()
	await process_frame


## A table taunt (Table3D.taunted) plays the dealer's taunt clip.
func _taunt_plays_clip() -> void:
	var s := await _table_with(["pit_boss"])
	var ap := s.dealer_art.player
	check(ap != null and ap.current_animation == &"idle", "Pit Boss idles (%s)" % (ap.current_animation if ap else "no player"))
	s.taunted.emit(&"bonfire_bust", "test")
	check(ap != null and ap.current_animation == &"taunt", "taunted -> taunt clip")
	s.queue_free()
	await process_frame


func _ashmouth_kept_alive_on_swap() -> void:
	var s := await _table_with(["ashmouth"])
	var old := s.dealer_art.scene
	s.dealer_art.taunt()
	s.dealer_art.player.seek(0.5, true)
	s.dealer_art.show_art("smiles")
	await process_frame
	check(is_instance_valid(old) and old.get_parent() == root, "Ashmouth mid-taunt: kept alive at the root after the swap")
	if is_instance_valid(old):
		check(not (old.get_node("Model") as Node3D).visible, "Ashmouth kept alive: body hidden (never beside Smiles)")
	_check_only(s, "smiles", "after swap")
	await create_timer(0.8).timeout
	check(is_instance_valid(old), "Ashmouth still alive before 1.75 s")
	await create_timer(0.8).timeout
	check(not is_instance_valid(old), "Ashmouth freed after ~1.75 s")
	s.queue_free()
	await process_frame
