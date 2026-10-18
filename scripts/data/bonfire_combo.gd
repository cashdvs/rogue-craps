## One Bonfire combo: score = (base + sum of the potted faces) x mult.
## A pot matches a combo only EXACTLY (every potted die belongs to it).
class_name BonfireCombo
extends Resource

enum Kind { SINGLE, N_OF_A_KIND, RUN, TWO_PAIR, FULL_HOUSE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.SINGLE
## N_OF_A_KIND: how many alike; RUN: its length. Unused otherwise.
@export var n: int = 1
## SINGLE: which faces count on their own.
@export var single_faces: Array[int] = [1, 5]
@export var base: int = 0
@export var mult: int = 1
