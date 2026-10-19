## Child of tests/test_run_shaped_table.gd: opens the real Bonfire table in
## run mode with the run's dice (a Powder Keg and a Ferryman's Coin in the
## bag), runs frames and a throw, and prints CHILD_OK / CHILD_FAIL lines.
## The parent fails on any SCRIPT ERROR in this process's output.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := (load("res://resources/map/bonfire_run.tres") as RunData).duplicate() as RunData
	data.max_dice = 7  # 5 Bones + Keg + Coin (the shipped bag cap is 6)
	var run := MapRun.new(data, 7)
	run.progress.add_die(&"powder_keg")
	run.progress.add_die(&"coin")
	for n: MapNode in run.map.nodes.values():
		if n.type == MapGenData.NodeType.TABLE:
			run.map.current_id = n.prev[0] if not n.prev.is_empty() else -1
			run.choose_node(n.id)
			break
	var st := run.table_setup().to_table_setup(load("res://resources/tuning/bonfire_tuning.tres"))
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	s.test_speed = 10.0
	root.add_child(s)
	for i in 30:
		await process_frame
	print("CHILD_DICE ", s.all_dice.size(), " keg labels ", s.all_dice[5].labels, " coin labels ", s.all_dice[6].labels)
	var ok: bool = s.all_dice.size() == 7 and s.all_dice[5].labels == [1, 1, 2, 2, 3, 3]
	var twin_ok: bool = s.all_dice[5].faces.get_node_or_null("FaceMods") != null and s.all_dice[5].faces.get_node("FaceMods").get_child_count() == 16
	print("CHILD_", "OK" if ok else "FAIL", " keg on the table as 1-1-2-2-3-3")
	print("CHILD_", "OK" if twin_ok else "FAIL", " keg's two Twin 3s carved (2 x 8 strips)")
	s.rig_slots([5, 6, 1, 2, 3, 6, 4] as Array[int])
	var thrown: bool = s.quick_throw()
	print("CHILD_", "OK" if thrown else "FAIL", " throw starts")
	if thrown:
		var res: Array = await s.throw_resolved
		print("CHILD_", "OK" if (res[0] as Array)[5] == 3 else "FAIL", " keg slot 6 lands a 3: ", res[0])
		print("CHILD_", "OK" if s.run.throw_mods[5] != null and s.run.throw_mods[5].id == &"twin" else "FAIL", " the Keg's 3 throws as a Twin")
	for i in 60:
		await process_frame
	print("CHILD_DONE")
	quit()
