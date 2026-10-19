## Leave table stills: clears Table 1 in 3 rigged hands, then saves
##   <dir>/<prefix>_banner.png     the clearing bank's TABLE CLEARED banner
##   <dir>/<prefix>_cleared.png    right after it, between hands: the
##                                 LEAVE TABLE button
##   <dir>/<prefix>_midhand.png    the next throw landed (button hidden)
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_leave_table.gd -- dir=/tmp prefix=pc
extends SceneTree

var _s: Bonfire3D


func _initialize() -> void:
	_run.call_deferred()


func _throw(faces: Array[int]) -> void:
	for k in 600:
		if _s.phase == Table3D.Phase.BET:
			break
		await process_frame
	_s.rig_faces(faces)
	_s.quick_throw()
	await _s.throw_resolved
	await _s.sequence_finished


func _bank(faces: Array[int], idx: Array[int]) -> void:
	await _throw(faces)
	for i in idx:
		_s.pick_die(i)
	await _s.bank()


func _shot(path: String, frames: int = 4) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path, "  leave button visible: ", _s.bhud.leave_button.visible)


func _run() -> void:
	var dir := "user://"
	var prefix := "leave"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dir="):
			dir = a.substr(4)
		elif a.begins_with("prefix="):
			prefix = a.substr(7)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	_s.setup = TableSetup.sandbox(t, 5)
	_s.tutorial_override = 0
	root.add_child(_s)
	await create_timer(0.5).timeout
	await _bank([1, 2, 3, 6, 6] as Array[int], [0, 1, 2] as Array[int])
	await _bank([4, 4, 4, 2, 6] as Array[int], [0, 1, 2] as Array[int])
	await _throw([2, 2, 6, 6, 3] as Array[int])
	for i in 4:
		_s.pick_die(i)
	_s.bank()  # not awaited: catch the banner while it is up
	for k in 2000:
		if _s.bhud.cleared_banner.modulate.a > 0.95:
			break
		await process_frame
	await _shot("%s/%s_banner.png" % [dir, prefix], 1)
	for k in 600:
		if _s.phase == Table3D.Phase.BET:
			break
		await process_frame
	await _shot("%s/%s_cleared.png" % [dir, prefix])
	await _throw([3, 3, 2, 4, 6] as Array[int])
	await _shot("%s/%s_midhand.png" % [dir, prefix])
	quit()
