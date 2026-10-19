## Every run-level Bonfire number outside the table itself (map/events spec
## §1-2, build content v0.3, Game Designer prices): floors, Soul, handful
## size, Seal steps, reward picks, Rest, Shop, and the pools events and
## rewards draw from. Edit resources/map/bonfire_run.tres to tune.
class_name RunData
extends Resource

@export_group("Run")
@export var floors: Array[FloorData] = []
@export var max_soul: int = 35
@export var starting_soul: int = 35
@export var starting_embers: int = 0
## Handful: 5 dice to start, max 6 (economy_balance_v1 P2; was 7). Every bag-full
## check (shop, Elite reward, event give_die, "Your dice" panel) reads max_dice.
@export var starting_dice: int = 5
@export var max_dice: int = 7

@export_group("Pools (build content v0.3)")
## Events the map's Event nodes draw from (no repeats until all are seen).
@export var events: Array[EventData] = []
## Special dice the Shop and Elite rewards offer (SpecialDieData resources).
@export var special_dice: Array[SpecialDieData] = []
## Die shapes (design/nonstandard_dice.md §10): d6 (the default) plus the batch-3 dice,
## each with its price, pre-carved faces and an `enabled` flag.
@export var shapes: Array[DieShape] = []
## Chance a dice offer (shop slot or Elite reward) is a shaped die instead of
## a special die (Game Designer: about 1 in 4). Enabled shapes share it equally.
@export var shape_offer_chance: float = 0.25
## Face mods the Shop and Rest offer (FaceModData resources).
@export var face_mods: Array[FaceModData] = []
## Each face mod costs this % more per mod already on that die (GD: +50%).
@export var mod_price_step_percent: int = 50
## A special die sells for floor(price * this / 100) (GD: half).
@export var die_sell_percent: int = 50
## Heavy Face ("lands twice as often", build content): roll weight of a
## Heavy face vs 1.0 for every other face. The table ignores Heavy; the run
## puts it in TableDie.weights.
@export var heavy_weight: float = 2.0
## A Cracked die never shatters while you own this many dice or fewer (GD
## "Rules rulings"); RunProgress.remove_dice won't go below it either.
@export var cracked_min_dice: int = 5
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

@export_group("Rewards (spec 1)")
## Free Seal pick after every cleared Table/Elite/Boss: options, or skip for Embers.
@export var seal_pick_options: int = 3
@export var elite_seal_pick_options: int = 4
@export var seal_skip_embers: int = 3
## Elite: pick 1 of this many special dice.
@export var elite_dice_options: int = 2
@export var boss_embers: int = 25
## Boss misses allowed before the run ends (spec: one re-sit).
@export var boss_resits: int = 1

## Chance a Seal offer is a rare Seal (build content: about 1 in 10).
@export_range(0.0, 1.0) var rare_seal_chance: float = 0.1

@export_group("Rest (spec 1)")
@export var rest_heal: int = 12
@export var rest_seal_levels: int = 1

@export_group("Shop (spec 1)")
@export var shop_dice: int = 2
@export var shop_mods: int = 2
@export var shop_seals: int = 2
@export var shop_seal_price: int = 5
## Rare Seals in the shop (build content: about 10 Embers).
@export var shop_rare_seal_price: int = 10
## Each Seal bought this visit raises the Seal price by this.
@export var shop_seal_step: int = 1
@export var reroll_base: int = 3
@export var reroll_step: int = 1
## Soul Draught, in every shop (economy_balance_v1 P3): +shop_soul_amount max
## Soul (also heals that much) for shop_soul_price Embers, + shop_soul_step
## per Draught bought this run (12, 16, 20...). Same rate as the Toll Keeper.
@export var shop_soul_amount: int = 4
@export var shop_soul_price: int = 12
@export var shop_soul_step: int = 4
