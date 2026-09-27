class_name SlideInteraction
extends PullInteraction
## 레일을 따라 밀어 넣는다. 당기기와 손동작은 같지만 **부품이 빠지지 않는다.**
## 끝까지 밀면 걸려서 그 자리에 남고, 그 상태가 다른 부품의 잠금을 푼다.
##
## 중간에서 손을 떼면 가까운 쪽 끝으로 붙는다. 어중간한 위치를 남기지 않는다 —
## 걸쇠는 반쯤 걸린 상태가 없다.

const LATCH_FRACTION := 0.55

func _on_finish() -> void:
	if not free:
		part.state = Part.State.IDLE
		part.set_outline(Part.OUTLINE_FREE, 0.0)
		_reject(_world_dir)
		part.settle_home()
		return

	if _travel >= part.params().remove_distance * LATCH_FRACTION:
		_latch()
		return

	part.state = Part.State.IDLE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	part.settle_home(0.16)
	Sfx.play_varied("slide", -12.0)

func _latch() -> void:
	var target: Vector3 = _home + part.params().remove_direction * part.params().remove_distance
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	var tw := part.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(part, "position", target, 0.12)
	tw.tween_callback(func() -> void:
		# 여기가 이제 이 부품의 제자리다. 나중에 흔들려도 되돌아올 곳.
		if is_instance_valid(part):
			part.commit_home())
	_complete()
