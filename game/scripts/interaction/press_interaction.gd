class_name PressInteraction
extends PartInteraction
## 눌러서 잠근다. 손가락이 닿는 순간 끝난다 — 버튼은 망설이지 않는다.
##
## 막혀 있으면 살짝 들어갔다 튕겨 나온다. 눌리지 않는 버튼이라는 걸
## 손가락이 먼저 안다.

func _on_begin() -> void:
	if not free:
		part.set_outline(Part.OUTLINE_BLOCKED, 0.45)
		_bounce()
		_reject(part.def.remove_direction)
		return
	part.set_outline(Part.OUTLINE_FREE, 0.5)
	Sfx.play_varied("snap", -4.0)
	Haptics.release()
	_complete()

## 안 눌리는 버튼: 조금 들어갔다 바로 나온다.
func _bounce() -> void:
	var dir: Vector3 = part.def.remove_direction * (part.def.press_depth * 0.35)
	var home: Vector3 = part.home_transform.origin
	var tw := part.create_tween()
	tw.tween_property(part, "position", home + dir, 0.05)
	tw.tween_property(part, "position", home, 0.09)

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
