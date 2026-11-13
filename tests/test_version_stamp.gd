## Export stamp for version.cfg (VersionStamp). A dev tree stays
## "v0.1.8 (dev)". A sha plus a CI build number becomes "v0.1.8.42 (abc1234)".
## The export plugin only packs that copy; this checks the stamp itself.
##   godot --headless --path . --script res://tests/test_version_stamp.gd
extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _run() -> void:
	var raw := FileAccess.get_file_as_string("res://version.cfg")
	check(Version.build_number() == 0 and Version.display() == "v0.1.8 (dev)", "dev corner is v0.1.8 (dev)")
	check(VersionStamp.apply(raw, "nope", 0) == raw, "a bad sha and no build leave the file alone")
	check(VersionStamp.hex7("dev") == "" and VersionStamp.build_from_env("") == 0 and VersionStamp.build_from_env("0") == 0, "dev and 0 are not a stamp")
	check(VersionStamp.short_sha("DEADBEEFcafe", "", "") == "deadbee", "GITHUB_SHA wins and is 7 lowercase hex chars")
	check(VersionStamp.short_sha("", "ref: refs/heads/main\n", "0123456789abcdef\n") == "0123456", "a git ref resolves to its sha")
	check(VersionStamp.short_sha("", "abc1234\n", "") == "abc1234", "a detached HEAD sha is used when env is empty")
	check(VersionStamp.build_from_env("42") == 42, "GITHUB_RUN_NUMBER 42")
	var stamped := VersionStamp.apply(raw, "ABC1234dead", 42)
	check("sha=\"abc1234\"" in stamped and "\nbuild=42" in stamped and "dev_tools=true" in stamped, "stamp writes sha and build and keeps dev_tools")
	var path := "user://version_stamp_test.cfg"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(stamped)
	f.close()
	Version.load_file(ProjectSettings.globalize_path(path))
	check(Version.sha() == "abc1234" and Version.build_number() == 42, "stamped file reads sha and build")
	check(Version.number() == "0.1.8" and Version.display() == "v0.1.8.42 (abc1234)", "corner shows v0.1.8.42 (abc1234), got %s" % Version.display())
	Version.load_file()
	check(Version.display() == "v0.1.8 (dev)" and Version.build_number() == 0, "loading the repo file restores dev")
	var plug := load("res://addons/version_stamp/export_plugin.gd")
	check(plug != null, "export plugin script parses")
	print("=== test_version_stamp: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
