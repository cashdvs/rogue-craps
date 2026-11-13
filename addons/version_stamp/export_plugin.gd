## Replaces the packed res://version.cfg with a stamped copy. The working
## tree file stays "dev" / build 0. Called by Godot during export, including
## `godot --headless --export-release`, once this plugin is enabled.
@tool
extends EditorExportPlugin

var _did := false


func _get_name() -> String:
	return "version_stamp"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_did = false


## Swap in the stamped cfg once. The replacement is exported on the next
## pass; `_did` stops that pass from skipping it again.
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if _did or path != "res://version.cfg":
		return
	var sha := _sha()
	var build := VersionStamp.build_from_env(OS.get_environment("GITHUB_RUN_NUMBER"))
	if sha == "" and build <= 0:
		return
	var raw := FileAccess.get_file_as_string(path)
	var stamped := VersionStamp.apply(raw, sha, build)
	if stamped == raw:
		return
	_did = true
	skip()
	add_file(path, stamped.to_utf8_buffer(), false)


## GITHUB_SHA, or the checkout's .git. A worktree (`.git` is a `gitdir:`
## file) and a branch that exists only in packed-refs are included.
func _sha() -> String:
	var root := ProjectSettings.globalize_path("res://")
	return VersionStamp.sha_for_root(OS.get_environment("GITHUB_SHA"), root)
