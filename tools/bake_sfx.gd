## Saves the procedural sounds as .wav files in res://audio/sfx/.
## Run: godot --headless --path . --script res://tools/bake_sfx.gd
##
## Every script in scripts/audio/ with a static bake_all() is baked.
## bake_all() returns {file name: AudioStreamWAV} for every file that synth
## owns, so adding a synth (or more files to one) never touches this tool or
## audio/sfx/SOURCES.md. (The game works without baking; SfxManager
## synthesizes missing sounds.)
extends SceneTree

const AUDIO_SCRIPTS: String = "res://scripts/audio/"
const OUT_DIR: String = "res://audio/sfx/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ok := true
	for script in synth_scripts():
		var files: Dictionary = script.call(&"bake_all")
		for file_name: String in files:
			var path := OUT_DIR + file_name
			if (files[file_name] as AudioStreamWAV).save_to_wav(ProjectSettings.globalize_path(path)) != OK:
				push_error("Could not save %s" % path)
				ok = false
			else:
				print("Saved ", path)
	quit(0 if ok else 1)


## Every script in scripts/audio/ that has a static bake_all(), by file name.
static func synth_scripts() -> Array[GDScript]:
	var out: Array[GDScript] = []
	var names := Array(DirAccess.get_files_at(AUDIO_SCRIPTS))
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".gd"):
			continue
		var script := load(AUDIO_SCRIPTS + file_name) as GDScript
		if script == null:
			continue
		for m: Dictionary in script.get_script_method_list():
			if m.name == "bake_all":
				out.append(script)
				break
	return out
