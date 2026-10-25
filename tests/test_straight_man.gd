## Headless test: Straight Man (art/models/characters/bosses/straight_man), templated on tests/test_pit_boss.gd via
## tests/support/boss_dealer_test.gd: Smiles rig + clips, tri budgets, toon-noir + ink in the AD dealer palette
## (+ the two ambient conditions), HeadTrack + HeadAnchor, brazier gap + felt in both game cams, plus
## the croupier rod on the chip bone.
##
## Run:
##   godot --headless --path . --script res://tests/test_straight_man.gd
extends "res://tests/support/boss_dealer_test.gd"


func _setup() -> void:
	title = "Straight Man"
	boss = "straight_man"
	parts = ["StraightMan_Body", "StraightMan_Head", "StraightMan_Hair", "StraightMan_Rod"]
	slots = ["sm_skin", "sm_suit", "sm_chalk", "sm_shirt", "sm_brass", "sm_bone", "sm_black", "sm_hair", "sm_eye", "sm_rod"]
	no_ink = ["sm_eye"]
	accents = ["sm_brass", "sm_bone"]
	prop = "StraightMan_Rod"
	prop_slots = ["sm_brass", "sm_rod"]
	swap_bone = {"StraightMan_Rod": "chip", "StraightMan_Hair": "visor"}
	extra_bones = {}
	scripted_ok = []
