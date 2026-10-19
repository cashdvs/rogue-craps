## Headless test: SfxManager.play_mod_trigger and CrowdLayers.nudge. Cues land
## their transient on the row's hit (scheduled, or skipped into when late), ids
## map to rows (generic fallback, silent rows, Blank -> no_score), tiers and
## intensity set the volume, at most MAX_VOICES cues at once (then one shared
## cluster), count ticks can't cut them, same-moment triggers stagger 0.08 s,
## extra Bellows play once, signature hits nudge the crowd, 2x plays sooner and
## up, Instant plays one cluster per frame. Hooks: scripts/audio/README.md.
##
## Run:
##   godot --headless --path . --script res://tests/test_mod_trigger_hook.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	print("=== Dice of the Damned: mod trigger hook tests ===")
	await _test_hook()
	await _test_nudge()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _last(sfx: SfxManager) -> AudioStreamPlayer:
	return sfx._trigger_players.back()


func _test_hook() -> void:
	var sfx := SfxManager.new()
	root.add_child(sfx)
	var heard: Array[StringName] = []
	sfx.played.connect(func(e: StringName) -> void: heard.append(e))
	# Scheduled: mirror's transient sits 210 ms into its file, its hit is 250 ms after the FX start.
	_check(is_equal_approx(sfx.play_mod_trigger(&"mirror"), 0.25), "timing: returns the seconds to the hit (mirror 0.25)")
	_check(heard.is_empty(), "timing: mirror's cue waits until 40 ms after the FX start")
	sfx._process(0.03)
	_check(heard.is_empty(), "timing: not yet at 30 ms")
	sfx._process(0.02)
	_check(heard == [&"trigger_mirror_copy"], "timing: mirror_copy starts at 40-50 ms (%s)" % [heard])
	_check(is_equal_approx(_last(sfx).volume_db, -2.0), "volume: a major row plays at -2 dB")
	# Late (hit_ms shorter than the anticipation): starts now, skipping into the file.
	_check(is_equal_approx(sfx.play_mod_trigger(&"mirror_copy", 2, 0.0, 100.0), 0.1), "timing: hit_ms overrides the row")
	_check(heard.back() == &"trigger_mirror_copy" and _last(sfx).get_playback_position() >= 0.1, "timing: a late cue skips 110 ms in (at %.3f s)" % _last(sfx).get_playback_position())
	_check(is_equal_approx(_last(sfx).volume_db, -9.0), "volume: tier 2 at intensity 0 = -9 dB")
	_check(sfx.play_mod_trigger(&"heavy") < 0.0 and sfx.play_mod_trigger(&"extra") < 0.0, "map: Heavy / Extra play nothing")
	_check(is_equal_approx(sfx.play_mod_trigger(&"some_new_mod"), 0.247), "stagger: a 2nd trigger at the same moment hits 0.08 s later (generic 0.167 + 0.08)")
	sfx._process(0.25)
	_check(heard.back() == &"trigger_generic", "map: -> trigger_generic")
	# Ticks have the main pool; trigger cues their own.
	for i in 14:
		sfx.play(&"count_tick")
	var live := 0
	for p in sfx._trigger_players:
		live += 1 if p.playing else 0
	_check(live == 3, "pool: 14 count ticks cut none of the 3 live cues (%d)" % live)
	# Cap: 3 live + 1 more = 4, the 5th becomes one cluster at its hit, the 6th is dropped.
	_check(sfx.play_mod_trigger(&"twin") > 0.0, "cap: the 4th cue plays")
	_check(is_equal_approx(sfx.play_mod_trigger(&"stair"), 0.33), "cap: the 5th returns its (staggered) hit time (cluster)")
	_check(sfx.play_mod_trigger(&"gilded") < 0.0, "cap: the 6th is dropped while the cluster is pending")
	sfx._process(0.4)
	_check(heard.has(&"trigger_cluster") and not heard.has(&"trigger_stair_face"), "cap: the 5th played as trigger_cluster")
	sfx._process(1.0)
	_check(sfx.play_mod_trigger(&"gilded") > 0.0 and sfx._trigger_ends.size() == 1, "cap: voices free up when the cues end")
	# Blank: the existing no_score bounce, right away.
	_check(sfx.play_mod_trigger(&"blank") == 0.0 and heard.back() == &"no_score", "map: Blank plays no_score")
	sfx._process(1.0)
	# 2x: the hit comes at half the time, 1.12x up, 2 dB down.
	sfx.trigger_speed_mode = 1
	_check(is_equal_approx(sfx.play_mod_trigger(&"wild"), 0.0835), "2x: the hit comes twice as soon")
	sfx._process(0.1)
	_check(is_equal_approx(_last(sfx).pitch_scale, 1.12) and is_equal_approx(_last(sfx).volume_db, -6.0), "2x: 1.12x pitch, -2 dB")
	# Instant: one shared cluster per frame.
	sfx.trigger_speed_mode = 2
	_check(sfx.play_mod_trigger(&"hellfire") == 0.0 and heard.back() == &"trigger_cluster", "instant: the first trigger plays the cluster now")
	_check(sfx.play_mod_trigger(&"twin") < 0.0, "instant: the rest of the frame's triggers are skipped")
	_check(is_equal_approx(ModTriggerSynth.stagger(3), 0.24), "stagger: 0.08 s between triggers at 1x")
	# Bellows: extra Bellows in one Hot Hand play once (spec §2b).
	sfx.trigger_speed_mode = 0
	sfx._process(1.0)
	_check(is_equal_approx(sfx.play_mod_trigger(&"bellows"), 0.25) and sfx.play_mod_trigger(&"bellows") < 0.0, "bellows: a 2nd Bellows at the same Hot Hand plays nothing")
	sfx._process(1.0)
	_check(sfx.play_mod_trigger(&"bellows") > 0.0, "bellows: the next Hot Hand plays again")
	# Pre-carved batch-3 faces: the face-mod row + its flavour layer, on the same hit.
	sfx.trigger_speed_mode = 0
	sfx._process(1.0)
	heard.clear()
	_check(is_equal_approx(sfx.play_mod_trigger(&"verdict_20"), 0.25), "flavour: Verdict 20 hits with Hellfire (0.25 s)")
	sfx._process(0.26)
	_check(heard == [&"trigger_hellfire_face", &"trigger_flavor_verdict"], "flavour: Hellfire cue + the gavel layer (%s)" % [heard])
	_check(is_equal_approx(_last(sfx).volume_db, -2.0 + ModTriggerSynth.FLAVOR_DB), "flavour: the layer sits 6 dB under the cue")
	heard.clear()
	sfx.play_mod_trigger(&"blood_face", -1, 1.0, -1.0, &"verdict")
	sfx._process(0.3)
	_check(heard == [&"trigger_blood_face"], "flavour: Verdict 1 (Blood + verdict) has no layer of its own")
	for p in sfx._trigger_players + sfx._players:
		p.stop()
	await create_timer(0.1).timeout
	sfx.free()


func _test_nudge() -> void:
	var crowd := CrowdLayers.new()
	root.add_child(crowd)
	crowd.nudge()
	_check(crowd.current_db()[0] <= CrowdLayers.SILENT_DB, "nudge: does nothing while the crowd is stopped")
	crowd.start(0.01)
	crowd.set_pot_fraction(1.0, 0.01)
	await create_timer(0.1).timeout
	# The hook nudges by itself: SIGNATURE rows only, on their hit.
	var sfx := SfxManager.new()
	root.add_child(sfx)
	sfx.crowd = crowd
	var top := crowd.volume_db
	sfx.play_mod_trigger(&"mirror")
	sfx._process(0.3)
	_check(absf(crowd.current_db()[2] - top) < 0.3, "nudge: a major trigger doesn't nudge the crowd")
	_check(is_equal_approx(sfx.play_mod_trigger(&"last_breath"), 0.333), "nudge: last_breath (signature) hits at 0.333 s")
	sfx._process(0.3)
	_check(absf(crowd.current_db()[2] - top) < 0.3, "nudge: not before the hit")
	sfx._process(0.04)
	_check(absf(crowd.current_db()[2] - (top + 3.0)) < 0.3, "nudge: the stems swell 3 dB on the hit (%.1f)" % crowd.current_db()[2])
	await create_timer(0.45).timeout
	_check(absf(crowd.current_db()[2] - top) < 0.3, "nudge: then glide back to the pot level (%.1f)" % crowd.current_db()[2])
	for p in sfx._trigger_players:
		p.stop()
	crowd.stop(0.01)
	await create_timer(0.1).timeout
	sfx.free()
	crowd.free()
