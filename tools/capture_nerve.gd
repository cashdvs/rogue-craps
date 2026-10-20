## Nerve HUD screenshots (PR #126 QA): settled with the pip, a nudge, and the
## bust-rescue prompt with HN1. Needs a display and Vulkan (lavapipe under
## xvfb works); phone=WxH frames it like a phone (see CapturePhone):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan \\
##       --resolution 1920x1080 --script res://tools/capture_nerve.gd -- --out=/tmp/nerve/ [phone=390x844]
extends SceneTree

var OUT := "user://captures_nerve/"
var s: Bonfire3D
var phone := CapturePhone.new()


func _initialize() -> void:
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	phone.image(root).save_png(OUT + name + ".png")
	print("saved ", OUT + name + ".png")


func wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func throw_faces(faces: Array[int]) -> void:
	while s.phase != Table3D.Phase.BET:
		await process_frame
	await wait(0.35)
	s.rig_faces(faces)
	if s.quick_throw():
		await s.sequence_finished


func _run() -> void:
	phone.parse_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(OUT)
	s = (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.bonfire_seed = 21
	s.tutorial_override = 1  # hints on (HN1 on the rescue)
	phone.add_table(root, s)
	await wait(1.0)
	phone.frame(s)
	await throw_faces([3, 3, 3, 2, 6] as Array[int])
	await wait(0.6)
	await shot("1_settled")
	s.nerve.nudge(3, NerveState.UP)
	await wait(0.6)
	await shot("2_nudged_up")
	s.nerve.undo(3)
	s.pick_die(0)
	s.pick_die(1)
	s.pick_die(2)
	s.throw_again()
	await throw_faces([4, 6] as Array[int])
	await wait(0.6)
	await shot("5_rescue_prompt")
	print("done")
	quit()
