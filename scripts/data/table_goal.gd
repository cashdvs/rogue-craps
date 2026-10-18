## A table's goal: land every required bounty within `hands` hands.
class_name TableGoal
extends Resource

@export var display_name: String = "Table 1"
@export var hands: int = 5
@export var required: Array[BountyData] = []
@export var bonus: Array[BountyData] = []
## Embers for clearing the table.
@export var clear_embers: int = 10
## Out of hands: Soul lost per required bounty still unticked.
@export var timeout_soul_per_bounty: int = 3
