## Where the Target HUD v2.1 goal plate and its SEALS chip sit on each screen
## (HANDOFF_SPEC.md "Placement"; spec px are 1600x900 on PC and pt on phone):
##   PC 1600x900:     plate x740 y100 w540, SEALS under it at y228.
##   Phone 844x390:   plate x190 y40 w510, SEALS bottom-right (no bottom bar yet).
##   Portrait 390:    plate at y36, scale 0.8, SEALS under it. Not centred:
##                    it stops 80 pt short of the pot row down the right edge.
## The HUD's design canvas is 1920 wide, so on PC 1 spec px = 1.2 design px;
## on a phone 1 pt = ui_pt_px design px.
class_name TargetPlace
extends RefCounted

const PC_POS := Vector2(740, 100)
const PC_SEALS_Y: float = 228.0
const PHONE_POS := Vector2(190, 40)
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
		_size(p, u, PORTRAIT_W / PORTRAIT_SCALE, 12.0)
		pos = Vector2(12.0, PORTRAIT_Y) * pt
	elif hud.is_phone_land:
		u = pt
		_size(p, u, 510.0, 12.0)
		pos = PHONE_POS * u
	else:
		u = hud.get_viewport_rect().size.x / 1600.0  # spec px -> design px
		_size(p, u, 540.0, 16.0)
		pos = PC_POS * u
	p.position = pos
	var chip := p.seals_chip
	chip.reset_size()
	if hud.is_portrait:  # top-left, just under the plate (the corner holds the help button)
		chip.position = Vector2(pos.x, pos.y + p.size.y + 4.0 * pt)
	elif hud.is_phone_land:
		var vs := hud.get_viewport_rect().size
		chip.position = vs - chip.size - Vector2(12.0, 12.0) * pt
	else:
		chip.position = Vector2(pos.x, PC_SEALS_Y * u)


static func _size(p: TargetPlate, u: float, width_spec: float, pad_spec: float) -> void:
	if not is_equal_approx(p.unit, u) or p.width_spec != width_spec:
		p.unit = u
		p.width_spec = width_spec
		p.pad_spec = pad_spec
		p.restyle()
	p.reset_size()


## The plate plus its SEALS chip when that sits right under it (PC, portrait).
static func goal_rect(hud: BonfireHud) -> Rect2:
	var p := hud.target_plate
	var r := Rect2(p.position, p.size)
	if p.seals_chip.visible and not hud.is_phone_land:
		r = r.merge(Rect2(p.seals_chip.position, p.seals_chip.size))
	return r
