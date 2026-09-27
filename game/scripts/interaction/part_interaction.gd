class_name PartInteraction
extends RefCounted
## 조작 방식의 공통 뼈대. 부품마다 다른 조작을 붙이기 위한 지점이다 (기획서 3번).
##
## 규칙: 여기서는 절대 "제거할 수 없습니다" 같은 걸 띄우지 않는다.
## 막혀 있으면 조금 움직이다 걸리고, rejected 로 알린다.

signal completed(part: Part)
signal rejected(part: Part, blockers: PackedStringArray)
signal progress_changed(value: float)

var part: Part
var ctx: InteractionContext
var free: bool = false
var blockers: PackedStringArray = PackedStringArray()

var _rejected_fired: bool = false
var _done: bool = false

func begin(p: Part, c: InteractionContext) -> void:
	part = p
	ctx = c
	free = ctx.engine.is_free(p.def.id)
	blockers = ctx.engine.blockers_of(p.def.id)
	_rejected_fired = false
	_done = false
	part.state = Part.State.ENGAGED
	_on_begin()

func update(_screen_pos: Vector2) -> void:
	pass

func tick(_delta: float) -> void:
	pass

## 손을 뗐다.
func finish() -> void:
	if _done:
		return
	_on_finish()

func cancel() -> void:
	if _done:
		return
	part.state = Part.State.IDLE
	part.settle_home()

func _on_begin() -> void:
	pass

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.settle_home()

func _reject(shake_axis: Vector3 = Vector3.ZERO) -> void:
	if _rejected_fired:
		return
	_rejected_fired = true
	part.shake(shake_axis)
	rejected.emit(part, blockers)

func _complete() -> void:
	if _done:
		return
	_done = true
	part.state = Part.State.REMOVED
	completed.emit(part)

# --- 화면 ↔ 월드 환산 헬퍼 -------------------------------------------

## 월드 방향 벡터가 화면에서 어느 쪽으로, 1 유닛당 몇 픽셀로 보이는지.
## 방향이 카메라 정면을 향해 거의 찌그러지면 화면 위쪽 드래그로 대체한다.
func screen_axis_of(world_dir: Vector3) -> Dictionary:
	var origin := part.global_position
	var a := ctx.camera.unproject_position(origin)
	var b := ctx.camera.unproject_position(origin + world_dir * 0.25)
	var v := b - a
	if v.length() < 26.0:
		return {"dir": Vector2(0, -1), "px_per_unit": 440.0, "degenerate": true}
	return {"dir": v.normalized(), "px_per_unit": v.length() / 0.25, "degenerate": false}
