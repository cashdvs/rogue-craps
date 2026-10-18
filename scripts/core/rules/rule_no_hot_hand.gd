## Cold Hands (Elite twist) / Ashmouth (boss): "No Hot Hand." Potting the
## last dice of a hand is still allowed, but you must Bank: no free rethrow.
class_name RuleNoHotHand
extends TableRule


func hot_hand_allowed(_run: BonfireRun) -> bool:
	return false
