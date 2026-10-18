## Title screen (after the studio splash): Play, Options, Quit. Play loads
## the project setting boot/play_scene (default PLAY_SCENE). Quit is hidden on
## web and mobile builds.
class_name TitleScreen
extends Control

const PLAY_SCENE := "res://scenes/bonfire.tscn"
const PLAY_SETTING := "boot/play_scene"

var play_button: Button
var options_button: Button
var quit_button: Button
var options: OptionsPanel
var menu: VBoxContainer
var _t: float = 0.0
var _glow: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.PIT_BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_glow = ColorRect.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 ember : source_color = vec4(0.91, 0.38, 0.16, 1.0);
uniform vec4 blood : source_color = vec4(0.23, 0.05, 0.08, 1.0);
uniform float pulse = 1.0;
void fragment() {
	vec2 p = UV - vec2(0.5, 1.05);
	p.x *= 1.6;
	float d = length(p);
	float glow = smoothstep(0.95, 0.0, d) * 0.55 * pulse;
	float vig = smoothstep(1.2, 0.35, length(UV - 0.5) * 1.4);
	COLOR = vec4(mix(blood.rgb * 0.5, ember.rgb, glow) * vig, glow * 0.9 + (1.0 - vig) * 0.0 + 0.35 * vig);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_glow.material = mat
	add_child(_glow)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var title := Label.new()
	title.text = "DICE OF THE DAMNED"
	title.label_settings = Palette.label_settings(110, Palette.BRASS_HI, 12, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Label.new()
	sub.text = "BONFIRE  -  playtest"
	sub.label_settings = Palette.label_settings(34, Palette.EMBER, 6, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 50)
	col.add_child(gap)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(menu)
	play_button = OptionsPanel.menu_button("PLAY", Palette.BURGUNDY)
	play_button.pressed.connect(play)
	options_button = OptionsPanel.menu_button("OPTIONS", Palette.FELT_DARK)
	options_button.pressed.connect(open_options)
	quit_button = OptionsPanel.menu_button("QUIT", Palette.PIT_BLACK)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	quit_button.visible = _can_quit()
	for b in [play_button, options_button, quit_button]:
		var c := CenterContainer.new()
		c.add_child(b)
		menu.add_child(c)
	var studio := Label.new()
	studio.text = "TINY ANVIL GAMES"
	studio.label_settings = Palette.label_settings(22, Color(Palette.BONE, 0.6), 4, true)
	studio.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	studio.position = Vector2(-130, -60)
	studio.size = Vector2(260, 40)
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(studio)
	options = OptionsPanel.new()
	options.visible = false
	var oc := CenterContainer.new()
	oc.set_anchors_preset(Control.PRESET_FULL_RECT)
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oc.add_child(options)
	add_child(oc)
	options.closed.connect(func() -> void:
		menu.visible = true
		options_button.grab_focus())
	play_button.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	(_glow.material as ShaderMaterial).set_shader_parameter("pulse", 0.85 + 0.15 * sin(_t * 2.2))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and options.visible:
		options.visible = false
		menu.visible = true
		get_viewport().set_input_as_handled()


static func play_scene_path() -> String:
	var p := str(ProjectSettings.get_setting(PLAY_SETTING, ""))
	return p if p != "" else PLAY_SCENE


func play() -> void:
	get_tree().change_scene_to_file(play_scene_path())


func open_options() -> void:
	menu.visible = false
	options.visible = true


func _can_quit() -> bool:
	var gs := get_node_or_null("/root/GameSettings")
	return gs.can_quit() if gs != null else not (OS.has_feature("web") or OS.has_feature("mobile"))
