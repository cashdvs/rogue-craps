## A table bounty: a pattern to land (in a potted, banked throw by default).
class_name BountyData
extends Resource

enum Kind { N_OF_A_KIND, RUN, TWO_PAIR, FULL_HOUSE, STRAIGHT_5 }

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var kind: Kind = Kind.N_OF_A_KIND
## N_OF_A_KIND: how many alike; RUN: minimum length.
@export var n: int = 3
## N_OF_A_KIND: a specific face (0 = any).
@export var face: int = 0
## How many separate pots must contain it.
@export var count_needed: int = 1
## Bonus bounties: Embers paid when banked.
@export var bonus_embers: int = 0
