## Frame strip of the RUN COMPLETE count-up (RunCompleteCountup): the end
## panel's rows at start, mid (Embers landed, Final ticking) and final.
## Needs Forward+/Vulkan (lavapipe under xvfb):
##   VK_ICD_FILENAMES=.../lvp_icd.json xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \\
##       --rendering-method forward_plus --rendering-driver vulkan --resolution 1280x720 \\
##       --script res://tools/capture_run_complete_countup.gd -- --out=/tmp/rcc/
extends SceneTree

const TIMES: Array[float] = [0.0, 1.0, 9.0]
const TAGS: Array[String] = ["start", "mid", "final"]
var OUT := "user://captures_run_complete_countup/"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			OUT = a.substr(6)
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	print("capture_run_complete_countup: renderer %s / %s" % [method, driver])
	if method != "forward_plus" or driver != "vulkan":
		push_error("capture_run_complete_countup: need Forward+/Vulkan, got %s/%s" % [method, driver])
		quit(1)
		return
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var bg := ColorRect.new()
	bg.color = RunTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(200, 120)
	box.size = Vector2(700, 500)
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	box.add_child(RunTheme.label("RUN COMPLETE", 40, RunTheme.EMBER, true))
	box.add_child(RunTheme.label("You beat the Ashmouth Baron, and the run is yours.", 24))
	box.add_child(RunTheme.label("Points banked: 1234", 24))
	var e := RunTheme.label("", 24)
	var t := RunTheme.label("", 24)
	box.add_child(e)
	box.add_child(t)
	var c := RunCompleteCountup.new()
	root.add_child(c)
	c.set_process(false)
	c.setup(e, t, 7, 10, 1234, false)
	var shots: Array[Image] = []
	var at := 0.0
	for i in TIMES.size():
		c.advance(TIMES[i] - at)
		at = TIMES[i]
		for f in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image().get_region(Rect2i(0, 0, 720, 300))
		img.save_png(OUT + "run_complete_countup_%s.png" % TAGS[i])
		print("  %s: %s | %s" % [TAGS[i], e.text, t.text])
		shots.append(img)
	var strip := Image.create(720 * 3 + 8, 300, false, shots[0].get_format())
	strip.fill(Color.BLACK)
	for i in shots.size():
		strip.blit_rect(shots[i], Rect2i(0, 0, 720, 300), Vector2i(i * 724, 0))
	strip.save_png(OUT + "run_complete_countup_strip.png")
	print("capture_run_complete_countup: wrote ", OUT)
	quit(0)
