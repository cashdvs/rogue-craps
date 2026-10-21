## Onboarding hints v1 (design/onboarding_hints_v1.md): the Table 1 teaching
## flow (TH0-TH10) and the just-in-time hints (JIT1-5). One small bubble at
## a time, pointing at the die / card / button involved. The game stays live
## under it: most hints close when you do what they say, and every one has
## an ✕ (Esc on PC, a tap outside on mobile).
##
## The table asks with request(id, ctx, still); a hint that arrives while
## another is up waits, and shows only if `still` is true once the first one
## closes (else it's dropped and can fire again later). "Shown" counts are
## per profile: GameSettings.hints_seen (user://settings.cfg).
class_name BonfireTutorial
extends PanelContainer

signal skipped
signal done
## A hint went up (tests / analytics).
signal shown_hint(id: StringName)
## The seen counts changed (the table saves them).
signal seen_changed(seen: Dictionary)

## Text: {pot} = Click / Tap, {n} = cold dice, {odds} = "1 in 3".
## "touch": the mobile text, when it differs. "anchor": what it points at
## (the table resolves it to a screen rect). "dismiss": the actions that
## close it (&"any" = the next one). "timeout": seconds. "max": times per
## profile (default 1). "tutorial": a Table 1 hint (TH, Skip marks it seen);
## "any_table": a TH hint that may fire on any table (TH9).
const HINTS := {
	&"th0_throw": {"text": "Grab the dice and flick them onto the felt.", "touch": "Grab the dice and swipe them onto the felt.",
		"anchor": &"hand", "dismiss": [&"thrown"], "tutorial": true},
	&"th1_lit": {"text": "Glowing dice can score. Grey dice are cold.", "anchor": &"lit_dice", "dismiss": [&"potted"], "tutorial": true},
	&"th2_pot": {"text": "{pot} glowing dice to pot one combo.", "anchor": &"lit_dice", "dismiss": [&"valid_selection"], "tutorial": true},
	&"th2b_nofit": {"text": "That die doesn't fit this combo.", "anchor": &"refused_die", "dismiss": [&"any"], "timeout": 2.5, "max": 3, "tutorial": true},
	&"th3_pending": {"text": "This combo claims that bounty. Bank to lock it.", "anchor": &"pulsing_card", "dismiss": [&"bank", &"rethrow"], "tutorial": true},
	&"th4_choice": {"text": "Bank keeps your points. Or throw the cold dice again.", "anchor": &"buttons", "dismiss": [&"bank", &"rethrow"], "tutorial": true},
	&"th5_risk": {"text": "{n} cold dice: {odds} chance nothing lights.", "anchor": &"risk", "dismiss": [&"bank", &"rethrow"], "tutorial": true},
	&"th6_hot": {"text": "Every die scored! All {all} come back, plus {mult} mult.", "anchor": &"mult", "dismiss": [&"thrown"], "timeout": 4.0, "tutorial": true},
	&"th7_claimed": {"text": "Claimed! Claim every card to clear the table.", "anchor": &"stamped_card", "timeout": 4.0, "tutorial": true},
	&"th8_points": {"text": "Points turn into Embers after the table. Spend them in shops.", "anchor": &"embers", "timeout": 4.0, "tutorial": true},
	&"th9_bust": {"text": "Nothing lit, so you bust: lose the hand's points and {soul} Soul.", "anchor": &"soul", "timeout": 4.0, "tutorial": true, "any_table": true},
	&"th10_cleared": {"text": "Cleared! Chase the bonus card, or Leave table.", "anchor": &"bonus_leave", "dismiss": [&"leave", &"thrown"], "tutorial": true},
	&"jit1_last": {"text": "Last hand! Each unclaimed bounty costs {soul} Soul.", "anchor": &"unclaimed_cards", "dismiss": [&"thrown"]},
	&"jit2_free": {"text": "Nothing lit on a full throw: free rethrow.", "anchor": &"tray", "timeout": 3.0},
	&"jit3_seal": {"text": "Seals level up a combo: bigger base, bigger mult.", "anchor": &"seal_options", "dismiss": [&"seal_pick"]},
	&"jit4_wild": {"text": "Wild faces pick their best value for you.", "anchor": &"wild_die", "timeout": 3.0},
	# Nerve (nerve_v1.md; PM Oct 20): HN1 only on the first bust rescue a
	# profile ever sees; after that the rescue prompt alone.
	&"hn1_nerve": {"text": "Nothing lit, but Nerve can turn one die to save it.", "anchor": &"tray", "dismiss": [&"thrown"], "timeout": 5.0},
	&"jit5_twist": {"text": "This table has a twist. Check its rule card.", "anchor": &"rules", "dismiss": [&"thrown"]},
	# Bounty and Seal hints (onboarding_hints_v1.md, Oct 19; just-in-time:
	# Skip doesn't mark them, only Tutorial hints Off stops them). {soul} =
	# the real Soul cost at that table. HB1 / HB2 / HB6 (the map's table
	# preview) and HS3 / HS4 (shop, rewards) are shown by the run screens:
	# they call request() with these ids; the table wires HB3-HB5 and HS2.
	&"hb1_bounties": {"text": "Bounties: combos you must pot and bank before hands run out.", "anchor": &"preview_bounties", "dismiss": [&"sit_down"]},
	&"hb2_cost": {"text": "Each bounty still unclaimed at the end costs {soul} Soul.", "anchor": &"preview_cost", "dismiss": [&"sit_down"]},
	&"hb3_bonus": {"text": "The bonus card is optional: claim it for extra Embers.", "anchor": &"bonus_card", "dismiss": [&"thrown"], "timeout": 4.0},
	&"hb4_bigger": {"text": "Bigger combos count too: {combo} claims a {card} card.", "anchor": &"pulsing_card", "dismiss": [&"bank", &"rethrow"]},
	&"hb5_lost": {"text": "That bust lost your pending bounty; bank sooner to keep it.", "anchor": &"lost_card", "timeout": 4.0},
	&"hb6_boss": {"text": "Boss bounties work the same, and you get one re-sit.", "anchor": &"preview_rule", "dismiss": [&"sit_down"]},
	&"hs2_sealed": {"text": "Your Seal boosts this combo: more base and more mult.", "anchor": &"pot_preview", "dismiss": [&"any"], "timeout": 3.0},
	&"hs3_stack": {"text": "Seals stack: buy the same one again for another level.", "anchor": &"seal_button", "dismiss": [&"leave_shop"]},
	&"hs4_rare": {"text": "Rare Seals move or add Seal levels; read the card first.", "anchor": &"rare_seal", "dismiss": [&"seal_pick", &"seal_skip"]},
}
const NUMBER_WORDS: Array[String] = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
## Bubble look (design pt; x ui_pt_px). Text cap ~9 pt, 12 pt Barlow-ish.
const BUBBLE_W_PT := 190.0
const TEXT_PT := 12.0
const GAP_PT := 8.0

var label: Label
var close_button: Button
var skip_button: Button
## The hint on screen (&"" = none).
var current: StringName = &""
## Hint ids in the order they went up this table (tests).
var shown: Array[StringName] = []
## id -> times shown (per profile; loaded / saved by the table).
var seen: Dictionary = {}
## The Table 1 tutorial (TH hints, Skip link) is running.
var active: bool = false
## Hints at all (Settings: Tutorial hints On/Off).
var enabled: bool = true
## True once the table's end screen is up (stop()): no hint may show until
## the next table resets it (start() or the table's new run).
var stopped: bool = false
## Mobile wording ("Tap", "swipe") and dismiss (tap outside).
var touch: bool = false
## Design px per pt (BonfireHud.ui_pt_px).
var pt_px: float = 2.0
## (anchor: StringName, ctx: Dictionary) -> Rect2 in this control's parent
## space; Rect2() = no anchor (the bubble sits top centre).
var anchor_provider: Callable
var _ctx: Dictionary = {}
var _queue: Array = []
var _left: float = -1.0


func _init() -> void:
	name = "BonfireTutorial"
	add_theme_stylebox_override("panel", Palette.ink_box(Color(Palette.PIT_BLACK, 0.92), 10, 3, Palette.BRASS))
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	m.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	label = Label.new()
	label.label_settings = Palette.label_settings(24, Palette.BONE, 4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	close_button = Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.tooltip_text = "Close (Esc)"
	close_button.pressed.connect(dismiss)
	top.add_child(close_button)
	skip_button = Button.new()
	skip_button.text = "Skip tutorial"
	skip_button.flat = true
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_button.add_theme_color_override("font_color", Palette.BRASS_HI)
	skip_button.pressed.connect(skip)
	box.add_child(skip_button)
	_apply_scale()


## The Table 1 tutorial starts (TH hints on, seeding is the table's).
func start() -> void:
	active = true
	stopped = false
	shown.clear()
	_queue.clear()
	current = &""
	visible = false


## The table ended (end screen up, #103 N6): hide the hint, forget every
## waiting hint and refuse new ones until the next table.
func stop() -> void:
	visible = false
	current = &""
	_left = -1.0
	_queue.clear()
	active = false
	stopped = true


## Sizes the bubble for the screen: px = screen pixels per design point.
func set_ui_scale(px: float) -> void:
	pt_px = px
	_apply_scale()


func _apply_scale() -> void:
	var fs := int(round(TEXT_PT * pt_px))
	label.label_settings.font_size = fs
	label.label_settings.outline_size = maxi(2, int(pt_px * 1.5))
	label.custom_minimum_size = Vector2((BUBBLE_W_PT - 30.0) * pt_px, 0)
	close_button.add_theme_font_size_override("font_size", fs)
	skip_button.add_theme_font_size_override("font_size", int(round(TEXT_PT * 0.8 * pt_px)))
	custom_minimum_size = Vector2(BUBBLE_W_PT * pt_px, 0)


## Could hint `id` show now (ignoring a hint already up)?
func can_show(id: StringName) -> bool:
	if stopped or not enabled or not HINTS.has(id):
		return false
	var h: Dictionary = HINTS[id]
	if int(seen.get(id, 0)) >= int(h.get("max", 1)):
		return false
	if bool(h.get("tutorial", false)) and not active and not bool(h.get("any_table", false)):
		return false
	return true


## Asks for hint `id` (ctx fills its text / anchor: n, odds, all, mult,
## soul, die, card ...). still: re-checked if it has to wait. True if shown.
func request(id: StringName, ctx: Dictionary = {}, still: Callable = Callable()) -> bool:
	if not can_show(id):
		return false
	if current != &"":
		if current != id and not _queue.any(func(q: Array) -> bool: return q[0] == id):
			_queue.append([id, ctx, still])
		return false
	_show(id, ctx)
	return true


func _show(id: StringName, ctx: Dictionary) -> void:
	var h: Dictionary = HINTS[id]
	current = id
	_ctx = ctx
	shown.append(id)
	seen[id] = int(seen.get(id, 0)) + 1
	label.text = text_for(id, ctx)
	skip_button.visible = active and bool(h.get("tutorial", false))
	_left = float(h.get("timeout", -1.0))
	visible = true
	reset_size()
	_place()
	seen_changed.emit(seen)
	shown_hint.emit(id)


## The hint's text with its {fields} filled.
func text_for(id: StringName, ctx: Dictionary = {}) -> String:
	var h: Dictionary = HINTS[id]
	var s: String = h.get("touch", h["text"]) if touch else h["text"]
	var all := int(ctx.get("all", 5))
	s = s.format({"pot": "Tap" if touch else "Click", "n": str(ctx.get("n", 2)), "odds": str(ctx.get("odds", "1 in 3")),
		"all": NUMBER_WORDS[all] if all >= 0 and all < NUMBER_WORDS.size() else str(all),
		"mult": str(ctx.get("mult", 1)), "soul": str(ctx.get("soul", 1)),
		"combo": str(ctx.get("combo", "Quads")), "card": str(ctx.get("card_name", "Trips"))})
	if id == &"hb4_bigger" and bool(ctx.get("run", false)):
		# "Bigger combos count too: a Run of 4 claims Run of 3."
		s = "Bigger combos count too: a %s claims %s." % [str(ctx.get("combo", "Run of 4")), str(ctx.get("card_name", "Run of 3"))]
	return s


## The player did something: closes the hint if that's its dismiss action.
## Actions: &"thrown", &"potted", &"valid_selection", &"bank", &"rethrow",
## &"leave", &"seal_pick" (and anything else counts for &"any").
func on_action(action: StringName) -> void:
	if current == &"":
		return
	var d: Array = HINTS[current].get("dismiss", [])
	if d.has(action) or d.has(&"any"):
		dismiss()


## Closes the hint on screen; the next waiting one shows if still true.
func dismiss() -> void:
	visible = false
	current = &""
	_left = -1.0
	while not _queue.is_empty():
		var q: Array = _queue.pop_front()
		var still: Callable = q[2]
		if can_show(q[0]) and (not still.is_valid() or bool(still.call())):
			_show(q[0], q[1])
			return


## Skip tutorial: every TH hint counts as seen, seeding stops (the table
## listens to `skipped`), the just-in-time hints stay.
func skip() -> void:
	for id: StringName in HINTS:
		if bool(HINTS[id].get("tutorial", false)):
			seen[id] = maxi(int(seen.get(id, 0)), int(HINTS[id].get("max", 1)))
	_queue = _queue.filter(func(q: Array) -> bool: return not bool(HINTS[q[0]].get("tutorial", false)))
	active = false
	seen_changed.emit(seen)
	if current != &"" and bool(HINTS[current].get("tutorial", false)):
		dismiss()
	skipped.emit()
	done.emit()


func _process(delta: float) -> void:
	if current == &"":
		return
	if _left > 0.0:
		_left -= delta / maxf(Engine.time_scale, 0.001)
		if _left <= 0.0:
			dismiss()
			return
	_place()


## Next to its anchor: beside it at the screen's left / right edge, else
## above it in the lower half and below it in the upper half; clamped on
## screen.
func _place() -> void:
	var view := get_parent_area_size() if get_parent() is Control else Vector2(1920, 1080)
	var sz := size
	var a := Rect2()
	if anchor_provider.is_valid():
		a = anchor_provider.call(HINTS[current].get("anchor", &""), _ctx)
	var gap := GAP_PT * pt_px
	var p := Vector2((view.x - sz.x) * 0.5, 150.0)
	if a.size != Vector2.ZERO or a.position != Vector2.ZERO:
		var c := a.get_center()
		if c.x > view.x * 0.72 and a.size.x < view.x * 0.3:
			# Right-edge anchors (Bank / Throw, the cards): beside, to the left.
			p = Vector2(a.position.x - sz.x - gap, c.y - sz.y * 0.5)
		elif c.x < view.x * 0.2 and a.size.x < view.x * 0.3:
			# Left-edge anchors (the Soul flask): to the right.
			p = Vector2(a.end.x + gap, c.y - sz.y * 0.5)
		else:
			p.x = c.x - sz.x * 0.5
			p.y = a.position.y - sz.y - gap if c.y > view.y * 0.5 else a.end.y + gap
	p.x = clampf(p.x, gap, maxf(gap, view.x - sz.x - gap))
	p.y = clampf(p.y, gap, maxf(gap, view.y - sz.y - gap))
	position = p


## Esc closes a hint (PC); a tap outside the bubble does (mobile).
func _input(event: InputEvent) -> void:
	if current == &"" or not visible:
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
		dismiss()
		get_viewport().set_input_as_handled()
		return
	var t := event as InputEventScreenTouch
	if t != null and t.pressed and not get_global_rect().has_point(t.position):
		dismiss()
