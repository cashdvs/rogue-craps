## Export stamp for version.cfg (VersionStamp). A dev tree stays
## "v0.1.8 (dev)". A sha plus a CI build number becomes "v0.1.8.42 (abc1234)".
## The export plugin only packs that copy; this checks the stamp itself,
## including a worktree `.git` file and a branch that lives only in
## packed-refs. Git fixtures are temp dirs under user://, and the sha
## argument is "" so a real GITHUB_SHA on CI cannot hide them.
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
	check(VersionStamp.hex7("notasha") == "", "non-hex sha of 7+ chars is rejected (notasha)")
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
	var plug_src := FileAccess.get_file_as_string("res://addons/version_stamp/export_plugin.gd")
	check("sha_for_root" in plug_src, "export plugin asks VersionStamp to read .git")
	_git_layouts()
	_excludes_addons()
	print("=== test_version_stamp: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Fake .git trees under user://. "" is passed as the env sha so CI's
## GITHUB_SHA cannot skip the fixture. The user:// path contains spaces;
## the absolute gitdir case keeps those spaces inside the file.
func _git_layouts() -> void:
	var base := ProjectSettings.globalize_path("user://version_stamp_git")
	_rm_tree(base)
	var loose_sha := "abc1234deadbeef0123456789abcdef012345678"
	var topic_sha := "c0ffee0123456789abcdef0123456789abcdef01"

	var loose := base.path_join("loose")
	_write(loose.path_join(".git/HEAD"), "ref: refs/heads/main\n")
	_write(loose.path_join(".git/refs/heads/main"), loose_sha + "\n")
	check(VersionStamp.sha_for_root("", loose) == "abc1234", "loose ref in a normal .git dir, got %s" % VersionStamp.sha_for_root("", loose))
	check(VersionStamp.sha_for_root("DEADBEEFcafe", loose) == "deadbee", "GITHUB_SHA wins over the loose ref")

	var wt := base.path_join("worktree/wt")
	_write(wt.path_join(".git"), "gitdir: ../repo.git/worktrees/topic\n")
	check(FileAccess.file_exists(wt.path_join(".git")) and not DirAccess.dir_exists_absolute(wt.path_join(".git")), "worktree .git is a file")
	var gitdir := base.path_join("worktree/repo.git/worktrees/topic")
	_write(gitdir.path_join("HEAD"), "ref: refs/heads/topic\n")
	_write(gitdir.path_join("commondir"), "../..\n")
	_write(base.path_join("worktree/repo.git/refs/heads/topic"), topic_sha + "\n")
	var got := VersionStamp.sha_for_root("", wt)
	check(got == "c0ffee0", "worktree gitdir + commondir loose ref, got %s" % got)

	var packed := base.path_join("packed")
	_write(packed.path_join(".git/HEAD"), "ref: refs/heads/main\n")
	_write(packed.path_join(".git/packed-refs"), _packed_main())
	got = VersionStamp.sha_for_root("", packed)
	check(got == "deadbee", "branch ref only in packed-refs, got %s" % got)
	_write(packed.path_join(".git/refs/heads/main"), loose_sha + "\n")
	got = VersionStamp.sha_for_root("", packed)
	check(got == "abc1234", "a loose ref wins over packed-refs, got %s" % got)

	var wt_root := base.path_join("wtpack/wt")
	var wt_git := base.path_join("wtpack/repo.git/worktrees/topic")
	_write(wt_root.path_join(".git"), "gitdir: %s\n" % wt_git)
	_write(wt_git.path_join("HEAD"), "ref: refs/heads/topic\n")
	_write(wt_git.path_join("commondir"), "../..\n")
	_write(base.path_join("wtpack/repo.git/packed-refs"), _packed_topic(topic_sha))
	got = VersionStamp.sha_for_root("", wt_root)
	check(got == "c0ffee0", "worktree ref only in the common packed-refs, got %s" % got)
	_rm_tree(base)


func _packed_main() -> String:
	return "# pack-refs with: peeled fully-peeled sorted\n" \
			+ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/mainline\n" \
			+ "deadbeefcafebabe0123456789abcdef01234567 refs/heads/main\n" \
			+ "^bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n"


func _packed_topic(topic_sha: String) -> String:
	return "# pack-refs with: peeled fully-peeled sorted\n" \
			+ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/heads/topic-old\n" \
			+ topic_sha + " refs/heads/topic\n"


## Every preset keeps the editor addon out of the game pack. The stamp
## still runs in the editor process during export.
func _excludes_addons() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg loads")
	var n := 0
	for sec in cfg.get_sections():
		var name := str(sec)
		if name.ends_with(".options"):
			continue
		n += 1
		var filt := str(cfg.get_value(name, "exclude_filter", ""))
		check("addons/*" in filt, "%s exclude_filter contains addons/* (%s)" % [name, filt])
	check(n == 3, "three presets exclude addons, saw %d" % n)


func _write(path: String, body: String) -> void:
	var parent := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(parent)
	if not DirAccess.dir_exists_absolute(parent):
		check(false, "mkdir %s" % parent)
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		check(false, "write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(body)
	f.close()


## `.git` is a hidden name, so the listing has to include hidden entries
## or the temp checkout is left behind for the next run.
func _rm_tree(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		var dir := DirAccess.open(path)
		if dir == null:
			return
		dir.set_include_hidden(true)
		var dirs := dir.get_directories()
		for i in dirs.size():
			_rm_tree(path.path_join(dirs[i]))
		var files := dir.get_files()
		for i in files.size():
			dir.remove(files[i])
		DirAccess.remove_absolute(path)
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
