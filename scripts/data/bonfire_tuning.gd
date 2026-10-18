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
@export var table_goal: TableGoal
