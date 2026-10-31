## Dev sandbox launcher: pick an event, floor, boss and seed, then jump in
## (RunScreen with a SandboxPreset run). Debug builds only; a release build
## goes straight to the title. Scriptable for QA / art screenshots:
##   godot --path . res://scenes/sandbox.tscn -- --sandbox=boss --boss=pit_boss --floor=2 --seed=123
class_name SandboxScreen
extends Control

const RUN_SCENE := "res://scenes/run.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

var run_data: RunData
var event_pick: OptionButton
var floor_pick: OptionButton
var boss_pick: OptionButton
var seed_edit: LineEdit
## The RunScreen opened by launch(), or null.
var run_screen: RunScreen


func _ready() -> void:
	if not OS.is_debug_build():
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
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
	if p != null:
		launch.call_deferred(p)


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
	run_screen = (load(RUN_SCENE) as PackedScene).instantiate() as RunScreen
	run_screen.preset_run = p.build(run_data)
	run_screen.debug_table_stubs = true
	visible = false
	get_parent().add_child(run_screen)
