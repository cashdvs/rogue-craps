## Headless test: Bloodletter (art/models/characters/bosses/bloodletter), templated on tests/test_pit_boss.gd via
## tests/support/boss_dealer_test.gd: Smiles rig + clips, tri budgets, toon-noir + ink in the AD dealer palette
## (+ the two ambient conditions), HeadTrack + HeadAnchor, brazier gap + felt in both game cams, plus
## the bowl + silver lancet on the chip bone, the spectacles swap slot.
##
## Run:
##   godot --headless --path . --script res://tests/test_bloodletter.gd
extends "res://tests/support/boss_dealer_test.gd"


func _setup() -> void:
	title = "Bloodletter"
	boss = "bloodletter"
	parts = ["Bloodletter_Body", "Bloodletter_Head", "Bloodletter_Specs", "Bloodletter_Lancet"]
	slots = ["bl_skin", "bl_coat", "bl_apron", "bl_collar", "bl_brass", "bl_bone", "bl_hair", "bl_eye", "bl_glass", "bl_silver", "bl_pewter"]
	no_ink = ["bl_eye"]
	accents = ["bl_brass", "bl_bone", "bl_glass", "bl_silver", "bl_pewter"]
	prop = "Bloodletter_Lancet"
	prop_slots = ["bl_brass", "bl_bone", "bl_silver", "bl_pewter"]
	swap_bone = {"Bloodletter_Lancet": "chip", "Bloodletter_Specs": "visor"}
	extra_bones = {}
	scripted_ok = []
