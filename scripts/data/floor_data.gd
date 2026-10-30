## One floor of a Bonfire run (map/events spec §1): its map rules, how its
## tables are built (bounty counts, hands, pools), Elite twists and the boss pool.
class_name FloorData
extends Resource

@export var display_name: String = "Floor 1"
@export var map: MapGenData

@export_group("Tables")
## Required bounties per table, rolled between these (spec: 3 / 3-4 / 4).
@export var min_bounties: int = 3
@export var max_bounties: int = 3
@export var hands: int = 5
## Drawn from first, at random, without repeats.
@export var common_bounties: Array[BountyData] = []
## At least one of these is in every table if not empty (floor 2 and
## floor 3: Run of 4).
@export var featured_bounties: Array[BountyData] = []
## One optional bonus bounty per table, drawn from here.
@export var bonus_bounties: Array[BountyData] = []
@export var clear_embers: int = 10
## Unused since table_goals_v1 PR1 (kept for save compatibility; PR3 cleanup).
@export var timeout_soul_per_bounty: int = 3
## table_goals_v1 PR1: a table is passed by banking its target score.
## One target per node type on the floor (no ramp); 0 = no target (the table falls back to the bounty rule: BonfireRun._goal_met).
@export var target_table: int = 0
@export var target_elite: int = 0
@export var target_boss: int = 0
## Soul lost when the hands run out short of the target (Bloodletter doubles it).
@export var miss_soul: int = 5

@export_group("Elite and Boss")
## Twist pool: each Elite picks one at random (Cold Sixes, First Throw,
## Greedy Pot, Cold Hands).
@export var elite_twists: Array[RunRuleData] = []
## Boss pool: one boss (its cheat) is drawn when you enter the floor.
@export var boss_cheats: Array[RunRuleData] = []
## When true, the boss also gets one random Elite twist.
@export var boss_adds_twist: bool = false
## Extra bounties only the boss draws from (so it can reach 4-5).
@export var boss_bounties: Array[BountyData] = []
@export var boss_min_bounties: int = 4
@export var boss_max_bounties: int = 5
@export var boss_hands: int = 6
