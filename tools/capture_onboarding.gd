## Onboarding hints v1: stills of the seeded first hand on Table 1
## (design/onboarding_hints_v1.md), the tutorial on:
##   <dir>/<prefix>_1_th0.png   TH0 throw prompt
##   <dir>/<prefix>_2_th1.png   H1 T1 lands 2 3 4 4 6: TH1 (the 6 cold)
##   <dir>/<prefix>_3_th3.png   2-3-4 potted: TH3 at the Run of 3 card
##   <dir>/<prefix>_4_th5.png   TH5: 2 cold dice, 1 in 3
##   <dir>/<prefix>_5_t2.png    H1 T2 lands 1 1
##   <dir>/<prefix>_6_th6.png   Pair potted: Hot Hand, TH6
##   <dir>/<prefix>_7_t3.png    H1 T3 lands 3 3 3 2 6 (the Triple seed)
##   xvfb-run -a -s "-screen 0 2400x2400x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_onboarding.gd -- dir=/tmp prefix=pc
## Phone framing: add phone=390x844 (portrait) or phone=844x390 (landscape).
extends SceneTree

## `-- phone=390x844` frames the table like a phone (CapturePhone).
var _phone := CapturePhone.new()

var _s: Bonfire3D
var _dir := "user://"
var _prefix := "onboard"


func _initialize() -> void:
	_run.call_deferred()


func _ready_to_throw() -> void:
	for k in 2000:
		if _s.phase == Table3D.Phase.BET and _s.run.state == BonfireRun.State.AIM and not _s.hand_moving() and not _s.bhud.countup.is_playing():
			return
		await process_frame


func _throw() -> void:
	await _ready_to_throw()
	await create_timer(0.3).timeout
	_s.quick_throw()
	await _s.throw_resolved
	await _s.sequence_finished
	await create_timer(0.3).timeout


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	var path := "%s/%s_%s.png" % [_dir, _prefix, name]
	_phone.image(root).save_png(path)
	print("saved ", path)


func _pick(want: Array) -> void:
	var left := want.duplicate()
	for i in _s.run.throw_faces.size():
		if left.has(int(_s.run.throw_faces[i])):
			left.erase(int(_s.run.throw_faces[i]))
			_s.pick_die(i)


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dir="):
			_dir = a.substr(4)
		elif a.begins_with("prefix="):
			_prefix = a.substr(7)
	var t := load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	_s.setup = TableSetup.sandbox(t, 5)
	_s.setup.table_seed = 5
	_s.tutorial_override = 1
	_phone.parse_args()
	_phone.add_table(root, _s)
	await process_frame
	await process_frame
	_phone.frame(_s)
	await create_timer(0.8).timeout
	await _shot("1_th0")
	await _throw()
	await _shot("2_th1")
	_s.bhud.tutorial.dismiss()
	_pick([2, 3, 4])
	await _shot("3_th3")
	_s.bhud.tutorial.dismiss()
	_s.bhud.tutorial.dismiss()
	await _shot("4_th5")
	_s.bhud.tutorial.dismiss()
	_s.throw_again()
	await _throw()
	await _shot("5_t2")
	_pick([1, 1])
	_s.throw_again()
	await create_timer(0.5).timeout
	await _shot("6_th6")
	await _throw()
	await _shot("7_t3")
	quit()
