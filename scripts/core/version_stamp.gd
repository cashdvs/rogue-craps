## Stamps the text of version.cfg for an export: a 7-character git sha and
## the CI build number. Dev checkouts keep sha "dev" and build 0, so the
## title corner stays "v0.1.8 (dev)". The export plugin calls this; it does
## not run a shell. See docs/ARCHITECTURE.md (Build version).
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


## Seven hex chars from GITHUB_SHA, else from `.git/HEAD` (a sha, or a
## `ref:` line plus that ref's body). "" when neither is a commit.
static func short_sha(env_sha: String, head: String, ref_body: String) -> String:
	var env := hex7(env_sha)
	if env != "":
		return env
	var h := head.strip_edges()
	if h.begins_with("ref:"):
		return hex7(ref_body)
	return hex7(h)


## GITHUB_RUN_NUMBER, or 0 when it is missing or not an integer.
static func build_from_env(run_number: String) -> int:
	var t := run_number.strip_edges()
	if t.is_valid_int():
		var n := int(t)
		return n if n > 0 else 0
	return 0


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
