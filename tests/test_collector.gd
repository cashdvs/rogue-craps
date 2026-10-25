## Headless test: Collector (art/models/characters/bosses/collector), templated on tests/test_pit_boss.gd via
## tests/support/boss_dealer_test.gd: Smiles rig + clips, tri budgets, toon-noir + ink in the AD dealer palette
## (+ the two ambient conditions), HeadTrack + HeadAnchor, brazier gap + felt in both game cams, plus
## the glass cloche on the chip bone (it never covers a die: held in hand only).
##
## Run:
##   godot --headless --path . --script res://tests/test_collector.gd
extends "res://tests/support/boss_dealer_test.gd"


func _setup() -> void:
	title = "Collector"
	boss = "collector"
	parts = ["Collector_Body", "Collector_Head", "Collector_Ears", "Collector_Cloche"]
	slots = ["col_fur", "col_fur_dark", "col_coat", "col_scarf", "col_brass", "col_bone", "col_glass", "col_eye", "col_black"]
	no_ink = ["col_eye"]
	accents = ["col_brass", "col_bone", "col_glass"]
	prop = "Collector_Cloche"
	prop_slots = ["col_brass", "col_glass"]
	swap_bone = {"Collector_Cloche": "chip", "Collector_Ears": "visor"}
	extra_bones = {}
	scripted_ok = []
