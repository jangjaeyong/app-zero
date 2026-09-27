class_name SequenceInteraction
extends PartInteraction
## 정해진 순서로 누른다 (기획서 3번 Sequence).
##
## 순서를 틀리면 그 그룹이 통째로 처음으로 돌아간다. 그래서 외우기 전에
## 한 번 보여 준다 — 그룹이 열리는 순간 순서대로 한 번 점등한다(게임 쪽에서).
## 사이먼 게임과 같은 약속이고, 설명 없이 읽힌다.

func _on_begin() -> void:
	var d := part.params()
	if not free:
		part.set_outline(Part.OUTLINE_BLOCKED, 0.45)
		_reject(Vector3.ZERO)
		return

	if ctx.engine.sequence_expects(d.sequence_group, d.sequence_index):
		part.set_outline(Part.OUTLINE_FREE, 0.7)
		Sfx.play_varied(d.sfx_release, -5.0)
		Haptics.release()
		_sink()
		_complete()
		return

	# 순서가 틀렸다. 그룹을 되돌린다.
	part.set_outline(Part.OUTLINE_BLOCKED, 0.8)
	Sfx.play("relock", -4.0)
	Haptics.bump()
	ctx.engine.reset_group(d.sequence_group)
	_reject(Vector3.ZERO)

func _sink() -> void:
	var d := part.params()
	if d.press_depth <= 0.0:
		return
	var home: Vector3 = part.home_transform.origin
	var tw := part.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(part, "position", home + d.remove_direction * d.press_depth, 0.11)
	tw.tween_callback(func() -> void:
		if is_instance_valid(part):
			part.commit_home())

func _on_finish() -> void:
	part.state = Part.State.IDLE
	if part.state != Part.State.SETTLED:
		part.set_outline(Part.OUTLINE_FREE, 0.0)
