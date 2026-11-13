## Stamps the text of version.cfg for an export: a 7-character git sha and
## the CI build number. Dev checkouts keep sha "dev" and build 0, so the
## title corner stays "v0.1.8 (dev)". The export plugin calls this; it does
## not run a shell. When GITHUB_SHA is empty, `sha_for_root` reads `.git`
## (a directory, a worktree `gitdir:` file, or packed-refs). See
## docs/ARCHITECTURE.md (Build version).
class_name VersionStamp
extends RefCounted


## Rewrite `text` (a version.cfg). An empty or non-hex sha is left alone.
## `build` <= 0 leaves the build line alone. Missing keys are added.
static func apply(text: String, sha: String, build: int) -> String:
	var out := text
	var short := hex7(sha)
	if short != "":
		out = _set_line(out, "sha", "\"%s\"" % short)
	if build > 0:
		out = _set_line(out, "build", str(build))
	return out


## First 7 hex digits, or "" when `raw` is not a commit sha.
static func hex7(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	if s.length() < 7:
		return ""
	s = s.substr(0, 7)
	for i in s.length():
		var c := s.unicode_at(i)
		var hex := (c >= 48 and c <= 57) or (c >= 97 and c <= 102)
		if not hex:
			return ""
	return s


## Seven hex chars from GITHUB_SHA, else from a HEAD string (a sha, or a
## `ref:` line plus that ref's body). "" when neither is a commit.
## `sha_for_root` is what reads the `.git` files before calling this.
static func short_sha(env_sha: String, head: String, ref_body: String) -> String:
	var env := hex7(env_sha)
	if env != "":
		return env
	var h := head.strip_edges()
	if h.begins_with("ref:"):
		return hex7(ref_body)
	return hex7(h)


## Seven hex chars for an export of the checkout at `root`. `env_sha`
## (GITHUB_SHA) wins. Otherwise read `.git`: a directory, or a worktree
## file whose line is `gitdir: <path>` (HEAD lives in that directory; a
## `commondir` file points at the shared refs). A relative `gitdir` or
## `commondir` path is resolved from the directory that contains the
## file. A branch ref may be a loose file or one packed-refs line
## `<sha> refs/heads/<name>`. "" when nothing is a commit sha, so the
## caller leaves version.cfg at "dev".
static func sha_for_root(env_sha: String, root: String) -> String:
	var env := hex7(env_sha)
	if env != "":
		return env
	return _sha_from_git(root)


## GITHUB_RUN_NUMBER, or 0 when it is missing or not an integer.
static func build_from_env(run_number: String) -> int:
	var t := run_number.strip_edges()
	if t.is_valid_int():
		var n := int(t)
		return n if n > 0 else 0
	return 0


## Seven hex chars from the checkout at `root`, or "" when `.git` cannot
## name a commit. Does not look at GITHUB_SHA.
static func _sha_from_git(root: String) -> String:
	var git_dir := _git_dir(root)
	if git_dir == "":
		return ""
	var head := FileAccess.get_file_as_string(git_dir.path_join("HEAD"))
	var ref_body := ""
	var h := head.strip_edges()
	if h.begins_with("ref:"):
		ref_body = _ref_text(git_dir, h.substr(4).strip_edges())
	return short_sha("", head, ref_body)


## Directory that holds HEAD. A linked worktree stores `.git` as a file,
## not a directory: the line `gitdir: <path>` is the real directory.
## A relative path starts at the checkout (the folder that contains `.git`).
static func _git_dir(root: String) -> String:
	var git_path := root.path_join(".git")
	if FileAccess.file_exists(git_path):
		var text := FileAccess.get_file_as_string(git_path).strip_edges()
		var nl := text.find("\n")
		var line := text if nl < 0 else text.substr(0, nl).strip_edges()
		if not line.begins_with("gitdir:"):
			return ""
		var dir := line.substr("gitdir:".length()).strip_edges()
		if dir == "":
			return ""
		if not dir.is_absolute_path():
			dir = root.path_join(dir)
		return dir.simplify_path()
	if DirAccess.dir_exists_absolute(git_path):
		return git_path.simplify_path()
	return ""


## Shared git directory. Worktrees keep a `commondir` file (often `../..`)
## so branch refs and packed-refs are read from the main `.git`, not from
## the worktree's private directory. A normal checkout has no such file.
static func _common_dir(git_dir: String) -> String:
	var path := git_dir.path_join("commondir")
	if not FileAccess.file_exists(path):
		return git_dir
	var raw := FileAccess.get_file_as_string(path).strip_edges()
	if raw == "":
		return git_dir
	if not raw.is_absolute_path():
		raw = git_dir.path_join(raw)
	return raw.simplify_path()


## Body of a ref such as `refs/heads/main`. A loose file wins (the worktree
## directory first, then the common dir). Otherwise the packed-refs line.
static func _ref_text(git_dir: String, rel: String) -> String:
	if rel == "":
		return ""
	var loose := _loose(git_dir, rel)
	var common := _common_dir(git_dir)
	if loose == "" and common != git_dir:
		loose = _loose(common, rel)
	if loose != "":
		return loose
	var packed := _packed(common, rel)
	if packed == "" and common != git_dir:
		packed = _packed(git_dir, rel)
	return packed


## Text of a loose ref file, or "" when that file is missing or empty.
static func _loose(base: String, rel: String) -> String:
	var path := base.path_join(rel)
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


## Sha from `packed-refs` for `rel`, or "". Lines look like
## `<sha> refs/heads/<name>`. Comments (`#`) and peeled tags (`^`) are skipped.
static func _packed(git_dir: String, rel: String) -> String:
	var path := git_dir.path_join("packed-refs")
	if not FileAccess.file_exists(path):
		return ""
	var want := rel.strip_edges()
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var t := lines[i].strip_edges()
		if t == "" or t.begins_with("#") or t.begins_with("^"):
			continue
		var sp := t.find(" ")
		if sp <= 0:
			continue
		if t.substr(sp + 1).strip_edges() == want:
			return t.substr(0, sp)
	return ""


static func _set_line(text: String, key: String, value: String) -> String:
	var lines := text.split("\n")
	var found := false
	for i in lines.size():
		var trimmed := lines[i].strip_edges()
		if trimmed.begins_with(key + "="):
			lines[i] = "%s=%s" % [key, value]
			found = true
			break
	if not found:
		if lines.size() > 0 and lines[lines.size() - 1] == "":
			lines.insert(lines.size() - 1, "%s=%s" % [key, value])
		else:
			lines.append("%s=%s" % [key, value])
	return "\n".join(lines)
