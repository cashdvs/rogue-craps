## Every Bonfire number (Game Designer's table): combos, Soul, bust, Hot Hand,
## Ember conversion and the table goal. Data-only to change.
class_name BonfireTuning
extends Resource

@export var starting_soul: int = 35
@export var dice_count: int = 5
@export var bust_soul_loss: int = 1
## Each Hot Hand adds this to the mult of every later pot in that hand.
@export var hot_hand_mult_bonus: int = 1
## Points convert to Embers at table end: floor(points / points_per_ember).
@export var points_per_ember: int = 100
## true: bounties tick only from potted dice (pending until Bank, lost on a
## bust). false: any throw where the pattern lands ticks it (still pending).
@export var bounty_requires_pot: bool = true
## Combos in rank order, lowest first; a pot scores as the highest-ranked
## combo that exactly matches it.
@export var combos: Array[BonfireCombo] = []

@export_group("Special dice (build content v0.3)")
## Twin Flame: a Pair or Two Pair containing it gets + this mult.
@export var twin_flame_mult: int = 4
## Coven: Trips or Full House containing it get x this.
@export var coven_factor: float = 2.0
## Cracked: x this on its pot, and this chance it shatters after scoring.
@export var cracked_factor: float = 2.0
## Cracked never shatters while the player owns this many dice or fewer.
@export var cracked_min_owned_dice: int = 5
@export var cracked_shatter_chance: float = 1.0 / 6.0
## Last Breath: potted from a rethrow of 1..last_breath_max_dice dice: x factor.
@export var last_breath_factor: float = 3.0
@export var last_breath_max_dice: int = 2
## Blood Pact: + 1 mult per this much missing Soul (max Soul - Soul).
@export var blood_pact_soul_step: int = 5
## Bellows: while in the handful, each Hot Hand adds this instead of hot_hand_mult_bonus.
@export var bellows_hot_hand_mult_bonus: int = 2

@export_group("Juice (scoring count-up, moments)")
## Score tiers (bonfire_map_events_juice.md section 3): points < [0] = 0
## sparks, < [1] = 1 flames, < [2] = 2 inferno, else 3 pillar (big).
@export var juice_tier_thresholds: Array[int] = [100, 300, 1000]
## Count-up beats (seconds at 1x): one pip tick per counted value, the Mult
## chip slam, each extra chip (Hot Hand, Hellfire factor), the "x" sweep, the
## total count-up and the banner hold. Big = the top tier.
@export var juice_pip_gap: float = 0.08
@export var juice_pip_gap_big: float = 0.14
@export var juice_slam_time: float = 0.14
@export var juice_chip_gap: float = 0.12
@export var juice_sweep_time: float = 0.1
@export var juice_count_time: float = 0.28
@export var juice_count_time_big: float = 0.5
@export var juice_banner_hold: float = 0.22
@export var juice_banner_hold_big: float = 0.45
## Hard caps on the whole sequence (everything is scaled down to fit).
@export var juice_cap: float = 1.2
@export var juice_cap_big: float = 2.0
## count_tick sounds at most this often (Sound Designer).
@export var juice_count_tick_min_gap: float = 0.03
## Shake per tier (px, seconds); the top tier also slows time.
@export var juice_shake_px: Array[float] = [0.0, 3.0, 7.0, 14.0]
@export var juice_shake_time: Array[float] = [0.0, 0.1, 0.2, 0.35]
@export var juice_slowmo_time: float = 0.25
@export var juice_slowmo_scale: float = 0.3
## Combo id -> banner tier (0 bone, 1 ember, 2 hellfire, 3 black-gold).
@export var juice_banner_tiers: Dictionary = {
	&"single": 0, &"pair": 0, &"run3": 0, &"two_pair": 1, &"trips": 1, &"run4": 1,
	&"full_house": 2, &"run5": 2, &"quads": 2, &"five_kind": 3,
}
## Moments.
@export var juice_hot_hand_fly_time: float = 0.5
@export var juice_bank_flow_time: float = 0.55
@export var juice_stamp_gap: float = 0.3
@export var juice_ash_time: float = 0.5
@export var juice_flask_crack_delay: float = 0.35
## Unbanked pot that makes the crowd roar (CrowdLayers pot fraction 1).
@export var juice_crowd_full_pot: int = 1500
## Table 1 tutorial: the first throw lands a pair + a run of 3.
@export var tutorial_first_throw: Array[int] = [2, 2, 4, 5, 6]

@export_group("Throw momentum (flick speed -> launch)")
## Flick speeds (screen px/s, after the Options "Throw sensitivity"
## multiplier) mapped onto the launch range below. Under flick_speed_min it's
## still a throw if it passes TuningData.min_throw_speed (it launches as the
## gentlest lob); above flick_speed_max it's the hardest throw.
@export var flick_speed_min: float = 700.0
@export var flick_speed_max: float = 4200.0
## k = ((flick - min) / (max - min)) ^ launch_exponent, then every launch
## value below lerps from its _min (gentle lob) to its _max (hard throw).
## Exponent > 1 gives finer control over soft throws.
@export var launch_exponent: float = 1.3
## Horizontal launch speed (m/s). ~0.8 lands a hand's width away; ~4.5
## slams the backboard and comes back.
@export var launch_speed_min_mps: float = 0.8
@export var launch_speed_max_mps: float = 4.6
## Upward launch speed (m/s): a low lob vs a high, hard throw.
@export var launch_up_min_mps: float = 0.45
@export var launch_up_max_mps: float = 1.5
## Spin at release (rad/s): a lob barely tumbles, a hard throw spins hard.
@export var spin_min_rad_s: float = 4.0
@export var spin_max_rad_s: float = 42.0
## +- random spread on each die's spin (fraction) and its fan angle (deg).
@export var spin_jitter: float = 0.18
@export var fan_deg: float = 5.0
@export var table_goal: TableGoal
