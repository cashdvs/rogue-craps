## Camera2D with pixel-amplitude screen shake (poc_feel.md 6: "shake 6 px /
## 0.2 s"). The strongest active shake wins and decays linearly to zero.
class_name ShakeCamera
extends Camera2D

var _amp: float = 0.0
var _dur: float = 0.0
var _left: float = 0.0
var _rng := RandomNumberGenerator.new()
## Set by the table when reduced motion is on.
var disabled: bool = false


func shake(pixels: float, seconds: float) -> void:
	if disabled or pixels <= 0.0 or seconds <= 0.0:
		return
	var current := _amp * (_left / maxf(_dur, 0.0001))
	if pixels >= current:
		_amp = pixels
		_dur = seconds
		_left = seconds


func current_amplitude() -> float:
	return _amp * (_left / maxf(_dur, 0.0001)) if _left > 0.0 else 0.0


func _process(delta: float) -> void:
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		var a := current_amplitude()
		offset = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))
		rotation = _rng.randf_range(-1.0, 1.0) * a * 0.0012
	else:
		offset = Vector2.ZERO
		rotation = 0.0
