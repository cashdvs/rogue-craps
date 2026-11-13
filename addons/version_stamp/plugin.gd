## Editor plugin: registers the export hook that stamps version.cfg.
## GitHub Actions already sets GITHUB_SHA and GITHUB_RUN_NUMBER, so the
## export workflow does not need an edit. Dev play is unchanged.
@tool
extends EditorPlugin

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/version_stamp/export_plugin.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export != null:
		remove_export_plugin(_export)
		_export = null
