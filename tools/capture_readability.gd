## Readability-pass stills (how_bonfire_plays.md section 4), the same staged
## Table 1 at any window size, so before / after shots line up:
##   <dir>/<prefix>_1_lit_cold.png       4-4-4-5 lit, the 2 cold
##   <dir>/<prefix>_2_pot_preview.png    4-4-4 picked: the live pot preview
##   <dir>/<prefix>_3_refused.png        the cold 2 clicked: bounces back
##   <dir>/<prefix>_4_rethrow.png        2 cold dice to throw: the bust-risk prompt, PENDING card
##   <dir>/<prefix>_5_claimed.png        banked: the CLAIMED stamp
##   <dir>/<prefix>_6_cleared.png        the clearing bank: TABLE CLEARED banner
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_readability.gd -- dir=/tmp prefix=pc
## Add --fixed-fps 30 --write-movie /tmp/x.avi before --script for a video.
extends SceneTree

var _s: Bonfire3D
var _dir := "user://"
var _prefix := "read"


func _initialize() -> void:
	_run.call_deferred()


func _bet() -> void:
	for k in 2000:
		if _s.phase == Table3D.Phase.BET:
			return
		await process_frame


func _throw(faces: Array[int]) -> void:
	await _bet()
	await create_timer(0.3).timeout
	_s.rig_faces(faces)
	_s.quick_throw()
	await _s.throw_resolved
	await _s.sequence_finished
	await create_timer(0.3).timeout


func _shot(name: String, frames: int = 3) -> void:
	for i in frames:
		await process_frame
	var path := "%s/%s_%s.png" % [_dir, _prefix, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dir="):
			_dir = a.substr(4)
		elif a.begins_with("prefix="):
			_prefix = a.substr(7)
	# `-- --throw-debug` turns the debug throw overlay on (Bonfire3D reads it).
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	_s.setup = TableSetup.sandbox(t, 5)
	_s.setup.table_seed = 5
	_s.tutorial_override = 0
	root.add_child(_s)
	await create_timer(0.6).timeout
	await _throw([4, 4, 4, 5, 2] as Array[int])
	await _shot("1_lit_cold")
	for i in 3:
		_s.pick_die(i)
	await _shot("2_pot_preview")
	_s.pick_die(4)
	await _shot("3_refused", 1)
	await create_timer(0.3).timeout
	_s.throw_again()
	await _bet()
	await create_timer(0.3).timeout
	await _shot("4_rethrow")
	await _throw([5, 6] as Array[int])
	_s.pick_die(0)
	_s.bank()
	for k in 600:
		if _s.bhud.has_stamp(&"triple"):
			break
		await process_frame
	await create_timer(0.35).timeout
	await _shot("5_claimed", 1)
	await _throw([1, 2, 3, 6, 6] as Array[int])
	for i in 3:
		_s.pick_die(i)
	await _s.bank()
	await _throw([2, 2, 6, 6, 3] as Array[int])
	for i in 4:
		_s.pick_die(i)
	_s.bank()
	for k in 2000:
		if _s.run.cleared and not _s.bhud.countup.is_playing():
			break
		await process_frame
	# The banner (ClearedBanner) settles at 0.40 s; shoot it while it holds.
	var bn: Variant = _s.bhud.get("cleared_banner")
	if bn != null and bn.has_method("is_playing"):
		for k in 2000:
			if bn.is_playing() and float(bn.get("t")) >= 0.45:
				break
			await process_frame
	else:
		await create_timer(0.3).timeout
	await _shot("6_cleared", 1)
	await create_timer(1.5).timeout
	quit()
