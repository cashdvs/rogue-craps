## Headless test for the Tiny Anvil boot splash (scenes/studio_splash.tscn).
## Checks: it is the main scene and loads; it advances to boot/next_scene after
## its duration (with its sound cues: per-cue OR the single studio_splash sting, never both); any key / click skips with a fast fade
## (mouse motion doesn't); it never replays once played; reduced motion is a
## shorter fade-only variant.
##
## Run:
##   godot --headless --path . --script res://tests/test_studio_splash.gd
extends SceneTree

const SPLASH := "res://scenes/studio_splash.tscn"
## A folder that doesn't exist: the splash finds no <event>.wav there, so the
## cue checks don't depend on which splash sounds are in res://audio/sfx/.
const NO_SFX := "res://tests/no_such_sfx_dir/"

var _failed: int = 0
var _state: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok    ", what)
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	_state = root.get_node_or_null(^"SplashState")
	if _state == null:
		_state = (load("res://scripts/splash/splash_state.gd") as GDScript).new()
		_state.name = "SplashState"
		root.add_child(_state)

	# --- wiring --------------------------------------------------------------
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == SPLASH, "run/main_scene is the splash")
	var packed := load(SPLASH) as PackedScene
	_check(packed != null, "splash scene loads")
	var next_path := str(ProjectSettings.get_setting("boot/next_scene", ""))
	_check(next_path == "res://scenes/table_3d.tscn", "boot/next_scene is the 3D table (%s)" % next_path)
	_check(next_path != "" and load(next_path) is PackedScene, "boot/next_scene points at a loadable scene (%s)" % next_path)
	var tl: Dictionary = (load("res://scripts/splash/studio_splash.gd") as GDScript).load_timeline("res://assets/branding/studio/splash_timings.json")
	_check(not tl.is_empty() and tl.has("layers") and tl.has("reduced_motion"), "motion spec splash_timings.json parses")
	var total := float(tl.get("total", 0.0))
	var reduced_total := float(tl.get("reduced_motion", {}).get("total", 0.0))
	var skip_fade := float(tl.get("skip", {}).get("skip_fade", 0.2))
	_check(total > 1.5 and total <= 3.0, "full splash is ~2.5 s (%.2f)" % total)
	var layers: Dictionary = tl.get("layers", {})
	for layer: Dictionary in [layers.anvil, layers.hammer, layers.sparks.hero, layers.wordmark.main, layers.wordmark.games]:
		var png := "res://assets/branding/studio/" + str(layer.texture)
		var tex := load(png) as Texture2D
		_check(tex != null and not (tex is AtlasTexture), "layer texture %s loads (own texture, not atlased)" % png)
	_check(is_equal_approx(float(tl.get("skip", {}).get("ignore_input_before", 0.0)), 0.15), "input ignored for the first 0.15 s")

	# --- full play advances after its duration ---------------------------------
	_state.played = false
	_state.reduced_motion = false
	var run := await _play_until_change(packed, 5.0, -1.0, null)
	_check(run.changed, "full splash changed scene")
	_check(absf(run.seconds - total) < 0.35, "changed after ~%.2fs (took %.2fs)" % [total, run.seconds])
	_check(run.cues.has(&"splash_clang") and not run.cues.has(&"studio_splash"), "per-cue events fired, no studio_splash on top (%s)" % [run.cues])
	_check(run.cues.size() == (tl.get("sfx", []) as Array).size(), "one cue per spec sfx entry")
	_check(run.skipped == 0, "finished(skipped=false)")
	_check(current_scene != null and current_scene.scene_file_path == next_path, "now in the next scene")
	_check(_state.played, "SplashState.played set")

	# --- never replays once played --------------------------------------------
	var again := await _play_until_change(packed, 2.0, -1.0, null)
	_check(again.changed and again.seconds < 0.3, "second splash skipped straight on (%.2fs)" % again.seconds)
	_check(again.cues.is_empty() and again.blocked, "second splash played no cues / animation")

	# --- input during the first 0.15 s is ignored --------------------------------
	_state.played = false
	var early := InputEventKey.new()
	early.keycode = KEY_ENTER
	early.pressed = true
	var ea := await _play_until_change(packed, 0.5, 0.0, early)
	_check(not ea.changed and ea.skipped == -1, "key press at t=0 (held over from launch) does not skip")

	# --- skip on key -------------------------------------------------------------
	_state.played = false
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	var sk := await _play_until_change(packed, 3.0, 0.5, key)
	_check(sk.changed and sk.skipped == 1, "key press skips")
	_check(sk.seconds < 0.5 + skip_fade + 0.25, "skip fade is fast (changed at %.2fs, pressed at 0.50s)" % sk.seconds)

	# --- skip on click, but not on mouse motion -----------------------------
	_state.played = false
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300, 300)
	motion.relative = Vector2(40, 0)
	var mv := await _play_until_change(packed, 0.8, 0.3, motion)
	_check(not mv.changed and mv.skipped == -1, "mouse motion does not skip")
	if not mv.changed:
		# Continue the same splash with a click.
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(300, 300)
		var started := Time.get_ticks_msec()
		root.push_input(click)
		var splash := current_scene
		while current_scene == splash and Time.get_ticks_msec() - started < 1000:
			await process_frame
		while current_scene == null and Time.get_ticks_msec() - started < 2000:
			await process_frame
		_check(current_scene != splash, "mouse click skips (%.2fs)" % ((Time.get_ticks_msec() - started) / 1000.0))

	# --- reduced motion ---------------------------------------------------------
	_state.played = false
	_state.reduced_motion = true
	var rm := await _play_until_change(packed, 4.0, -1.0, null)
	_check(rm.changed and absf(rm.seconds - reduced_total) < 0.35, "reduced motion finishes in ~%.2fs (took %.2fs)" % [reduced_total, rm.seconds])
	_check(not rm.hammer_visible, "reduced motion hides the hammer swing")
	_check(not rm.cues.has(&"studio_splash") and rm.cues.has(&"splash_clang"), "reduced motion: per-cue events only, no studio_splash (%s)" % [rm.cues])

	# --- studio_splash and the per-cue sounds are mutually exclusive -----------
	var beep := AudioStreamWAV.new()
	beep.data = PackedByteArray([0, 0, 0, 0])
	var full_n := (tl.get("sfx", []) as Array).size()
	var reduced_n := (tl.get("reduced_motion", {}).get("sfx", []) as Array).size()
	_state.reduced_motion = false
	_state.played = false
	var only_sting := await _play_until_change(packed, 5.0, -1.0, null, {&"studio_splash": beep})
	_check(only_sting.cues == [&"studio_splash"] and only_sting.mode == &"single", "only a studio_splash stream: the single sting plays alone (%s)" % [only_sting.cues])
	_state.played = false
	var both := await _play_until_change(packed, 5.0, -1.0, null, {&"studio_splash": beep, &"splash_clang": beep})
	_check(not both.cues.has(&"studio_splash") and both.cues.size() == full_n and both.mode == &"per_cue", "a per-cue stream exists: studio_splash is skipped (%s)" % [both.cues])
	_state.played = false
	_state.reduced_motion = true
	var rm_sting := await _play_until_change(packed, 5.0, -1.0, null, {&"studio_splash": beep})
	_check(rm_sting.cues == [&"studio_splash"], "reduced motion, only the sting: it plays alone (%s)" % [rm_sting.cues])
	_state.played = false
	var rm_both := await _play_until_change(packed, 5.0, -1.0, null, {&"studio_splash": beep, &"splash_whoosh": beep})
	_check(not rm_both.cues.has(&"studio_splash") and rm_both.cues.size() == reduced_n, "reduced motion with a per-cue stream: no studio_splash (%s)" % [rm_both.cues])
	_state.played = false
	var rm_other := await _play_until_change(packed, 5.0, -1.0, null, {&"studio_splash": beep, &"splash_twinkle": beep})
	_check(rm_other.cues == [&"studio_splash"], "a per-cue stream the reduced variant doesn't use doesn't block the sting (%s)" % [rm_other.cues])
	_state.reduced_motion = false

	# --- sfx_dir: the <event>.wav fallback folder is overridable ------------------
	var probe := packed.instantiate()
	probe.sfx_dir = "res://audio/sfx/"
	_check(probe._stream_for(&"chip_collect") != null, "sfx_dir: finds <event>.wav in the folder it points at")
	probe.sfx_dir = NO_SFX
	_check(probe._stream_for(&"chip_collect") == null, "sfx_dir: an empty/missing folder finds nothing")
	probe.free()

	if current_scene != null:
		current_scene.free()
	await process_frame
	print("=== studio splash: %s ===" % ("PASS" if _failed == 0 else "FAIL (%d)" % _failed))
	quit(1 if _failed > 0 else 0)


## Instantiates the splash as the current scene and waits until the scene
## changes (or `timeout` s). Optionally pushes `event` at `input_at` s.
## Sounds come only from `streams` (cue_streams); sfx_dir points at NO_SFX.
func _play_until_change(packed: PackedScene, timeout: float, input_at: float, event: InputEvent, streams: Dictionary = {}) -> Dictionary:
	var result := {"changed": false, "seconds": 0.0, "cues": [], "skipped": -1, "blocked": false, "hammer_visible": true, "mode": &""}
	if current_scene != null:
		var old := current_scene
		current_scene = null
		old.queue_free()
		await process_frame
	var splash := packed.instantiate()
	splash.sfx_dir = NO_SFX
	for k: StringName in streams:
		splash.cue_streams[k] = streams[k]
	var cues: Array = result.cues
	splash.cue.connect(func(e: StringName) -> void:
		if cues.is_empty():
			result.mode = splash.cue_mode()
		cues.append(e))
	splash.finished.connect(func(was_skipped: bool) -> void: result.skipped = 1 if was_skipped else 0)
	root.add_child(splash)
	current_scene = splash
	result.blocked = splash.replay_blocked
	var started := Time.get_ticks_msec()
	var pushed := false
	var saw_start := false
	while true:
		await process_frame
		if not saw_start and is_instance_valid(splash) and splash.playing:
			# The hammer as the timeline starts (reduced motion hides it).
			saw_start = true
			result.hammer_visible = splash.get_node("%Hammer").visible
		var t := (Time.get_ticks_msec() - started) / 1000.0
		if current_scene != splash:
			result.changed = true
			result.seconds = t
			while current_scene == null and (Time.get_ticks_msec() - started) / 1000.0 < timeout + 2.0:
				await process_frame  # change_scene finishes on the next frame
			break
		if not pushed and input_at >= 0.0 and t >= input_at:
			pushed = true
			root.push_input(event)
		if t > timeout:
			result.seconds = t
			break
	return result
