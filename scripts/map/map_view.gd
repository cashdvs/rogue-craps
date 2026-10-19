## Draws a RunMap: rows bottom to top with the Boss at the top, edges, and a
## round marker per node (type letter + name). Reachable nodes glow and are
## clickable; visited ones are dimmed, the current one ringed in gold.
## Hovering a node (PC) or long-pressing it (touch) shows its map key line;
## the boss shows its name, cheat line(s) and the re-sit line.
## View only: emits node_pressed(id); MapRun decides what happens.
class_name MapView
extends Control

signal node_pressed(node_id: int)

const NT := MapGenData.NodeType
const NAMES: Dictionary = {NT.TABLE: "Table", NT.ELITE: "Elite", NT.EVENT: "Event", NT.SHOP: "Shop", NT.REST: "Rest", NT.BOSS: "Boss"}
const GLYPHS: Dictionary = {NT.TABLE: "T", NT.ELITE: "E", NT.EVENT: "?", NT.SHOP: "$", NT.REST: "R", NT.BOSS: "B"}
const COLORS: Dictionary = {NT.TABLE: Color(0.85, 0.8, 0.7), NT.ELITE: Color(0.85, 0.2, 0.15), NT.EVENT: Color(0.6, 0.45, 0.9),
	NT.SHOP: Color(0.91, 0.69, 0.29), NT.REST: Color(0.35, 0.75, 0.5), NT.BOSS: Color(1.0, 0.35, 0.05)}
const RADIUS: float = 26.0
## Hold this long on a node (touch) to show its tooltip bubble instead of travelling.
const LONG_PRESS_SEC: float = 0.45

var map: RunMap
var boss_name: String = ""
## The boss's cheat (and any extra twist), shown under its name.
var boss_rules: String = ""
## Shown under reachable Table nodes (an event's pending twist), else "".
var table_note: String = ""
var _time: float = 0.0
## Touch long-press: the held node (-1 = none), how long, and the bubble.
var _press_id: int = -1
var _press_t: float = 0.0
var bubble: Label


func _ready() -> void:
	tooltip_text = " "  # enables hover tooltips; _get_tooltip gives the text
	bubble = RunTheme.label("", 18)
	bubble.visible = false
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.custom_minimum_size = Vector2(420, 0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.03, 0.03, 0.95)
	sb.border_color = RunTheme.GOLD
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	bubble.add_theme_stylebox_override("normal", sb)
	add_child(bubble)


## Tooltip text for node `id`: its map key line; for the boss, its name, cheat
## line(s) and the re-sit line; a reachable Table also shows a pending twist.
func tooltip_for(id: int) -> String:
	var n := map.node(id) if map != null else null
	if n == null:
		return ""
	if id == map.boss_id:
		var out: Array[String] = [boss_name]
		if boss_rules != "":
			out.append(boss_rules)
		out.append(MapKey.FOOTER[1])
		return "\n".join(out)
	var line: String = MapKey.LINES[n.type]
	if n.type == NT.TABLE and table_note != "" and map.can_travel(id):
		line += "\n" + table_note
	return line


func _get_tooltip(at_position: Vector2) -> String:
	return tooltip_for(node_at(at_position))


## Draw map `m` with the boss name, its rule line and a note under reachable Tables.
func show_map(m: RunMap, boss: String, rules: String = "", note: String = "") -> void:
	map = m
	boss_name = boss
	boss_rules = rules
	table_note = note
	queue_redraw()


## Screen position of node `n`.
func node_pos(n: MapNode) -> Vector2:
	var margin := Vector2(120, 80)
	margin.y = clampf(size.y * 0.1, 50.0, 90.0)
	var area := size - margin * 2.0
	var x: float = margin.x + area.x * (0.5 if map.columns <= 1 else float(n.col) / float(map.columns - 1))
	if n.id == map.boss_id:
		x = margin.x + area.x * 0.5
	var y: float = size.y - margin.y - area.y * float(n.row) / float(map.rows)
	return Vector2(x, y)


## Id of the node under point `p`, or -1.
func node_at(p: Vector2) -> int:
	if map == null:
		return -1
	for n: MapNode in map.nodes.values():
		var r: float = RADIUS * (1.8 if n.id == map.boss_id else 1.0)
		if node_pos(n).distance_to(p) <= r + 6.0:
			return n.id
	return -1


func _process(delta: float) -> void:
	_time += delta
	if _press_id >= 0 and not bubble.visible:
		_press_t += delta
		if _press_t >= LONG_PRESS_SEC:
			_show_bubble(_press_id)
	if map != null and visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		_on_touch(touch)
		return
	var mb := event as InputEventMouseButton
	# Touch-emulated clicks are handled as touches (tap travels, hold shows the bubble).
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION:
		var id := node_at(mb.position)
		if id >= 0 and map.can_travel(id):
			node_pressed.emit(id)
			accept_event()


## Touch: a tap on a reachable node travels; a hold shows its tooltip bubble
## until the finger lifts (and then doesn't travel).
func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		_press_id = node_at(t.position)
		_press_t = 0.0
		return
	var id := _press_id
	var held := bubble.visible
	_press_id = -1
	bubble.visible = false
	if id >= 0 and not held and node_at(t.position) == id and map.can_travel(id):
		node_pressed.emit(id)
	accept_event()


func _show_bubble(id: int) -> void:
	bubble.text = tooltip_for(id)
	bubble.reset_size()
	var p := node_pos(map.node(id))
	bubble.position = Vector2(clampf(p.x - 210.0, 8.0, maxf(size.x - 428.0, 8.0)), maxf(p.y - RADIUS * 2.0 - bubble.size.y - 12.0, 8.0))
	bubble.visible = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), RunTheme.BG)
	# A warm glow rising from the bottom (the pit), fading toward the boss.
	for i in 12:
		var t := float(i) / 12.0
		draw_rect(Rect2(0, size.y * (1.0 - t * 0.5), size.x, size.y * 0.05), Color(0.6, 0.15, 0.03, 0.05 * (1.0 - t)))
	if map == null:
		return
	var reach := map.reachable()
	for n: MapNode in map.nodes.values():
		for t in n.next:
			var walked: bool = map.visited.has(t) and (map.visited.has(n.id))
			var c := RunTheme.GOLD if walked else Color(0.45, 0.3, 0.22, 0.55)
			draw_line(node_pos(n), node_pos(map.node(t)), c, 4.0 if walked else 2.0, true)
	var font := RunTheme.body_font
	for n: MapNode in map.nodes.values():
		var p := node_pos(n)
		var r: float = RADIUS * (1.8 if n.id == map.boss_id else 1.0)
		var col: Color = COLORS[n.type]
		var visited := map.visited.has(n.id)
		var can := reach.has(n.id)
		if can:
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			draw_circle(p, r + 10.0 + pulse * 4.0, Color(RunTheme.EMBER, 0.25 + 0.2 * pulse))
		draw_circle(p, r, Color(0.08, 0.05, 0.05))
		draw_circle(p, r - 3.0, col.darkened(0.55) if visited and n.id != map.current_id else col.darkened(0.1 if can else 0.35))
		if n.id == map.current_id:
			draw_arc(p, r + 6.0, 0, TAU, 40, RunTheme.GOLD, 4.0, true)
		var g: String = GLYPHS[n.type]
		var fs: int = 34 if n.id == map.boss_id else 24
		draw_string(RunTheme.title_font, p + Vector2(-fs * 0.32, fs * 0.36), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.04, 0.03))
		var name: String = boss_name if n.id == map.boss_id else NAMES[n.type]
		var tc := RunTheme.BONE if can or n.id == map.boss_id else RunTheme.ASH
		draw_string(font, p + Vector2(-60, r + 22), name, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, tc)
		if can and n.type == MapGenData.NodeType.TABLE and table_note != "":
			draw_string(font, p + Vector2(-150, r + 42), table_note, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, RunTheme.EMBER)
		if n.id == map.boss_id and boss_rules != "":
			draw_string(font, p + Vector2(-400, r + 46), boss_rules, HORIZONTAL_ALIGNMENT_CENTER, 800, 16, RunTheme.EMBER)
