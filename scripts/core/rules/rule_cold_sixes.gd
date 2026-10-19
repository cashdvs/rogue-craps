## Cold Sixes (Elite twist): "6s never light." params.face (default 6).
class_name RuleColdSixes
extends TableRule


func can_light(_run: BonfireRun, value: int) -> bool:
	return value != int(param("face", 6))
