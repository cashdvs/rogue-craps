## Headless test: Shuffle (art/models/characters/bosses/shuffle), templated on tests/test_pit_boss.gd via
## tests/support/boss_dealer_test.gd: Smiles rig + clips, tri budgets, toon-noir + ink in the AD dealer palette
## (+ the two ambient conditions), HeadTrack + HeadAnchor, brazier gap + felt in both game cams, plus
## the card fan on the chip bone, the hair-tower swap slot.
##
## Run:
##   godot --headless --path . --script res://tests/test_shuffle.gd
extends "res://tests/support/boss_dealer_test.gd"


func _setup() -> void:
	title = "Shuffle"
	boss = "shuffle"
	parts = ["Shuffle_Body", "Shuffle_Head", "Shuffle_Hair", "Shuffle_Cards"]
	slots = ["shuffle_skin", "shuffle_gown", "shuffle_glove", "shuffle_hair", "shuffle_trim", "shuffle_eye", "shuffle_lip", "shuffle_card", "shuffle_cardback"]
	no_ink = ["shuffle_eye", "shuffle_lip"]
	accents = ["shuffle_trim", "shuffle_card", "shuffle_cardback"]
	prop = "Shuffle_Cards"
	prop_slots = ["shuffle_card", "shuffle_cardback"]
	swap_bone = {"Shuffle_Cards": "chip", "Shuffle_Hair": "visor"}
	extra_bones = {}
	scripted_ok = []
