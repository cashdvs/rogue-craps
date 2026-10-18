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
