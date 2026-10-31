## Build version (Version, version.cfg, tools/stamp_version.sh): formats,
## the stamped sha, export presets in step with version.cfg, and the corner
## label on the real title screen and pause menu at PC, 844x390 and portrait.
##   godot --headless --path . --script res://tests/test_version.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _shot := ""


func _initialize() -> void:
	_run.call_deferred()


func check(c: bool, what: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _formats() -> void:
	var n := Version.number()
	var re := RegEx.create_from_string("^0\\.1\\.(\\d+)$")
	check(re.search(n) != null, "number is 0.1.<N> (%s)" % n)
	check(Version.code() == 102 and n == "0.1.2", "next release: N = 2, code 102 (%s, code %d)" % [n, Version.code()])
	check(Version.code_for("0.2.0") > Version.code_for("0.1.9") and Version.code_for("1.0.0") > Version.code_for("0.99.99"), "versionCode grows across minor/major (0.2.0 > 0.1.9)")
	check(Version.code_for("0.1.10") > Version.code_for("0.1.9") and Version.code_for("0.2.0") == 200, "versionCode: 0.1.10 > 0.1.9, 0.2.0 = 200")
	check(Version.sha() == Version.DEV_SHA, "unstamped tree says dev (%s)" % Version.sha())
	check(Version.display() == "v0.1.2 (dev)", "display() %s" % Version.display())
	check(Version.tag() == "beta-0.1.2", "tag() %s" % Version.tag())
	check(Version.file_stem() == "DiceOfTheDamned-0.1.2", "file_stem() %s" % Version.file_stem())
	check(Version.bug_subject() == "Bug report - v0.1.2 (dev)", "bug_subject() %s" % Version.bug_subject())
	check(Version.font_for(1920, 1920) == Version.FONT_PT and Version.font_for(1920, 844) * 844.0 / 1920.0 >= Version.MIN_SCREEN_PX \
			and Version.font_for(1920, 390) * 390.0 / 1920.0 >= Version.MIN_SCREEN_PX, "label font >= 11 screen px at PC, 844 wide and 390 wide")


## The real export presets and project.godot match version.cfg.
func _presets() -> void:
	var p := ConfigFile.new()
	check(p.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	var seen := {}
	for sec in p.get_sections():
		if not sec.ends_with(".options"):
			continue
		var plat := str(p.get_value(sec.trim_suffix(".options"), "platform", ""))
		seen[plat] = true
		if plat == "Android":
			check(int(p.get_value(sec, "version/code", -1)) == Version.code(), "Android version/code = %d" % Version.code())
			check(str(p.get_value(sec, "version/name", "")) == Version.number(), "Android version/name = %s" % Version.number())
		if plat == "Windows Desktop":
			check(str(p.get_value(sec, "application/file_version", "")) == Version.number() + ".0", "Windows file_version")
			check(str(p.get_value(sec, "application/product_version", "")) == Version.number() + ".0", "Windows product_version")
	for sec in p.get_sections():
		if not sec.ends_with(".options"):
			check(str(p.get_value(sec, "include_filter", "")).contains("version.cfg"), "%s exports version.cfg" % sec)
	check(seen.has("Android") and seen.has("Windows Desktop"), "Android and Windows presets found")
	check(str(ProjectSettings.get_setting("application/config/version")) == Version.number(), "project config/version = version.cfg")


## The stamp script on a copy: sha written, presets set, file names printed.
func _stamp() -> void:
	var dir := ProjectSettings.globalize_path("user://stamp_test")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ["version.cfg", "export_presets.cfg", "project.godot"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://" + f), dir + "/" + f)
	var c := ConfigFile.new()
	c.load(dir + "/export_presets.cfg")
	c.set_value("preset.2.options", "version/code", 1)
	c.set_value("preset.2.options", "version/name", "0.0.9")
	c.save(dir + "/export_presets.cfg")
	var out := []
	var rc := OS.execute("env", ["STAMP_DIR=" + dir, "STAMP_SHA=abc1234", ProjectSettings.globalize_path("res://tools/stamp_version.sh"), "--stamp-only"], out, true)
	var text := "".join(out)
	check(rc == 0, "stamp script runs (%d: %s)" % [rc, text])
	check(text.contains("DiceOfTheDamned-0.1.2-Windows.zip") and text.contains("DiceOfTheDamned-0.1.2-Android.apk"), "stamp prints the export file names")
	Version.load_file(dir + "/version.cfg")
	check(Version.sha() == "abc1234" and Version.display() == "v0.1.2 (abc1234)", "stamped sha shown (%s)" % Version.display())
	check(Version.bug_subject() == "Bug report - v0.1.2 (abc1234)", "bug subject carries the sha")
	var p := ConfigFile.new()
	p.load(dir + "/export_presets.cfg")
	check(int(p.get_value("preset.2.options", "version/code", -1)) == 102 and str(p.get_value("preset.2.options", "version/name", "")) == "0.1.2", "stamp sets Android code/name from version.cfg")
	rc = OS.execute("env", ["STAMP_DIR=" + dir, ProjectSettings.globalize_path("res://tools/stamp_version.sh"), "--no-sha", "--stamp-only"], out, true)
	Version.load_file(dir + "/version.cfg")
	check(Version.sha() == "dev", "--no-sha (dev) falls back to dev")
	Version.load_file()


## Wrapped export in a throwaway git repo: the stub export copies version.cfg
## out while it runs (so the build saw the sha), and the 3 tracked files are
## restored afterwards, on success and on a failing export.
func _wrapped() -> void:
	var base := ProjectSettings.globalize_path("user://stamp_wrap")
	var dir := base + "/repo"
	OS.execute("rm", ["-rf", base])
	DirAccess.make_dir_recursive_absolute(dir + "/tools")
	for f in ["version.cfg", "export_presets.cfg", "project.godot", "tools/stamp_version.sh"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://" + f), dir + "/" + f)
	var sh := dir + "/tools/stamp_version.sh"
	OS.execute("chmod", ["+x", sh])
	var git := ["-C", dir, "-c", "user.name=t", "-c", "user.email=t@t"]
	OS.execute("git", ["init", "-q", dir])
	OS.execute("git", git + ["add", "-A"])
	OS.execute("git", git + ["commit", "-qm", "base"])
	var out := []
	var seen := base + "/seen.cfg"
	var rc := OS.execute("env", ["STAMP_SHA=abc1234", sh, "--", "sh", "-c", "cp '%s/version.cfg' '%s' && echo built" % [dir, seen]], out, true)
	check(rc == 0 and "".join(out).contains("built"), "wrapped export runs (%d: %s)" % [rc, "".join(out)])
	check(_status(dir) == "", "tree clean after a good export (%s)" % _status(dir))
	check(FileAccess.get_file_as_string(seen).contains("sha=\"abc1234\""), "the export saw the stamped sha")
	check(FileAccess.get_file_as_string(dir + "/version.cfg").contains("sha=\"dev\""), "version.cfg back to dev after export")
	out.clear()
	rc = OS.execute("env", ["STAMP_SHA=abc1234", sh, "--", "sh", "-c", "exit 3"], out, true)
	check(rc == 3, "failing export's status passed through (%d)" % rc)
	check(_status(dir) == "", "tree clean after a failing export (%s)" % _status(dir))
	rc = OS.execute(sh, [], out, true)
	check(rc == 2 and _status(dir) == "", "no export command: usage, nothing stamped")


func _status(dir: String) -> String:
	var out := []
	OS.execute("git", ["-C", dir, "status", "--porcelain"], out, true)
	return "".join(out).strip_edges()


func _label_ok(host: Node, what: String) -> void:
	var l := host.find_child("VersionLabel", true, false) as Label
	check(l != null and l.is_visible_in_tree(), "%s: version label shown" % what)
	if l == null:
		return
	var view := l.get_viewport().get_visible_rect()
	check(l.text == Version.display(), "%s: label reads %s" % [what, l.text])
	check(view.encloses(l.get_global_rect()) and l.get_global_rect().size.x > 0, "%s: label %s on screen %s" % [what, str(l.get_global_rect()), str(view)])
	var vp := l.get_viewport() as Window
	var screen_w := float(vp.size.x) if vp != null else view.size.x
	var px := l.label_settings.font_size * screen_w / view.size.x if l.label_settings else 0.0
	check(px >= Version.MIN_SCREEN_PX and px <= 40.0, "%s: label %.1f screen px (small, readable)" % [what, px])
	if _shot != "":
		await RenderingServer.frame_post_draw
		l.get_viewport().get_texture().get_image().save_png(_shot % what.replace(" ", "_"))


func _screens(size: Vector2i, label: String) -> void:
	root.size = size
	change_scene_to_file("res://scenes/title.tscn")
	await _frames(4)
	await _label_ok(current_scene, "title " + label)
	change_scene_to_file("res://scenes/bonfire.tscn")
	await _frames(6)
	var b := current_scene as Bonfire3D
	check(b != null, "%s: Bonfire loads" % label)
	if b == null:
		return
	b.pause_menu.open()
	await _frames(2)
	await _label_ok(b.pause_menu, "pause " + label)
	b.pause_menu.close()


func _run() -> void:
	_shot = OS.get_environment("VERSION_SHOT")
	_formats()
	_presets()
	_stamp()
	_wrapped()
	await _screens(Vector2i(1920, 1080), "PC")
	await _screens(Vector2i(844, 390), "844x390")
	await _screens(Vector2i(390, 844), "portrait")
	print("test_version: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
