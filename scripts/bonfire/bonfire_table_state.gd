## Layer 1 of the Bonfire table (see bonfire_3d.gd for the whole picture).
## Holds every signal, constant and variable of the table plus small
## read-only questions (is it lit? how many dice left?). The table script is
## split into a chain of layers, each extending the one before:
##   BonfireTableState -> BonfireTableLook -> BonfireTableLayout
##   -> BonfireThrowFlow -> BonfirePotBank -> Bonfire3D (the real node).
## Only Bonfire3D is ever created; the layers just keep each file short.
@abstract
class_name BonfireTableState
extends Table3D


# Declared here, written in a later layer (the chain ends at Bonfire3D).
# "@abstract" only promises the function exists so this file can call it.
@abstract func forfeit() -> bool
@abstract func finish() -> TableOutcome
@abstract func _mod_ctx(fm: FaceModData, d: DieVisual) -> Dictionary
@abstract func rethrow_prompt() -> String


signal throw_resolved(faces: Array[int], lit: Array[int])
## After each launch (debug overlay / tools): the flick speed in game
## (canvas) px/s, the dice's launch speed in m/s and the curve fraction k
## (0..1 strength after the launch curve).
signal throw_measured(flick_px_s: float, launch_mps: float, curve_k: float)
signal hand_result(result: Dictionary)
## Run mode: the table is done (end panel CONTINUE, or finish()). Emitted once.
signal finished(outcome: TableOutcome)

## The pot: a row of set-aside dice on the felt just inside the far rail,
## clear of the backboard (inner face z = -0.49). On the rail top they sat
## at the screen edge at 720p and off-screen in phone portrait. Potted dice
## are solid for the throw physics, so thrown dice bounce off them instead
## of passing through.
const POT_ORIGIN := Vector3(-0.19, 0.0, -0.44)
const POT_GAP: float = 0.095
const PICK_RADIUS_PX: float = 60.0
## Most dice one handful can hold (Table3D.MAX_DICE is the craps-era cap).
const MAX_HANDFUL: int = 12
## Face-mod looks (cheap decals on the die faces).
const HELLFIRE_COLOR := Color("#E2380C")
const WILD_COLOR := Color("#C88A00")
const TWIN_COLOR := Color("#2A1A10")
## The Wild rim's 4 strips (top, right, bottom, left): brass and dark in
## turn, with small brass ticks over the 4 corners.
const WILD_FRAME: Array[Color] = [Color("#C9A24A"), Color("#1E1712"), Color("#C9A24A"), Color("#1E1712")]
const WILD_TICK := Color("#C9A24A")
## Tint of a die whose face a rule changed (by rule id; others use the default).
const CHANGE_TINT := {&"mirror": Color("#BFE3FF"), &"madame_shuffle": Color("#C060FF")}
const CHANGE_TINT_DEFAULT := Color("#FFFFFF")
const FLIP_TIME: float = 0.3

@export var bonfire_tuning: BonfireTuning
## Seed for the dice faces (-1 = random).
@export var bonfire_seed: int = -1

var run: BonfireRun
var bhud: BonfireHud
var all_dice: Array[DieVisual] = []
## Dice of the current throw; index = run.throw_faces index.
var throw_dice: Array[DieVisual] = []
## Dice set aside by earlier throws of this hand.
var pot_dice: Array[DieVisual] = []
var _felt_pos: Array[Vector3] = []
## True when the last throw's dice were nudged into the phone rest rows (#204).
var last_nudge := false
var _brng := RandomNumberGenerator.new()
## Dice showing the lit (scoring) look; keys only.
var _lights: Dictionary = {}
var _hand_tweens: Array[Tween] = []
## The last throw's launch (tests/tools): lin, spin, speed, k, flick.
var last_launch: Dictionary = {}
var _player_flick: bool = false
var pause_menu: PauseMenu
## How this table was opened (null before _ready = sandbox).
var setup: TableSetup
## all_dice[i] -> its TableDie.
var _die_of: Dictionary = {}
## The physical face slots of the current throw (index = throw_dice index).
var throw_slots: Array[int] = []
## Nerve (nerve_v1.md): the table side (NerveTable) and its HUD (NerveUi).
var nerve: NerveTable
var nerve_ui: NerveUi
var _soul_before: int = 0
var _finished_sent: bool = false
## events.table_cleared went out for this table (once per table).
var _cleared_emitted: bool = false
## Text on the felt from the rules (e.g. "LOCKED  4").
var felt_label: Label3D
## The combo table on the felt (FeltComboTable).
var felt_combos: FeltComboTable
## Scoring juice adapter (sounds / VFX; art + audio branches if present).
var juice: BonfireJuice
## Tutorial: -1 = GameSettings decides (Table 1, not seen), 0 = never,
## 1 = always (tests). Set before add_child.
var tutorial_override: int = -1
## Hints + tutorial seeds for this table (made in _ready).
var onboarding: BonfireOnboarding
## The dealer art at the far rail: Smiles, or the boss on a boss table.
var dealer_art: BonfireDealerArt
## Dice of the pot being counted up, pip -> die index, its tier.
var _juice_dice: Array[DieVisual] = []
var _pip_die: Array[int] = []
var _juice_tier: int = 0
## The pot's face mod ids, per die (&"" = none): mod_triggered.
var _pip_mods: Array[StringName] = []
## mod_triggered ctx per die of the pot being counted (see _mod_ctx).
var _pip_ctx: Array[Dictionary] = []
## What the lit dice of this throw could claim (no selection yet).
var _throw_claims: Array = []


var _rig_is_slots: bool = false


## Is this table opened by the run?
func is_run_mode() -> bool:
	return setup != null and setup.run_mode


## The table's result so far (final once run.is_over()).
func outcome() -> TableOutcome:
	return TableOutcome.from_run(run, _soul_before)


## Can the table be forfeited right now? Not while a throw is in flight
## (rolling, landed, resolving): its faces are already decided, so a forfeit
## then could dodge a bust you can see (QA #60 blocker). FORFEIT comes back
## once the throw has resolved (bust or score applied) and phase is BET.
func can_forfeit_now() -> bool:
	return run != null and not run.is_over() and (phase == Phase.BET or phase == Phase.HELD)


## Is the Leave table button live right now? A cleared table, between
## hands (no throw yet this hand), not during the count-up or a throw.
func can_leave_now() -> bool:
	return run != null and run.can_leave() and phase == Phase.BET and not bhud.countup.is_playing()


const _STAGE_ORDER: Array[StringName] = [&"land", &"copies", &"boss", &"lit", &"scoring"]


## The refusal callout over a die that can't join the combo.
const NO_SCORE_TEXT := "doesn't score"
## A pick was refused (die index): tests / juice.
signal refused(index: int)


## How many dice the next throw would use (0 = none / not a rethrow).
func next_throw_size() -> int:
	if run == null or run.is_over():
		return 0
	if run.state == BonfireRun.State.PICK:
		if not run.selection()["valid"]:
			return 0
		return run.dice_count if run.is_hot() else run.throw_faces.size() - run.potted.size()
	if run.state == BonfireRun.State.AIM and run.throws_this_hand > 0:
		return run.cold
	return 0


var _risk_key: String = ""
var _risk: Dictionary = {}


## The bust chance behind the last rethrow_prompt() (0-1).
func bust_chance() -> float:
	return float(_risk.get("burn", 0.0))


# --- Onboarding (BonfireOnboarding does the work) --------------------------------------

## The Table 1 tutorial (TH hints + seeded throws) runs on this table.
func tutorial_wanted() -> bool:
	return onboarding.tutorial_wanted()


## Any hints on this table (Settings: Tutorial hints On/Off).
func hints_wanted() -> bool:
	return onboarding.hints_wanted()


## Does the run hold a Seal for this combo? (BonfireOnboarding.is_sealed)
func is_sealed(combo_id: StringName) -> bool:
	return onboarding.is_sealed(combo_id)


## Per throw this table: true if it was seeded by the tutorial (tests).
var seeded_throws: Array[bool]:
	get:
		return onboarding.seeded_throws


## Bounty cards the current selection could claim (or, with nothing
## selected, what the lit dice could claim).
func claimable_bounties() -> Array:
	if run == null or run.state != BonfireRun.State.PICK or not run.bounties_count():
		return []
	if run.potted.is_empty():
		return _throw_claims
	var sel := run.selection()
	if not sel["valid"]:
		return []
	return _open_ticks(sel["bounty_values"])


func _open_ticks(values: Array) -> Array:
	var open: Array = []
	for b: BountyData in run.all_bounties():
		if not run.is_ticked(b):
			open.append(b)
	return BonfireScoring.bounty_ticks(open, values)


func _compute_throw_claims() -> void:
	_throw_claims = []
	if run.state != BonfireRun.State.PICK:
		return
	var dice_now := run.throw_dice()
	var ctx := run.rule_ctx()
	for sub: Array in BonfireScoring.matching_subsets(dice_now, bonfire_tuning, ctx):
		var pick: Array = []
		for i in sub:
			pick.append(dice_now[i])
		var sc := BonfireScoring.score_selection(pick, bonfire_tuning, 0, ctx)
		for id in _open_ticks(sc["bounty_values"]):
			if not _throw_claims.has(id):
				_throw_claims.append(id)


func can_throw() -> String:
	if run == null:
		return "..."
	if phase != Phase.BET and phase != Phase.HELD:
		return "The dice are still rolling."
	if run.is_over():
		return "The table is over. Continue." if is_run_mode() else "The table is over. Restart."
	if run.state != BonfireRun.State.AIM:
		return "Pot your lit dice, then Throw again or Bank."
	return ""


## Table3D throws by physical face SLOT, so this returns one slot (1..6)
## per active die: rigged, or rolled with the die's face weights.
func _pick_values() -> Array[int]:
	var v: Array[int] = []
	if _rig.size() >= dice.size():
		for i in dice.size():
			var td := _td(i)
			var slot := _rig[i] if _rig_is_slots else td.slot_for_value(_rig[i])
			v.append(clampi(slot if slot > 0 else _rig[i], 1, td.face_count()))
		_rig.clear()
		return v
	for i in dice.size():
		v.append(_td(i).roll_slot(_brng))
	return v


func _td(i: int) -> TableDie:
	var td: TableDie = _die_of.get(dice[i])
	return td if td != null else TableDie.new()


## Active dice i -> (value, mod) for the slots it landed on.
func _values_for(slots: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		out.append(_td(i).value_at(slots[i]))
	return out


func _mods_for(slots: Array[int]) -> Array:
	var out: Array = []
	for i in slots.size():
		out.append(_td(i).mod_at(slots[i]))
	return out


# --- Debug throw overlay (off by default) ------------------------------------------
## After each flick: the flick speed (game px/s), the dice's launch speed
## (m/s) and the curve fraction k; it stays until the next throw. Turn it
## on with F3 (debug builds only), GameSettings.throw_debug, or the command line user arg
## `-- --throw-debug`. Tools can also set `throw_debug = true` directly.
var throw_debug: bool = false:
	set(v):
		throw_debug = v
		if throw_debug_label != null:
			throw_debug_label.visible = v and throw_debug_label.text != ""
var throw_debug_label: Label


## 0..1 strength of a flick (after the curve).
func launch_k(flick_speed: float) -> float:
	var bt := bonfire_tuning
	var k := clampf((flick_speed - bt.flick_speed_min) / maxf(bt.flick_speed_max - bt.flick_speed_min, 1.0), 0.0, 1.0)
	return pow(k, maxf(bt.launch_exponent, 0.01))


func sensitivity() -> float:
	var gs := get_node_or_null("/root/GameSettings")
	return float(gs.get("throw_sensitivity")) if gs != null else 1.0


## The screen size in pt that fit_phone was last given (0 = PC / not a phone).
var phone_screen := Vector2.ZERO


## Dice still on this table (a shattered die is gone).
func dice_left() -> int:
	return all_dice.size()


## Bonfire handfuls aren't capped at Table3D.MAX_DICE (runs grow to 7+).
func dice_per_throw() -> int:
	return 2 if mode == Mode.CRAPS else clampi(total_dice_per_throw, 1, MAX_HANDFUL)


# --- Internals ----------------------------------------------------------------------

## True while any die is still flying back to the hand.
func hand_moving() -> bool:
	for tw in _hand_tweens:
		if tw != null and tw.is_valid() and tw.is_running():
			return true
	return false


## Board A's near-rail total dial (art kit anchor TotalPlate, top edge) and
## the top of a tier-4 pillar over the pot: both must be on screen.
const NEAR_DIAL_TOP := Vector3(0.0, 0.2, 0.68)
const PILLAR_HEIGHT: float = 0.3


## Phone framing: Table3D's fit (dice >= min_die_px, hand + landing zone in
## view), then the view slides across the table so the pot row (both ends,
## with its pillar) is in view. The near dial is kept in view too when both
## fit; at portrait phone sizes they don't, and the pot row wins.
## Returns the smallest die size (px) like Table3D.fit_phone.
var phone_dial_visible: bool = true


## How far (px) the pot row / hand points want to stay from the viewport
## edges on a phone (clear of the HUD bar).
const PHONE_EDGE_PX: float = 80.0


## Throw physics: one solid box per potted die (the dice on the pot row).
var _pot_bodies: Array[StaticBody3D] = []


func is_lit(d: DieVisual) -> bool:
	return _lights.has(d)


## True if this die is showing the cold (matte grey) look.
func is_cold(d: DieVisual) -> bool:
	return d.glow_cold > 0.0 and not _lights.has(d)
