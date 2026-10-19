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
## Icon size: one flat 32 px at 720p for every tier, scaled with the
## viewport height (Art Director sign-off; tier shows by the art's rim studs).
const ICON_PX_720: float = 32.0
## Longest a row may run per tier, in 12 fps frames (spec 1.2: minor 0.42 s,
## major 0.50 s, signature 0.58 s).
const BUDGET_FRAMES: Array[int] = [5, 6, 7]
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
	# Coin: tossed up, ONE flip end over end while it spins, lands flat on the
	# hit (f4) a quarter-turn round; the settle frame (f5) snaps it back:
	# its face turns as the copy arrives. 6 f = 0.50 s (Art Director).
	&"spin_flip": [[0, 0, 0, 0.88, 1.06, 0], [0.6, 90, 30, 1.0, 1.0, 0], [0.85, 180, 60, 1.0, 1.0, 0], [0.45, 270, 90, 1.0, 1.0, 0],
			[0, 360, 90, 1.10, 0.97, 0]],
	# Coin alone: a shorter toss, one flip, lands on f3.
	&"spin_flip_short": [[0, 0, 0, 0.88, 1.06, 0], [0.45, 120, 30, 1.0, 1.0, 0], [0.3, 240, 60, 1.0, 1.0, 0], [0, 360, 90, 1.10, 0.97, 0]],
	# Wild (and Lantern 8): squash, then a snap quarter-turn over 2 f, hold.
	&"snap_spin": [[0, 0, 0, 0.88, 1.06, 0], [0, 0, 0, 0.88, 1.06, 0], [0, 0, 45, 1.10, 0.97, 0], [0, 0, 90, 1.0, 1.0, 0]],
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
			"spark": BRASS_HI, "icon": &"mirror_copy", "beat": &"hop_flip", "glint": [0, 3]},
	# A gold glow + shine bar on the pip tick, a gold pulse, then the brass
	# coin hops off the die to the Ember counter (its flip frames).
	&"gilded_payout": {"tier": MINOR, "frames": 5, "hit": 2, "anchor": &"PIP", "fx": &"gild", "ring": BRASS_HI,
			"spark": BRASS_HI, "icon": &"gilded_payout", "beat": &"bob", "coin_flight": 0.4},
	# The coin tosses, flips once and lands on the hit; then the glint from
	# the highest die arrives as its face turns (f5). 0.50 s.
	&"coin_heads_copy": {"tier": MAJOR, "frames": 6, "hit": 4, "anchor": &"LAND", "fx": &"coin", "ring": GLASS,
			"spark": BRASS, "icon": &"coin_heads_copy", "beat": &"spin_flip", "glint": [3, 5]},
	# Tails: the same, the glint from the LOWEST die (the game passes it as ctx.source).
	&"coin_tails_copy": {"tier": MAJOR, "frames": 6, "hit": 4, "anchor": &"LAND", "fx": &"coin", "ring": GLASS,
			"spark": BRASS, "icon": &"coin_tails_copy", "beat": &"spin_flip", "glint": [3, 5]},
	# Thrown alone, heads (= 5): no glint, a short flip, a glass pulse.
	&"coin_alone_heads": {"tier": MINOR, "frames": 5, "hit": 3, "anchor": &"LAND", "fx": &"coin", "ring": GLASS,
			"spark": BRASS, "icon": &"coin_alone_heads", "beat": &"spin_flip_short"},
	# Wild Face (and Lantern 8): a bone 4-point sparkle, the snap-spin.
	&"wild_face": {"tier": MINOR, "frames": 4, "hit": 2, "anchor": &"PIP", "fx": &"sparkle", "ring": BONE,
			"spark": EMBER_CORE, "icon": &"wild_face", "beat": &"snap_spin"},
	# Bone needles shoot out and retract, a Hellfire-red silhouette frame
	# (hex on Verdict / Midnight), an ember-core glow; a bone pulse with an
	# ember inner pulse; the x1.5 chip.
	&"hellfire_face": {"tier": MAJOR, "frames": 6, "hit": 3, "anchor": &"PIP", "fx": &"needles", "ring": BONE,
			"ring2": EMBER_MID, "spark": null, "icon": &"hellfire_face", "beat": &"jolt", "chip": "×1.5"},
}
## Table / die ids -> row ids. Built from DiceIds (#107) so die ids and face
## keys are never hand-typed. Face-mod short names (#91) and a few legacy cue
## ids (#98) that are not die aliases stay in _FACE_MOD_ALIASES / _CUE_ALIASES.
## Pre-carved faces reuse the face-mod row (spec v0.2) with a flavour (FLAVOR_OF).
static var ALIASES: Dictionary[StringName, StringName] = _build_aliases()
## Ids that imply a flavour (the frame shape, and #98's ModTriggerSynth.FLAVORS layer).
static var FLAVOR_OF: Dictionary[StringName, StringName] = _build_flavor_of()


## FaceModData.id short names -> row (what #91 sends). Not die ids.
const _FACE_MOD_ALIASES: Dictionary[StringName, StringName] = {
	&"hellfire": &"hellfire_face", &"gilded": &"gilded_payout", &"wild": &"wild_face", &"twin": &"twin_face",
	&"blood": &"blood_face", &"stair": &"stair_face", &"step": &"step_face", &"kindling": &"kindling_armed",
}
## Legacy cue / coin-face ids that are not in DiceIds.ALIASES.
const _CUE_ALIASES: Dictionary[StringName, StringName] = {
	&"coin": &"coin_heads_copy", &"coin_heads": &"coin_heads_copy", &"coin_tails": &"coin_tails_copy",
	&"coin_alone": &"coin_alone_heads", &"ferryman_heads": &"coin_heads_copy", &"ferryman_tails": &"coin_tails_copy",
	&"midnight_xii": &"hellfire_face", &"keg_3": &"twin_face",
}


static func _build_aliases() -> Dictionary[StringName, StringName]:
	var a: Dictionary[StringName, StringName] = {}
	for k: StringName in _FACE_MOD_ALIASES:
		a[k] = _FACE_MOD_ALIASES[k]
	# Die ids from DiceIds.DIE_* (no hand-typed die id strings).
	a[DiceIds.DIE_MIRROR] = &"mirror_copy"
	a[DiceIds.DIE_FERRYMAN] = &"coin_heads_copy"
	a[DiceIds.DIE_TITHE] = &"gilded_payout"
	a[DiceIds.DIE_MIDNIGHT] = &"hellfire_face"
	a[DiceIds.DIE_LANTERN] = &"wild_face"
	a[DiceIds.DIE_POWDER_KEG] = &"twin_face"
	a[DiceIds.DIE_CALTROP] = &"caltrop_run"
	a[DiceIds.DIE_KNUCKLEBONE] = &"knucklebone_level"
	# Face keys from DiceIds.face_key.
	a[DiceIds.face_key(DiceIds.DIE_VERDICT, 20)] = &"hellfire_face"
	a[DiceIds.face_key(DiceIds.DIE_VERDICT, 1)] = &"blood_face"
	a[DiceIds.face_key(DiceIds.DIE_MIDNIGHT, 12)] = &"hellfire_face"
	a[DiceIds.face_key(DiceIds.DIE_TITHE, 10)] = &"gilded_payout"
	a[DiceIds.face_key(DiceIds.DIE_LANTERN, 8)] = &"wild_face"
	a[DiceIds.face_key(DiceIds.DIE_POWDER_KEG, 3)] = &"twin_face"
	# Old spellings that DiceIds already maps to a canonical die.
	for old: Variant in DiceIds.ALIASES:
		var can: StringName = DiceIds.ALIASES[old]
		if a.has(can):
			a[old as StringName] = a[can]
	for k: StringName in _CUE_ALIASES:
		a[k] = _CUE_ALIASES[k]
	return a


static func _build_flavor_of() -> Dictionary[StringName, StringName]:
	# Keys match ModTriggerSynth.FLAVORS (&"powder_keg", not the short "keg").
	var f: Dictionary[StringName, StringName] = {}
	f[DiceIds.face_key(DiceIds.DIE_VERDICT, 20)] = &"verdict"
	f[DiceIds.DIE_MIDNIGHT] = &"midnight"
	f[DiceIds.face_key(DiceIds.DIE_MIDNIGHT, 12)] = &"midnight"
	f[&"midnight_xii"] = &"midnight"
	f[DiceIds.DIE_TITHE] = &"tithe"
	f[DiceIds.face_key(DiceIds.DIE_TITHE, 10)] = &"tithe"
	f[DiceIds.DIE_LANTERN] = &"lantern"
	f[DiceIds.face_key(DiceIds.DIE_LANTERN, 8)] = &"lantern"
	f[DiceIds.DIE_POWDER_KEG] = &"powder_keg"
	f[DiceIds.face_key(DiceIds.DIE_POWDER_KEG, 3)] = &"powder_keg"
	f[&"keg_3"] = &"powder_keg"
	return f

## Any other id until its row is built: a plain minor bone ring pop.
const GENERIC: Dictionary = {"tier": MINOR, "frames": 4, "hit": 2, "anchor": &"PIP", "fx": &"", "ring": BONE,
		"spark": EMBER_CORE, "icon": &"generic", "beat": &"pop"}


## The row for `id` (a row, face-mod, die or face id); GENERIC if not built.
static func row(id: StringName) -> Dictionary:
	return ROWS.get(hook(id), GENERIC)


## The spec hook id for a table id (unchanged if it already is one).
static func hook(id: StringName) -> StringName:
	return ALIASES.get(id, id)


## The flavour `id` implies (e.g. verdict_20 -> verdict), or &"".
static func flavor_of(id: StringName) -> StringName:
	return FLAVOR_OF.get(id, &"")


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
