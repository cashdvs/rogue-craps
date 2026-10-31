## Dev sandbox launcher: pick an event, floor, boss and seed, then jump in
## (RunScreen with a SandboxPreset run). Only with dev tools on (version.cfg
## dev_tools); otherwise it goes straight to the title. Scriptable for QA / art screenshots:
##   godot --path . res://scenes/sandbox.tscn -- --sandbox=boss --boss=pit_boss --floor=2 --seed=123
class_name SandboxScreen
extends Control

const RUN_SCENE := "res://scenes/run.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const SCENE := "res://scenes/sandbox.tscn"

## The --sandbox= boot jump runs once per launch (not on every title return).
static var _boot_done: bool = false

var run_data: RunData
var event_pick: OptionButton
var floor_pick: OptionButton
var boss_pick: OptionButton
var seed_edit: LineEdit
## The RunScreen opened by launch(), or null.
var run_screen: RunScreen


## The gate: the sandbox (menu, title button, --sandbox= flags) exists only
## when dev tools are on. Pass Version.dev_tools() (version.cfg dev_tools:
## on for beta review builds, off for public releases).
static func enabled(flag: bool) -> bool:
	if not flag:
		return false
	return true


## Where the sandbox scene goes on open: "" = stay (dev tools on), else the title.
static func entry_redirect(flag: bool) -> String:
	return "" if enabled(flag) else TITLE_SCENE


## Scene the title should jump to at boot for these args ("" = none):
## the sandbox when --sandbox= is given with dev tools on, never when off.
static func boot_target(flag: bool, args: PackedStringArray) -> String:
	return SCENE if enabled(flag) and SandboxPreset.from_args(args) != null else ""


func _ready() -> void:
	var to := entry_redirect(Version.dev_tools())
	if to != "":
		get_tree().change_scene_to_file.call_deferred(to)
		return
	run_data = load("res://resources/map/bonfire_run.tres") as RunData
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = RunTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(RunTheme.label("SANDBOX (dev only)", 36, RunTheme.GOLD))
	event_pick = _row(box, "Event", ["table", "elite", "boss", "shop"])
	floor_pick = _row(box, "Floor", ["1", "2", "3"])
	boss_pick = _row(box, "Boss", [])
	floor_pick.item_selected.connect(func(_i: int) -> void: _fill_bosses())
	_fill_bosses()
	var hb := HBoxContainer.new()
	var sl := RunTheme.label("Seed", 24, RunTheme.GOLD)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.custom_minimum_size = Vector2(120, 0)
	hb.add_child(sl)
	seed_edit = LineEdit.new()
	seed_edit.text = "1"
	seed_edit.custom_minimum_size = Vector2(240, 0)
	hb.add_child(seed_edit)
	box.add_child(hb)
	var go := RunTheme.button("Launch", 26)
	go.pressed.connect(func() -> void: launch(current_preset()))
	box.add_child(go)
	var p := SandboxPreset.from_args(OS.get_cmdline_user_args())
	if p != null and enabled(Version.dev_tools()):
		launch.call_deferred(p)


## Title screen hook (dev tools on only): a SANDBOX button in `menu`, and
## on normal boot with --sandbox=... jump straight in, once per launch.
static func title_hook(title: Control, menu: Container, flag: bool = Version.dev_tools()) -> void:
	if not enabled(flag):
		return
	var b := OptionsPanel.menu_button("SANDBOX", Palette.FELT_DARK)
	b.name = "SandboxButton"
	b.pressed.connect(func() -> void: title.get_tree().change_scene_to_file(SCENE))
	var c := CenterContainer.new()
	c.add_child(b)
	menu.add_child(c)
	if not _boot_done and boot_target(flag, OS.get_cmdline_user_args()) != "":
		_boot_done = true
		title.get_tree().change_scene_to_file.call_deferred(SCENE)


func _row(box: VBoxContainer, title: String, items: Array) -> OptionButton:
	var hb := HBoxContainer.new()
	var l := RunTheme.label(title, 24, RunTheme.GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(120, 0)
	hb.add_child(l)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(240, 0)
	for it in items:
		o.add_item(it)
	hb.add_child(o)
	box.add_child(hb)
	return o


func _fill_bosses() -> void:
	boss_pick.clear()
	boss_pick.add_item("(seeded)")
	for id in SandboxPreset.boss_ids(run_data, floor_pick.selected + 1):
		boss_pick.add_item(String(id))


## The preset the menu shows right now.
func current_preset() -> SandboxPreset:
	var p := SandboxPreset.new()
	p.event = StringName(event_pick.get_item_text(event_pick.selected))
	p.floor_num = floor_pick.selected + 1
	p.boss_id = &"" if boss_pick.selected <= 0 else StringName(boss_pick.get_item_text(boss_pick.selected))
	p.seed_value = seed_edit.text.to_int()
	return p


## Open the run screen on the preset's event.
func launch(p: SandboxPreset) -> void:
	print("sandbox: %s floor %d boss '%s' seed %d" % [p.event, p.floor_num, p.boss_id, p.seed_value])
	run_screen = (load(RUN_SCENE) as PackedScene).instantiate() as RunScreen
	run_screen.preset_run = p.build(run_data)
	run_screen.debug_table_stubs = true
	visible = false
	get_parent().add_child(run_screen)
