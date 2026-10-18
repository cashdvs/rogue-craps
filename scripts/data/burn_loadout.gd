## A named set of dice to take into a Burn Line table (e.g. "Standard",
## the obvious, easiest playstyle). Loadouts are data: add or change them in
## resources/tuning/burn_line_tuning.tres, no code needed.
class_name BurnLoadout
extends Resource

@export var id: StringName = &"standard"
@export var display_name: String = "Standard"
@export_multiline var description: String = ""
## BurnDie ids (see BurnLineTuning.dice), in button order.
@export var dice: Array[StringName] = [&"bone", &"knucklebone"]
## Side bets this loadout offers (numbers in BurnLineTuning). "exact_hit" =
## the optional Exact Hit side bet.
@export var side_bets: Array[StringName] = [&"exact_hit"]
