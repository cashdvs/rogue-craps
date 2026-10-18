## Every tunable number for the proof-of-concept table, in ONE resource.
##
## Values come from design doc v0.3 (/workspace/dice/design/gamblers-descent.md,
## sections 2, 3, 6 and 12). Edit resources/tuning/poc_tuning.tres in the
## inspector to tune without touching code. Bet payouts live in the bet
## .tres files (resources/bets/), and dice faces in resources/dice/.
class_name TuningData
extends Resource

@export_group("Table setup (doc 2, 12)")
## Coin moved from your purse into the table bankroll (Floor 1: 20).
@export var stake: int = 20
## The bankroll you must reach: stake + 20 = 40.
@export var target_bankroll: int = 40
## Rolls allowed at the table (Floor 1: 12).
@export var roll_limit: int = 12
## Smallest and largest single bet (5 / table cap 25).
@export var min_bet: int = 5
@export var max_bet: int = 25
## Chip sizes offered by the stake buttons.
@export var stake_chips: Array[int] = [5, 10, 25]

@export_group("Soul (doc 3)")
## Soul you start the table with (POC: 40).
@export var soul_max: int = 40
## Seven-out: base + 1 per soul_per_coin_lost Coin lost, rounded UP.
@export var seven_out_base: int = 2
## Craps on the come-out: base + 1 per soul_per_coin_lost Coin lost, rounded UP.
@export var craps_base: int = 1
## "1 Soul per 10 Coin lost". Any other losing roll uses FULL 10s (rounded down).
@export var soul_per_coin_lost: int = 10

@export_group("End of table (doc 2)")
## Miss the target: base + 1 per miss_step_percent % of the gap, capped at miss_max.
@export var miss_base: int = 3
@export var miss_step_percent: int = 25
@export var miss_max: int = 7
## Going bust ends the table with this penalty (the max).
@export var bust_penalty: int = 7
## Clear bonus and per-unused-roll Coin when you hit the target.
@export var clear_bonus: int = 5
@export var coin_per_unused_roll: int = 1

@export_group("Dealer taunts (POC feel; not in the doc)")
## A single bet stake at or above this makes the Dealer taunt "big_bet".
@export var dealer_big_bet_threshold: int = 20
## Soul at or below this makes the Dealer taunt "low_soul" (once per table).
@export var dealer_low_soul_threshold: int = 12

@export_group("Odds (doc 5)")
## Odds behind Pass may total at most this many times the Pass stake (doc: 2x).
@export var odds_max_multiple: int = 2

@export_group("Throw gesture (Cash: grab and flick the dice)")
## A release slower than this (px/s, 1920x1080 space) drops the dice back
## into the hand instead of throwing.
@export var min_throw_speed: float = 700.0
## ...and so does a release that moved less than this from the grab point.
@export var min_throw_drag: float = 40.0
## Release speeds are clamped to this before shaping the throw.
@export var max_throw_speed: float = 4200.0
## Travel distance per px/s of release speed (before walls/clamping).
@export var throw_distance_per_speed: float = 0.32
## Throw arc duration at min / max speed (spec: 0.5 s typical).
@export var throw_time_slow: float = 0.6
@export var throw_time_fast: float = 0.38
## Velocity kept after bouncing off the rim (0..1).
@export var rim_restitution: float = 0.45
## Window (seconds) of drag samples used to measure release velocity.
@export var throw_sample_window: float = 0.08

@export_group("Feel: roll timings (art spec poc_feel.md 2, 7)")
## Reduced motion: no shake / hit-stop / cracks, fewer particles, faster.
@export var reduced_motion: bool = false
## Timing multiplier used when reduced_motion is on (spec: ~30% shorter).
@export var reduced_motion_time_scale: float = 0.7
## Particle count multiplier when reduced_motion is on.
@export var reduced_motion_particles: float = 0.3
## Click during REVEAL/RESOLVE plays the rest at this speed.
@export var fast_roll_speed: float = 2.0
@export var windup_time: float = 0.12
@export var throw_time: float = 0.5
@export var bounce1_time: float = 0.18
@export var bounce2_time: float = 0.12
@export var settle_time: float = 0.18
## Die B starts this long after die A.
@export var die_b_delay: float = 0.06
## Face swap interval range while tumbling (seconds).
@export var flick_min: float = 0.045
@export var flick_max: float = 0.07

@export_group("Feel: reveal and resolve (poc_feel.md 2, 6, 7)")
@export var reveal_hold: float = 0.25
@export var reveal_punch_time: float = 0.15
@export var sum_pop_delay: float = 0.05
@export var resolve_natural: float = 1.0
@export var resolve_craps: float = 1.0
@export var resolve_point_set: float = 0.8
@export var resolve_point_hit: float = 1.3
@export var resolve_seven_out: float = 1.8
@export var resolve_no_decision: float = 0.35
@export var reset_time: float = 0.4
## Shake in pixels / hit-stop in ms per moment.
@export var shake_win_px: float = 4.0
@export var shake_natural_px: float = 5.0
@export var shake_craps_px: float = 6.0
@export var shake_point_set_px: float = 2.0
@export var shake_point_hit_px: float = 6.0
@export var shake_seven_out_px: float = 10.0
@export var hitstop_natural_ms: int = 50
@export var hitstop_craps_ms: int = 60
@export var hitstop_point_hit_ms: int = 70
@export var hitstop_seven_out_ms: int = 120
## Seven-out escalation per extra roll spent chasing the point (with caps).
@export var escalate_shake_px: float = 1.0
@export var escalate_shake_cap: float = 6.0
@export var escalate_hitstop_ms: int = 10
@export var escalate_hitstop_cap: int = 60
@export var escalate_embers: int = 4
@export var escalate_embers_cap: int = 24

@export_group("Feel: chips and puck (poc_feel.md 3, 4)")
## Each click on the bankroll stack / Pass Line adds one chip of this value.
@export var chip_value: int = 5
@export var chip_place_time: float = 0.22
@export var chip_stagger: float = 0.05
@export var payout_slide_time: float = 0.30
@export var payout_stagger: float = 0.04
@export var collect_slide_time: float = 0.35
@export var countup_time: float = 0.4
@export var rake_time: float = 0.35
@export var puck_move_time: float = 0.35
@export var puck_flip_time: float = 0.18
@export var puck_return_time: float = 0.3

@export_group("Loss rules (poc_feel.md Decisions)")
## Pass Line losses also burn Soul (doc 3/12 formulas). PM: true.
@export var soul_on_loss: bool = true

@export_group("Table rule (doc 6; OFF for the POC per doc v0.4 section 12)")
## The disruptive rule on this table (Hot Seven, kept for later).
@export var table_rule: TableRuleData
## Doc v0.4 puts table rules out of POC scope, so this ships OFF. Turn it on
## (or use the F1 debug panel) to try Hot Seven: plaque + doubled seven-outs.
@export var table_rule_enabled: bool = false

# ---------------------------------------------------------------------------------
# 3D table (art/concept/poc_3d.md). Units are meters; the felt is at y = 0,
# +Z points at the player, -Z at the dealer.
# ---------------------------------------------------------------------------------

@export_group("3D camera (poc_3d.md 1)")
## Camera pitch down from horizontal, degrees (spec: 55; Cash: 55-65 is fine).
@export_range(30.0, 80.0) var cam_pitch_deg: float = 55.0
## Vertical field of view (spec: a narrow 36 for the "diorama" read).
@export var cam_fov: float = 36.0
## Distance from the look-at pivot (spec: 2.5 m).
@export var cam_distance: float = 2.5
## Look-at pivot on the felt (spec: slightly toward the player).
@export var cam_pivot: Vector3 = Vector3(0.0, 0.0, 0.05)
## Reveal follow/zoom: distance and timings (spec: 2.5 -> 2.1 m in 0.30 s, back in 0.40 s).
@export var cam_reveal_distance: float = 2.1
@export var cam_reveal_time: float = 0.30
@export var cam_return_time: float = 0.40
## Max pivot offset from center while following the dice (spec: +-0.35 m).
@export var cam_follow_clamp: float = 0.35
## Seven-out roll tilt (degrees), recovers over cam_tilt_time.
@export var cam_seven_out_tilt_deg: float = 1.5
@export var cam_tilt_time: float = 0.6
## Shake mapping from the 2D pixel values: 1 px = this many meters + degrees.
@export var shake_m_per_px: float = 0.0015
@export var shake_deg_per_px: float = 0.03
@export var shake_cap_m: float = 0.03
## Phones: dice must render at least this many pixels wide (Cash: 48).
@export var min_die_px: float = 48.0

@export_group("3D dice and physics (poc_3d.md 3)")
## Die edge length (spec: 0.08 m, "raise to 0.09 if phones need it").
@export var die_size: float = 0.08
@export var die_mass: float = 0.02
@export var die_friction: float = 0.55
@export var die_bounce: float = 0.35
## Spec 0.1 / 0.6; raised (with die_gravity_scale) for the 0.9 s median settle.
@export var die_linear_damp: float = 0.8
@export var die_angular_damp: float = 2.0
@export var felt_friction: float = 0.7
@export var felt_bounce: float = 0.1
@export var rail_friction: float = 0.4
## Spec says 0.45; Jolt's real impacts at that value barely rebound, so the
## live dice died against the backboard. 0.9 gives craps-wall rebounds.
@export var rail_bounce: float = 0.9
## Physics ticks per second for the dice (higher = steadier small bodies).
@export var physics_hz: int = 120

@export_group("3D throw (flick -> real RigidBody3D throw)")
## The flick's screen speed (min_throw_speed..max_throw_speed px/s) maps to
## this world speed range in m/s (spec bake used 2.2-3.0).
@export var throw_speed_min_mps: float = 2.2
@export var throw_speed_max_mps: float = 3.2
## Upward launch speed (m/s) so the dice leave the hand in a small arc.
@export var throw_up_mps: float = 1.2
## Throw direction is kept within this many degrees of "straight at the
## dealer's backboard" so a sideways flick still reaches the far wall.
@export var throw_aim_cone_deg: float = 35.0
## Random-but-seeded spin (rad/s) given at release (spec: 15-35).
@export var throw_spin_min: float = 15.0
@export var throw_spin_max: float = 35.0
## The throw is simulated ahead at this speed-up while the 0.12 s wind-up
## plays, then the recorded motion plays back at normal speed.
@export var sim_warp: float = 16.0
## Give up waiting for rest after this much simulated time (s).
@export var sim_max_time: float = 2.0
## A die counts as at rest below these speeds for sim_rest_time seconds.
@export var sim_rest_linear: float = 0.03
@export var sim_rest_angular: float = 0.5
@export var sim_rest_time: float = 0.12
## Running-total mode (groundwork for Burn Line): the target-line marker.
## PLACEHOLDER until design/burn_line.md sets the real number and rules.
@export var total_target_line: int = 21

## Audio: at most one impact signal per die per this many seconds.
@export var impact_min_interval: float = 0.05
## Audio: contacts slower than this (relative m/s) are silent (no signal).
@export var impact_min_speed: float = 0.3
## Audio: tumble_ending fires once when a die's spin drops below this (rad/s).
@export var tumble_end_rad_s: float = 9.0
## A die resting with its top face tilted more than this (up-axis dot below
## it) is "cocked" against the rail and gets a small nudge.
@export var sim_cocked_dot: float = 0.97
## After this long (simulated s) the dice are damped harder so they stop.
@export var sim_damp_after: float = 0.7
## Settle wobble after the last recorded frame (spec: 0.12 s, +-2 degrees).
@export var settle_wobble_time: float = 0.12
@export var settle_wobble_deg: float = 2.0

@export_group("3D throw timing (design doc 5b: one throw every 2-3 s)")
## Pace target: MEDIAN time from release to the dice at rest (seconds).
@export var settle_target: float = 0.9
## Settle assist: a die still moving this long after release is eased
## (smoothly, no snap) flat onto its face; the face remap makes that the
## seeded face.
@export var assist_start: float = 1.2
## Hard cap: the standard pair's reveal (dice at rest + settle wobble) is
## done by this long after release. Exotic dice may later allow ~1.8 s.
@export var reveal_cap: float = 1.5
## Heavier-than-real gravity makes the dice land and settle fast while still
## bouncing off the rails (1 = 9.8 m/s^2).
@export var die_gravity_scale: float = 2.5
## Speed toggle (T key / debug panel): 0 = 1x, 1 = 2x, 2 = Instant (jumps
## straight to the result). Click during a roll still fast-forwards at 1x.
@export_enum("1x", "2x", "Instant") var roll_speed_mode: int = 0
