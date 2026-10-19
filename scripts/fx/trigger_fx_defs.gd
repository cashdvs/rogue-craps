## Data for the special-die / face-mod trigger FX (Art Director's
## art/concept/special_dice/trigger_fx_spec.md v0.2): one entry per hook id.
## TriggerFx plays every row with the same grammar (spec 1.1, at 12 fps on
## twos): anticipation squash -> KEY HIT (glow shape + sparks, the sound
## sync frame) -> icon pop -> the row's motion beat -> settle.
##
## A row: tier (MINOR / MAJOR / SIGNATURE), frames (total length), hit (the
## key-hit frame), anchor (LAND / PIP / HOT / END / THROW), tint / tint2
## (glow colours, one job each), shape (TriggerShapes cell), icon
## (TriggerIcon pictogram), beat (per-frame motion, see BEATS), link (an
## optional beam / arc from ctx.source). No fire shapes anywhere (spec 0).
class_name TriggerFxDefs
extends RefCounted

enum { MINOR, MAJOR, SIGNATURE }

const FPS: float = 12.0
## Spec 1.2 per tier: glow size (x die), spark count, icon disc pt, rim studs.
const SHAPE_SCALE: Array[float] = [1.4, 1.6, 1.8]
const SPARKS: Array[int] = [4, 6, 8]
const ICON_PT: Array[float] = [24.0, 28.0, 34.0]
const STUDS: Array[int] = [0, 4, 8]
## Spec 1.4 (Art Director, Oct 19): at most 4 visible bursts; the rest wait,
## and starts are 0.08 s apart in resolve order (biggest first).
const MAX_LIVE: int = 4
const STAGGER: float = 0.08
const POOL_PC: int = 8
const POOL_MOBILE: int = 6
## Icon fade after the burst (spec 1.1 settle).
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

## Motion beats: one key per frame from f0, [lift (x die edge), roll (deg,
## around the die's x), yaw (deg), scale_y, scale_xz, jitter (x die edge)].
## Frames past the end of a list hold the last key; the settle frame always
## returns to rest. Squash = f0-f1, stretch on the hit (spec 1.1).
const BEATS: Dictionary[StringName, Array] = {
	# Mirror: hop 0.2 and flip, landing ON the hit (f3).
	&"hop_flip": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0.2, 180, 0, 1.0, 1.0, 0], [0, 360, 0, 1.10, 0.97, 0], [0, 360, 0, 1.0, 1.0, 0]],
	# Gilded: hit f2, then dip 0.08 and rise (a coin dropping in).
	&"bob": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 1.10, 0.97, 0], [-0.08, 0, 0, 1.0, 1.0, 0], [0, 0, 0, 1.0, 1.0, 0]],
	# Coin: pops up, spins on its edge 2 turns, lands flat on the hit (f4).
	&"edge_spin": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0.3, 360, 0, 1.0, 1.0, 0], [0.18, 720, 0, 1.0, 1.0, 0], [0, 720, 0, 1.10, 0.97, 0], [0, 720, 0, 1.0, 1.0, 0]],
	# Hellfire: hit f3, then a 1 f up-kick and a 2 f rattle (+-1 px).
	&"jolt": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 1.0, 1.0, 0], [0, 0, 0, 1.10, 0.97, 0], [0.06, 0, 0, 1.0, 1.0, 0], [0, 0, 0, 1.0, 1.0, 0.04]],
	# Generic minor: squash, stretch on f2, settle.
	&"pop": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 1.10, 0.97, 0], [0, 0, 0, 1.0, 1.0, 0]],
}

const ROWS: Dictionary[StringName, Dictionary] = {
	&"mirror_copy": {"tier": MAJOR, "frames": 6, "hit": 3, "anchor": &"LAND", "tint": BONE, "tint2": BRASS_HI,
			"shape": &"frame", "icon": &"mirror", "beat": &"hop_flip", "link": &"beam"},
	&"gilded_payout": {"tier": MINOR, "frames": 5, "hit": 2, "anchor": &"PIP", "tint": BRASS, "tint2": BRASS_HI,
			"shape": &"shine", "icon": &"coin", "beat": &"bob", "link": &"", "coin_flight": 0.35},
	&"coin_heads_copy": {"tier": MAJOR, "frames": 6, "hit": 4, "anchor": &"LAND", "tint": BRASS, "tint2": BRASS_HI,
			"shape": &"ring", "icon": &"coin_skull", "beat": &"edge_spin", "link": &"arc"},
	&"hellfire_face": {"tier": MAJOR, "frames": 6, "hit": 3, "anchor": &"PIP", "tint": HELLFIRE, "tint2": EMBER_CORE,
			"shape": &"needles", "icon": &"needles", "beat": &"jolt", "link": &""},
}
## Table ids -> spec hook ids. TableEvents (#91) sends face-mod ids
## (FaceModData.id) and special-die / rule ids; the spec names rows by hook.
const ALIASES: Dictionary[StringName, StringName] = {
	&"hellfire": &"hellfire_face", &"gilded": &"gilded_payout", &"mirror": &"mirror_copy",
	&"coin_heads": &"coin_heads_copy", &"wild": &"wild_face", &"twin": &"twin_face", &"blood": &"blood_face",
	&"stair": &"stair_face", &"step": &"step_face", &"kindling": &"kindling_armed",
}
## Any other id until its row is built: a plain minor bone ring pop.
const GENERIC: Dictionary = {"tier": MINOR, "frames": 4, "hit": 2, "anchor": &"PIP", "tint": BONE, "tint2": EMBER_CORE,
		"shape": &"ring", "icon": &"generic", "beat": &"pop", "link": &""}


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
