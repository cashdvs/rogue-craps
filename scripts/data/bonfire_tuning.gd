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
## Caltrop d4 (nonstandard_dice.md §10): a Run containing it gets + this mult.
@export var caltrop_run_mult: int = 2
## Knucklebone (§10): its "one Seal level" comes from the run's RunData
## seal_base_step / seal_mult_step (NonStdDice.seal_steps), not from here.

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
## Table 1 tutorial seeds (design/onboarding_hints_v1.md). Hand 1, throw
## 1: 2-3-4 and 4-4 glow, the 6 is cold, the Run of 3 card pulses.
@export var tutorial_first_throw: Array[int] = [2, 3, 4, 4, 6]
## The seeded throws after it, matched in order by hand, throw (1 = the
## hand's first) and dice thrown. "bounty": only while that required bounty
## is unclaimed and not pending (the first match wins). "no_hot_hand": only
## if hand 1 never reached a Hot Hand (hand 2 is seeded only then). Seeding
## stops at the first throw with no entry, after hand 2, on Skip, and on any
## table but the run's first. No entry may bust (tests check).
@export var tutorial_seeds: Array[Dictionary] = [
	{"hand": 1, "throw": 2, "dice": 2, "faces": [1, 1]},  # after potting the run: Pair -> Hot Hand
	{"hand": 1, "throw": 2, "dice": 3, "faces": [1, 1, 1]},  # after potting 4-4: Trips -> Hot Hand
	{"hand": 1, "throw": 3, "dice": 5, "bounty": &"triple", "faces": [3, 3, 3, 2, 6]},
	{"hand": 1, "throw": 3, "dice": 5, "bounty": &"two_pairs", "faces": [2, 2, 5, 5, 6]},
	{"hand": 1, "throw": 3, "dice": 5, "bounty": &"run3", "faces": [4, 5, 6, 2, 2]},
	{"hand": 2, "throw": 1, "dice": 5, "no_hot_hand": true, "faces": [1, 1, 3, 3, 5]},
	{"hand": 2, "throw": 2, "dice": 1, "no_hot_hand": true, "faces": [5]},
]

@export_group("Game camera (home framing, applied over TuningData)")
## Bonfire's home framing (PM / Art Director, Oct 19): the spec pitch, a bit
## closer and pivoted toward the player, the lens tilted up 7.5 degrees, so
## ~0.44 m shows above the far rail where Smiles stands
## (art/dealer-smiles, x -0.42, z -0.86), while the whole felt, the near rail
## and the TotalPlate stay in frame on 16:9 and resting dice shrink <= 5%
## and every die stays >= min_die_px and the goal plaque >= 96% of its old
## size (tools/measure_camera_framing.gd; tests/test_bonfire_camera.gd).
## The asked-for 0.5-0.6 m would push the far-corner die under min_die_px
## and shrink the plaque > 5%. Was the spec camera: pitch 55, 2.5 m, pivot
## z 0.05, no tilt.
@export_range(30.0, 80.0) var cam_pitch_deg: float = 55.0
@export var cam_distance: float = 2.40
@export var cam_pivot: Vector3 = Vector3(0.0, 0.0, 0.26)
@export var cam_look_up_deg: float = 7.5
## Phone landscape (short side <= 500 px): same pitch and tilt, closer and
## centred, so the whole felt / near rail / TotalPlate fit and dice stay as
## big as the old hand-centred phone framing (which cropped the left third
## of the felt).
@export var cam_phone_landscape_distance: float = 2.04
@export var cam_phone_landscape_pivot: Vector3 = Vector3(0.0, 0.0, 0.34)
## Framing targets the camera test holds the numbers above to (16:9):
## headroom above the far rail top at the dealer's depth (m), the largest
## allowed shrink of a resting die vs the spec camera (fraction), and the
## must-see points' margin inside the frame (px).
@export var cam_headroom_min_m: float = 0.42
@export var cam_die_shrink_max: float = 0.05
@export var cam_edge_margin_px: float = 15.0

@export_group("Throw momentum (flick speed -> launch)")
## Flick speeds (screen px/s, after the Options "Throw sensitivity"
## multiplier) mapped onto the launch range below. Under flick_speed_min it's
## still a throw if it passes TuningData.min_throw_speed (it launches as the
## gentlest lob); above flick_speed_max it's the hardest throw.
@export var flick_speed_min: float = 700.0
@export var flick_speed_max: float = 6000.0
## k = ((flick - min) / (max - min)) ^ launch_exponent, then every launch
## value below lerps from its _min (gentle lob) to its _max (hard throw).
## Exponent < 1 (0.9) lifts soft flicks a little; > 1 would give finer
## control over soft throws.
@export var launch_exponent: float = 0.9
## Horizontal launch speed (m/s): from the gentlest lob (min) to the
## hardest throw, which slams the backboard and comes back (max).
@export var launch_speed_min_mps: float = 1.8
@export var launch_speed_max_mps: float = 9.0
## Upward launch speed (m/s): a low lob vs a high, hard throw.
@export var launch_up_min_mps: float = 0.45
@export var launch_up_max_mps: float = 1.5
## Spin at release (rad/s): a lob barely tumbles, a hard throw spins hard.
@export var spin_min_rad_s: float = 4.0
@export var spin_max_rad_s: float = 42.0
## +- random spread on each die's spin (fraction) and its fan angle (deg).
@export var spin_jitter: float = 0.18
@export var fan_deg: float = 5.0

@export_group("Coin flip (Ferryman's Coin)")
## End-over-end spin (rad/s) about the coin's diameter: gentle lob .. hard throw.
@export var coin_flip_min_rad_s: float = 45.0
@export var coin_flip_max_rad_s: float = 60.0
## Extra upward launch (m/s) on top of launch_up_*, so it tumbles in the air.
@export var coin_lift_min_mps: float = 1.8
@export var coin_lift_max_mps: float = 2.0
## Random tilt (deg) of the flip axis around vertical.
@export var coin_axis_jitter_deg: float = 20.0
@export var table_goal: TableGoal
