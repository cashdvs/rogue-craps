## Every run-level Bonfire number outside the table itself (map/events spec
## §1-2, build content v0.3): Soul, handful size, Seal steps, and the id
## pools rewards draw from. Floors, events, rewards, Rest and Shop numbers
## join in the next PRs. Edit resources/map/bonfire_run.tres to tune.
class_name RunData
extends Resource

@export_group("Run")
@export var max_soul: int = 35
@export var starting_soul: int = 35
@export var starting_embers: int = 0
## Handful: 5 dice to start, max 7 (build content).
@export var starting_dice: int = 5
@export var max_dice: int = 7

@export_group("Pools (build content v0.3)")
## Special dice the Shop and Elite rewards offer (SpecialDieData resources).
@export var special_dice: Array[SpecialDieData] = []
## Face mods the Shop and Rest offer (FaceModData resources).
@export var face_mods: Array[FaceModData] = []
## Each face mod costs this % more per mod already on that die (GD: +50%).
@export var mod_price_step_percent: int = 50
## A special die sells for floor(price * this / 100) (GD: half).
@export var die_sell_percent: int = 50
## Combos a Seal can level, lowest first (ids from bonfire_tuning.tres).
@export var seal_combos: Array[StringName] = [&"pair", &"run3", &"two_pair", &"trips", &"run4",
	&"full_house", &"run5", &"quads", &"five_kind"]
## Rare Seals (build content): used on the spot when taken.
@export var rare_seals: Array[StringName] = [&"transference", &"black", &"ashen"]
## Transference moves at most this much mult (and the matching base).
@export var transference_max_mult: int = 2

@export_group("Contract (spec 1)")
## One piece per boss beaten; each adds max Soul and heals to full.
@export var contract_max_soul: int = 5
## Pieces needed for the win after the last boss.
@export var contract_pieces_to_win: int = 3
## Per Seal level: base and mult added to that combo.
@export var seal_base_step: Dictionary[StringName, int] = {&"pair": 5, &"run3": 10, &"two_pair": 10,
	&"trips": 15, &"run4": 15, &"full_house": 20, &"run5": 25, &"quads": 30, &"five_kind": 40}
@export var seal_mult_step: Dictionary[StringName, int] = {&"pair": 1, &"run3": 1, &"two_pair": 1,
	&"trips": 1, &"run4": 2, &"full_house": 2, &"run5": 2, &"quads": 3, &"five_kind": 4}
