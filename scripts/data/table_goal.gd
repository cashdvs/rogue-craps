## A table's goal (table_goals_v1 PR1): bank `target` points within `hands`
## hands. `required` / `bonus` bounties stay for old saves and tests; MapRun
## no longer rolls any.
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
## Points to bank to pass the table (0 = no target: BonfireRun._goal_met falls back to the
## bounty rule, all `required` ticked; the standalone bonfire_tuning goal).
@export var target: int = 0
## Out of hands short of the target: Soul lost (BonfireRun.soul_cost doubles
## it under Bloodletter).
@export var miss_soul: int = 5
## The run's boss table (constant per table; the HUD plate's boss label).
@export var is_boss: bool = false
