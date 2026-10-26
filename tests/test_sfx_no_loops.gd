## Headless test: no shipped sound loops (the crowd bed was removed, #177).
## Every audio/sfx/*.wav is loaded through load() (so its .import loop settings
## apply) and must have loop_mode == LOOP_DISABLED, and every .wav.import must
## have edit/loop_mode absent or 0.
##
## Run:
##   godot --headless --path . --script res://tests/test_sfx_no_loops.gd
extends SceneTree

const DIR := "res://audio/sfx/"

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
	print("=== Dice of the Damned: no looping SFX ===")
	var wavs := Array(DirAccess.get_files_at(DIR)).filter(func(f: String) -> bool: return f.ends_with(".wav"))
	_check(wavs.size() > 50, "found the sfx WAVs (%d)" % wavs.size())
	for f: String in wavs:
		var wav := load(DIR + f) as AudioStreamWAV
		_check(wav != null, "%s loads as an AudioStreamWAV" % f)
		if wav != null:
			_check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s: loop_mode is disabled (%d)" % [f, wav.loop_mode])
		var cfg := ConfigFile.new()
		_check(cfg.load(DIR + f + ".import") == OK, "%s.import parses" % f)
		var mode: int = cfg.get_value("params", "edit/loop_mode", 0)
		_check(mode == 0, "%s.import: edit/loop_mode is 0 or absent (%d)" % [f, mode])
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
