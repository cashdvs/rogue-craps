## Saves the procedural placeholder sounds as .wav files in res://audio/sfx/.
## Run: godot --headless --path . --script res://tools/bake_sfx.gd
## (The game works without baking; SfxManager synthesizes missing sounds.)
extends SceneTree


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio/sfx"))
	var ok := true
	for event in SfxSynth.EVENTS:
		var path := "res://audio/sfx/%s.wav" % event
		var err := SfxSynth.make(event).save_to_wav(ProjectSettings.globalize_path(path))
		if err != OK:
			push_error("Could not save %s" % path)
			ok = false
		else:
			print("Saved ", path)
	quit(0 if ok else 1)
