## Where the Target HUD v2.1 goal plate and its SEALS chip sit on each screen
## (HANDOFF_SPEC.md "Placement"; spec px are 1600x900 on PC and pt on phone):
##   PC 1600x900:     AD Oct 30: plate x1.4 (w756, text x1.4, pad 16, chips
##                    24), top-centre at y24; SEALS just under its left end.
##   Phone 844x390:   plate w388 (46%), right-aligned (16) at y40, clear of the dealer
##                    and the dice rest zone (y >= 138); SEALS in the bottom bar.
##   Portrait 390:    plate at (12, 36) pt, scale 0.8, SEALS under it (AD OK:
##                    left-aligned, stops short of the pot row on the right).
## The HUD's design canvas is 1920 wide, so on PC 1 spec px = 1.2 design px;
## on a phone 1 pt = ui_pt_px design px.
class_name TargetPlace
extends RefCounted

const PC_Y: float = 24.0
const PC_W: float = 756.0
const PC_TEXT_SCALE: float = 1.4
const PHONE_Y: float = 40.0
const PHONE_W: float = 388.0
## Right-aligned under Embers, so the dealer (top-left) stays clear.
const PHONE_RIGHT: float = 16.0
const PORTRAIT_Y: float = 36.0
const PORTRAIT_SCALE: float = 0.8
## Portrait plate width in pt: 12 pt margin, 80 pt clear of the pot row (x ~344).
const PORTRAIT_W: float = 250.0
## Space to keep around the plate (spec: >= 24 px to other HUD parts).
const CLEAR_GAP: float = 24.0


## Sizes and places hud.target_plate (and its SEALS chip) for the screen.
static func place(hud: BonfireHud) -> void:
	var p := hud.target_plate
	if p == null or not p.is_node_ready():
		return
	var pt := hud.ui_pt_px
	var u: float
	var pos: Vector2
	if hud.is_portrait:
		u = pt * PORTRAIT_SCALE
		_size(p, u, PORTRAIT_W / PORTRAIT_SCALE, 12.0, 1.0)
		pos = Vector2(12.0, PORTRAIT_Y) * pt
	elif hud.is_phone_land:
		u = pt
		_size(p, u, PHONE_W, 12.0, 1.0)
		pos = Vector2(hud.get_viewport_rect().size.x / u - PHONE_W - PHONE_RIGHT, PHONE_Y) * u
	else:
		u = hud.get_viewport_rect().size.x / 1600.0  # spec px -> design px
		_size(p, u, PC_W, 16.0, PC_TEXT_SCALE)
		pos = Vector2((1600.0 - PC_W) * 0.5, PC_Y) * u
	p.position = pos
	var chip := p.seals_chip
	chip.reset_size()
	if hud.is_portrait:  # top-left, just under the plate (the corner holds the help button)
		chip.position = Vector2(pos.x, pos.y + p.size.y + 4.0 * pt)
	elif hud.is_phone_land:
		pass  # PhoneBottomBar.place() puts it in the bottom bar (#204)
	else:
		chip.position = Vector2(pos.x, pos.y + p.size.y + 4.0 * u)


static func _size(p: TargetPlate, u: float, width_spec: float, pad_spec: float, k: float) -> void:
	if not is_equal_approx(p.unit, u) or p.width_spec != width_spec or p.text_scale != k:
		p.unit = u
		p.width_spec = width_spec
		p.pad_spec = pad_spec
		p.text_scale = k
		p.restyle()
	p.reset_size()


## The plate plus its SEALS chip when that sits right under it (PC, portrait).
static func goal_rect(hud: BonfireHud) -> Rect2:
	var p := hud.target_plate
	var r := Rect2(p.position, p.size)
	if p.seals_chip.visible and not hud.is_phone_land:
		r = r.merge(Rect2(p.seals_chip.position, p.seals_chip.size))
	return r
