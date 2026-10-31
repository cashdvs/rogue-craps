## Build version, read from res://version.cfg (one source of truth; see
## tools/stamp_version.sh). display() "v0.1.2 (abc1234)", tag()
## "beta-0.1.2", file_stem() "DiceOfTheDamned-0.1.2", bug_subject() for the
## bug-report mail. Unstamped (dev) builds show "dev" for the sha.
class_name Version
extends RefCounted

const PATH := "res://version.cfg"
const GAME := "DiceOfTheDamned"
const DEV_SHA := "dev"
## Smallest on-screen font (physical px) for the version label.
const MIN_SCREEN_PX := 11.0
## Design font size (1920-wide canvas).
const FONT_PT := 24

## The file read; tests point it at a stamped copy.
static var path := PATH
static var _cfg: ConfigFile


static func _val(key: String, fallback: Variant) -> Variant:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)
	return _cfg.get_value("version", key, fallback)


## Re-read version.cfg, or another file (tests: a stamped copy).
static func load_file(file: String = PATH) -> void:
	path = file
	_cfg = null


## "0.1.2".
## Dev tools (the sandbox) on: `dev_tools` in version.cfg (beta review
## builds true, public releases false; missing = false).
static func dev_tools() -> bool:
	return bool(_val("dev_tools", false))


static func number() -> String:
	return "%s.%d" % [_val("major_minor", "0.1"), int(_val("patch", 0))]


## Android version/code, monotonic across releases:
## major*10000 + minor*100 + patch (0.1.2 -> 102, 0.2.0 -> 200).
static func code() -> int:
	return code_for(number())


## version/code for a "major.minor.patch" string (see code()).
static func code_for(ver: String) -> int:
	var p := ver.split(".")
	return int(p[0]) * 10000 + int(p[1]) * 100 + int(p[2])


## Short git sha stamped at export, or "dev".
static func sha() -> String:
	var s := str(_val("sha", DEV_SHA)).strip_edges()
	return s if not s.is_empty() else DEV_SHA


## Shown in the title/pause corner: "v0.1.2 (abc1234)", or "v0.1.2 (dev)".
static func display() -> String:
	return "v%s (%s)" % [number(), sha()]


## Release tag for git and the store beta track: "beta-0.1.2".
static func tag() -> String:
	return "beta-" + number()


## Export file name stem, before "-Windows.zip" / "-Android.apk":
## "DiceOfTheDamned-0.1.2".
static func file_stem() -> String:
	return "%s-%s" % [GAME, number()]


## Subject line for the (later) bug-report mailto:
## "Bug report - v0.1.2 (abc1234)".
static func bug_subject() -> String:
	return "Bug report - " + display()


## Font size (canvas px) that shows at least MIN_SCREEN_PX on a screen
## [param screen] px wide when the canvas is [param canvas] px wide.
static func font_for(canvas_w: float, screen_w: float) -> int:
	if screen_w <= 0.0:
		return FONT_PT
	return maxi(FONT_PT, ceili(MIN_SCREEN_PX * canvas_w / screen_w))


## A small corner label with display(), kept readable on phones. Add it to a
## full-rect Control or CanvasLayer; [param corner] is a Control.Preset.
static func make_label(corner: int = Control.PRESET_BOTTOM_RIGHT) -> Label:
	var l := VersionLabel.new()
	l.corner = corner
	return l


class VersionLabel:
	extends Label
	var corner: int = Control.PRESET_BOTTOM_RIGHT

	func _ready() -> void:
		name = "VersionLabel"
		text = Version.display()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_viewport().size_changed.connect(_fit)
		_fit()

	func _fit() -> void:
		var canvas := get_viewport().get_visible_rect().size
		var win := get_tree().root.size
		var screen_w: float = float(win.x) if win.x > 0 else canvas.x
		if get_viewport() != get_tree().root:
			screen_w = canvas.x
		label_settings = Palette.label_settings(Version.font_for(canvas.x, screen_w), Color(Palette.BONE, 0.75), 4)
		reset_size()
		set_anchors_and_offsets_preset(corner, Control.PRESET_MODE_MINSIZE, 16)
