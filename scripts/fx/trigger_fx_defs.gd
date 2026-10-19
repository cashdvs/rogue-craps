## Data for the special-die / face-mod trigger FX (Art Director's
## art/concept/special_dice/trigger_fx_spec.md v0.2): one entry per hook id.
## TriggerFx plays every row with the same grammar (spec 1.1, at 12 fps on
## twos): anticipation squash -> KEY HIT (the sound sync frame: the ring
## pulse, the row's glow and sparks, the icon pop) -> the row's motion beat
## -> settle. What makes rows read apart (Art Director, v1 review) is the
## row's own `fx` piece and beat, not the shared pieces.
##
## A row: tier (MINOR / MAJOR / SIGNATURE), frames (total length), hit (the
## key-hit frame), anchor (LAND / PIP / HOT / END / THROW), fx (the row's
## signature piece, see TriggerFx._row_fx), ring (pulse tint) and ring2 (an
## optional inner pulse one frame later), spark (tint, "" = none), icon
## (TriggerIcon pictogram), beat (per-frame motion, see BEATS), glint
## [from_f, to_f] (a glass glint travelling from ctx.source), chip (a factor
## label popped beside the icon). Glow only, never on the die body: every
## glow card is depth-tested at the die centre (the die covers its middle:
## a halo / rim), and no die material is touched, so the die's albedo is
## never tinted. No fire shapes anywhere (spec 0).
class_name TriggerFxDefs
extends RefCounted

enum { MINOR, MAJOR, SIGNATURE }

const FPS: float = 12.0
## Spec 1.2 per tier: glow size (x die), spark count, rim studs.
const SHAPE_SCALE: Array[float] = [1.4, 1.6, 1.8]
const SPARKS: Array[int] = [4, 6, 8]
const STUDS: Array[int] = [0, 4, 8]
## Icon disc diameter per tier in px at 720p (Art Director, v1 review:
## 28-32 px), scaled with the viewport height.
const ICON_PX_720: Array[float] = [28.0, 30.0, 32.0]
## The icon pops on the hit frame, holds this long, then fades.
const ICON_HOLD: float = 0.5
## Ring pulse: grows and fades over these frames from the hit (0.25 s).
const RING_FRAMES: int = 3
## The Art Director's sheet (art/vfx/trigger_fx/ README; the files used
## are copied here): icons/icon_<row>.png and shapes/<shape>[_fill|_outline].png.
## A missing file falls back to the code-drawn stand-in.
const ART_DIR := "res://assets/vfx/trigger_fx/"
const MAX_LIVE: int = 4
const STAGGER: float = 0.08
const POOL_PC: int = 8
const POOL_MOBILE: int = 6
## Icon fade at the end of its hold (spec 1.1 settle).
const ICON_FADE: float = 0.15
## Instant speed: icons only, static, for this long (spec 1.3).
const INSTANT_ICON: float = 0.25

## Palette (spec 0), one job per colour.
const EMBER_CORE := Color("#FFE6A8")
const EMBER_MID := Color("#E8622A")
const HELLFIRE := Color("#C8281E")
const OXBLOOD := Color("#3B0D14")
const BONE := Color("#E8DCC0")
const BRASS := Color("#B08D3C")
const BRASS_HI := Color("#E2C06A")
const LEATHER := Color("#5A1620")
const PIT_BLACK := Color("#0E1414")
## Pale glass for the copy rows (Mirror, Coin): the art README's warm
## near-white, deliberately not bluish so it never reads as Soul cyan.
const GLASS := Color("#F2EEE2")

## Motion beats: one key per frame from f0, [lift (x die edge), roll (deg,
## around the die's x), yaw (deg), scale_y, scale_xz, jitter (x die edge)].
## Frames past the end of a list hold the last key; the settle frame always
## returns to rest. Squash = f0-f1, stretch on the hit (spec 1.1).
const BEATS: Dictionary[StringName, Array] = {
	# Mirror: hop 0.2 and flip, landing ON the hit (f3) as the glint arrives:
	# the face turn (TODO(tween_to_face): Godot Dev's real turn to the copy).
	&"hop_flip": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0.2, 180, 0, 1.0, 1.0, 0], [0, 360, 0, 1.10, 0.97, 0], [0, 360, 0, 1.0, 1.0, 0]],
	# Gilded: hit f2, then dip 0.08 and rise (a coin dropping in).
	&"bob": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 1.10, 0.97, 0], [-0.08, 0, 0, 1.0, 1.0, 0], [0, 0, 0, 1.0, 1.0, 0]],
	# Coin: tossed up, flips end over end twice while spinning, lands flat on
	# the hit (f4); f5 its face turns (a quarter twist) as the copy arrives.
	&"spin_flip": [[0, 0, 0, 0.88, 1.06, 0], [0.7, 180, 60, 1.0, 1.0, 0], [1.0, 360, 120, 1.0, 1.0, 0], [0.5, 540, 180, 1.0, 1.0, 0],
			[0, 720, 180, 1.10, 0.97, 0], [0, 720, 225, 1.0, 1.0, 0], [0, 720, 270, 1.0, 1.0, 0]],
	# Hellfire: hit f3 with a 1 f up-kick (the gavel tap on Verdict), then
	# still: no rattle (the v1 rattle read as Cracked breaking).
	&"jolt": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 1.0, 1.0, 0], [0.08, 0, 0, 1.10, 0.97, 0], [0, 0, 0, 1.0, 1.0, 0]],
	# Generic minor: squash, stretch on f2, settle.
	&"pop": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 1.10, 0.97, 0], [0, 0, 0, 1.0, 1.0, 0]],
}

const ROWS: Dictionary[StringName, Dictionary] = {
	# A glass glint streak arcs from the source die (f0-f2) and lands on the
	# hit with the hop-flip and a pale glass frame flash; a glass pulse.
	&"mirror_copy": {"tier": MAJOR, "frames": 6, "hit": 3, "anchor": &"LAND", "fx": &"glint", "ring": GLASS,
			"spark": GLASS, "icon": &"mirror_copy", "beat": &"hop_flip", "glint": [0, 3]},
	# A gold glow + shine bar on the pip tick, a gold pulse, then the brass
	# coin hops off the die to the Ember counter (its flip frames).
	&"gilded_payout": {"tier": MINOR, "frames": 5, "hit": 2, "anchor": &"PIP", "fx": &"gild", "ring": BRASS_HI,
			"spark": BRASS_HI, "icon": &"gilded_payout", "beat": &"bob", "coin_flight": 0.4},
	# The coin spin-flips and lands on the hit; then the glint from the
	# highest die arrives as its face turns (f5).
	&"coin_heads_copy": {"tier": MAJOR, "frames": 7, "hit": 4, "anchor": &"LAND", "fx": &"coin", "ring": GLASS,
			"spark": GLASS, "icon": &"coin_heads_copy", "beat": &"spin_flip", "glint": [3, 5]},
	# Bone needles shoot out and retract, a Hellfire-red silhouette frame
	# (hex on Verdict / Midnight), an ember-core glow; a bone pulse with an
	# ember inner pulse; the x1.5 chip.
	&"hellfire_face": {"tier": MAJOR, "frames": 6, "hit": 3, "anchor": &"PIP", "fx": &"needles", "ring": BONE,
			"ring2": EMBER_MID, "spark": null, "icon": &"hellfire_face", "beat": &"jolt", "chip": "×1.5"},
}
## Table ids -> spec hook ids. TableEvents (#91) sends face-mod ids
## (FaceModData.id) and special-die / rule ids; the spec names rows by hook.
const ALIASES: Dictionary[StringName, StringName] = {
	&"hellfire": &"hellfire_face", &"gilded": &"gilded_payout", &"mirror": &"mirror_copy",
	&"coin_heads": &"coin_heads_copy", &"wild": &"wild_face", &"twin": &"twin_face", &"blood": &"blood_face",
	&"stair": &"stair_face", &"step": &"step_face", &"kindling": &"kindling_armed",
}
## Any other id until its row is built: a plain minor bone ring pop.
const GENERIC: Dictionary = {"tier": MINOR, "frames": 4, "hit": 2, "anchor": &"PIP", "fx": &"", "ring": BONE,
		"spark": EMBER_CORE, "icon": &"generic", "beat": &"pop"}


static func row(id: StringName) -> Dictionary:
	return ROWS.get(hook(id), GENERIC)


## The spec hook id for a table id (unchanged if it already is one).
static func hook(id: StringName) -> StringName:
	return ALIASES.get(id, id)


## Seconds from trigger start to the key hit at 1x (f2 167 / f3 250 / f4 333 ms).
static func hit_time(id: StringName) -> float:
	return int(row(id)["hit"]) / FPS


## Total length in seconds at 1x.
static func length(id: StringName) -> float:
	return int(row(id)["frames"]) / FPS


## Motion key for frame f of a beat (the last key holds).
static func beat_key(beat: StringName, f: int) -> Array:
	var keys: Array = BEATS.get(beat, BEATS[&"pop"])
	return keys[clampi(f, 0, keys.size() - 1)]
