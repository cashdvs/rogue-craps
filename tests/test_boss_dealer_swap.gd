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
	await _missing_scene_restores_greybox()
	await _swapped_out_dealer_is_freed()
	_mobile_paths()
	await _mobile_variant_loads()
	await _stopgap_id_is_shuffle()
	await _heads_in_frame_over_rail()
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
	check(n.position.is_equal_approx(BonfireDealerArt.DEALER_SPOT + BonfireDealerArt.GREYBOX_RAIL_LIFT), "%s: stands at the dealer spot (%s)" % [label, n.position])
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


## A boss whose scene file is missing: no art, so the greybox bust comes back.
func _missing_scene_restores_greybox() -> void:
	var s := await _table_with(["pit_boss"])
	s.dealer_art.show_art("no_such_boss")
	await process_frame
	check(_dealer_scenes(s).is_empty(), "missing art: no dealer scene left")
	check(s.dealer.head.visible, "missing art: greybox bust visible again")
	check(s.dealer_art.scene == null, "missing art: scene is null")
	s.queue_free()
	await process_frame


## Swapping a non-Ashmouth dealer frees the old scene (no leak).
func _swapped_out_dealer_is_freed() -> void:
	var s := await _table_with([])
	var old := s.dealer_art.scene
	s.dealer_art.show_art("pit_boss")
	await process_frame
	check(not is_instance_valid(old), "Smiles swapped out: old scene freed")
	_check_only(s, "pit_boss", "after Smiles -> Pit Boss swap")
	var old2 := s.dealer_art.scene
	s.dealer_art.show_art("collector")
	await process_frame
	check(not is_instance_valid(old2), "Pit Boss swapped out: old scene freed")
	_check_only(s, "collector", "after Pit Boss -> Collector swap")
	s.queue_free()
	await process_frame


## The low-poly variant path for Smiles and every boss (mobile = true).
func _mobile_paths() -> void:
	for id: String in ["smiles"] + BOSSES.values():
		var p := BonfireDealerArt.scene_path(id, true)
		check(p.ends_with("/%s_mobile.tscn" % id) and ResourceLoader.exists(p), "mobile path for %s (%s)" % [id, p])
		var pc := BonfireDealerArt.scene_path(id, false)
		check(pc.ends_with("/%s.tscn" % id), "PC path for %s (%s)" % [id, pc])


## show_art(mobile = true) really instances the _mobile scene at the spot.
func _mobile_variant_loads() -> void:
	var s := await _table_with([])
	for id: String in ["smiles", "ashmouth", "shuffle"]:
		s.dealer_art.show_art(id, true)
		await process_frame
		var scenes := _dealer_scenes(s)
		check(scenes.size() == 1 and scenes[0].scene_file_path.ends_with("/%s_mobile.tscn" % id), "mobile %s loads %s" % [id, scenes.map(func(n: Node) -> String: return n.scene_file_path)])
	s.queue_free()
	await process_frame


## PR #172's own id for Madame Shuffle shows the Shuffle dealer; pit_boss
## with faces [2, 4] is just the Pit Boss now (no faces fallback).
func _stopgap_id_is_shuffle() -> void:
	check(BonfireDealerArt.art_for_rules([{"id": &"madame_shuffle_stopgap", "params": {"faces": [2, 4]}}]) == "shuffle", "madame_shuffle_stopgap -> shuffle")
	check(BonfireDealerArt.art_for_rules([{"id": &"pit_boss", "params": {"faces": [2, 4]}}]) == "pit_boss", "no faces fallback: pit_boss [2,4] stays pit_boss")
	check(BonfireDealerArt.art_for_rules([{"id": &"pit_boss", "params": {"faces": [2, 3, 4, 5, 6]}}]) == "pit_boss", "real Pit Boss stays pit_boss")
	var s := await make_table(0, _setup_with([{"id": &"madame_shuffle_stopgap", "params": {"faces": [2, 4]}}]))
	_check_only(s, "shuffle", "boss madame_shuffle_stopgap")
	s.queue_free()
	await process_frame


func _setup_with(rules: Array) -> TableSetup:
	var st := TableSetup.sandbox(t, 5)
	st.rules = rules
	return st


## PC 16:9: every dealer's top is inside the frame and above the far rail
## top in screen space (the greybox rail used to hide the faces).
func _heads_in_frame_over_rail() -> void:
	root.size = Vector2i(1920, 1080)
	var s := await _table_with([])
	var cam := root.get_viewport().get_camera_3d()
	for id: String in ["smiles"] + BOSSES.values():
		s.dealer_art.show_art(id)
		await process_frame
		var top := -9.0
		for mi: MeshInstance3D in s.dealer_art.scene.find_children("*", "MeshInstance3D", true, false):
			top = maxf(top, (mi.global_transform * mi.get_aabb()).end.y)
		var top_px := cam.unproject_position(Vector3(-0.42, top, -0.86)).y
		check(top_px > 0.0, "%s: top inside the frame (%.0f px)" % [id, top_px])
		# The greybox far rail hides anything lower than ~0.18 m above its
		# top at this camera angle (QA shots: hats only), so the head band
		# must clear that. Smallest boss (Straight Man) is ~0.195 m up.
		check(top - CameraFraming.RAIL_TOP_Y > 0.18, "%s: head clears the far rail (%.3f m)" % [id, top - CameraFraming.RAIL_TOP_Y])
	s.queue_free()
	await process_frame
