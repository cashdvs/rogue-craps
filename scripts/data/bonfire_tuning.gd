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
