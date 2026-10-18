## Bellows Die: "While in your handful, each Hot Hand gives +2 mult instead
## of +1." (BonfireTuning.bellows_hot_hand_mult_bonus; several Bellows don't
## stack.)
class_name DieBellows
extends TableRule


func hot_hand_mult_bonus(run: BonfireRun, bonus: int) -> int:
	return maxi(bonus, int(param("bonus", run.tuning.bellows_hot_hand_mult_bonus)))
