## In-game bug report: a prefilled mailto (OS.shell_open) to the studio, and
## on PC a viewport screenshot in user://bug_reports/ (mailto can't attach,
## so the path is shown in a toast). build_mailto() / build_body() are pure
## for headless tests. The live run is registered by MapRun (weak ref).
## Strings: BugReportStrings, by strings_v1 id.
class_name BugReport
extends RefCounted

const TO := "tinyanvilgames@mail.grokbot.com"
const DIR := "user://bug_reports/"
const TOAST_SECS := 6.0

## Test seams: opener(url) -> Error and clipboard(text). Unset (default) =
## OS.shell_open / DisplayServer.clipboard_set; tests set fakes, then reset.
static var opener: Callable
static var clipboard: Callable

static var _run: WeakRef


## MapRun calls this when a run starts; null clears it.
static func set_run(run: Object) -> void:
	_run = weakref(run) if run != null else null


## The live MapRun registered by set_run(), or null (no run / freed).
static func current_run() -> Object:
	return _run.get_ref() if _run != null else null


## "mailto:...?subject=...&body=..." with both parts URL-encoded.
static func build_mailto(subject: String, body: String) -> String:
	return "mailto:%s?subject=%s&body=%s" % [TO, subject.uri_encode(), body.uri_encode()]


## Mail body: a blank "What happened:" line first, then the build, platform
## and (when a run is live) its seed, table/boss, Embers/Soul and bag.
static func build_body(version: String, platform: String, run: Object = null) -> String:
	var lines: Array[String] = [BugReportStrings.get_text("bug_report_what"), "", "", "Version: " + version, "Platform: " + platform]
	if run != null and run.get("progress") != null:
		lines.append_array(run_lines(run))
	return "\n".join(lines)


## The run part of the body: seed, floor/table, boss, Embers/Soul, bag.
static func run_lines(run: Object) -> Array[String]:
	var p: RunProgress = run.progress
	var out: Array[String] = ["Seed: %d" % int(run.run_seed)]
	var where := "Floor %d" % (int(run.floor_index) + 1)
	if run.screen == MapRunState.Screen.TABLE:
		where += ", " + str(MapGenData.NodeType.keys()[run.table_type]).capitalize()
	out.append("Table: " + where)
	if run.has_method("boss_name"):
		out.append("Boss: " + run.boss_name())
	out.append("Embers: %d / Soul: %d of %d" % [p.embers, p.soul, p.max_soul])
	out.append("Bag: " + bag_text(p.dice))
	return out


## "bone, bone[heavy], cracked": shape or special id, plus any face mods.
static func bag_text(dice: Array) -> String:
	var parts: Array[String] = []
	for d in dice:
		var s := String(d.special_id) if d.special_id != &"" else String(d.shape)
		var mods: Array[String] = []
		for f in d.faces:
			if f != &"":
				mods.append(String(f))
		parts.append(s + ("[%s]" % ",".join(mods) if not mods.is_empty() else ""))
	return ", ".join(parts) if not parts.is_empty() else "none"


## "Windows (1920, 1080)": OS name and window size ("headless" without a display).
static func platform() -> String:
	return "%s %s" % [OS.get_name(), str(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else "headless"]


## Screenshot file for [param when] (Time dict): "user://bug_reports/20261031-110500.png".
static func shot_path(when: Dictionary) -> String:
	return DIR + "%04d%02d%02d-%02d%02d%02d.png" % [when.year, when.month, when.day, when.hour, when.minute, when.second]


## Full report from [param layer] (e.g. the pause menu, hidden for the shot).
## PC: saves a screenshot first and toasts its path. Returns the path or "".
## Fire and forget: callers don't await it (it awaits one frame for the shot).
static func report(layer: CanvasLayer) -> String:
	var path := ""
	if OS.has_feature("pc"):
		var was := layer.visible
		layer.visible = false
		await RenderingServer.frame_post_draw
		path = save_shot(layer.get_viewport())
		layer.visible = was
		if path != "":
			toast(layer, BugReportStrings.get_text("bug_report_saved").format({"path": ProjectSettings.globalize_path(path)}))
	send(layer, Version.bug_subject(), build_body(Version.display(), platform(), current_run()))
	return path


## Opens the mailto through `opener`. If that fails (no mail app), copies the
## address, subject and body through `clipboard` and toasts bug_report_no_mail on
## [param node]. Returns the opener's Error.
static func send(node: Node, subject: String, body: String) -> int:
	var url := build_mailto(subject, body)
	var err := int(opener.call(url)) if opener.is_valid() else OS.shell_open(url)
	if err != OK:
		var copy := "To: %s\nSubject: %s\n\n%s" % [TO, subject, body]
		if clipboard.is_valid():
			clipboard.call(copy)
		else:
			DisplayServer.clipboard_set(copy)
		if node != null:
			toast(node, BugReportStrings.get_text("bug_report_no_mail"))
	return err


## Saves [param vp] as a PNG under DIR; returns its user:// path, or "" on failure.
static func save_shot(vp: Viewport) -> String:
	var img := vp.get_texture().get_image()
	if img == null:
		return ""
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := shot_path(Time.get_datetime_dict_from_system())
	return path if img.save_png(path) == OK else ""


## A short label at the top of [param node]'s viewport, freed after TOAST_SECS.
static func toast(node: Node, text: String) -> Label:
	var cl := CanvasLayer.new()
	cl.layer = 60
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var l := Label.new()
	l.name = "BugReportToast"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.label_settings = Palette.label_settings(24, Palette.BONE, 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 24)
	cl.add_child(l)
	node.get_tree().root.add_child(cl)
	node.get_tree().create_timer(TOAST_SECS, true).timeout.connect(cl.queue_free)
	return l
