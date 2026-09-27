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
	# 되돌아가던 트윈이 살아 있으면 드래그와 싸운다. 잡는 순간 끊는다.
	part.kill_motion()
	part.state = Part.State.ENGAGED
	_on_begin()

## 손가락이 처음 닿은 자리. 끌기를 쓰는 조작만 쓴다.
func set_start(_screen_pos: Vector2) -> void:
	pass

func update(_screen_pos: Vector2) -> void:
	pass

func tick(_delta: float) -> void:
	pass

## 손을 뗐다.
func finish() -> void:
	if _done:
		return
	_on_finish()

## 두 번째 손가락이 들어와 핀치로 넘어갈 때 등. 켜 둔 표시를 반드시 끈다 —
## 예전에는 테두리가 켜진 채로 남았다.
func cancel() -> void:
	if _done:
		return
	part.state = Part.State.IDLE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	progress_changed.emit(0.0)
	_on_cancel()
	part.settle_home()

func _on_cancel() -> void:
	pass

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
	# 시작할 때의 자격을 끝까지 믿으면 안 된다. 그 사이에 벌칙이나 되돌리기로
	# 막는 부품이 되살아났을 수 있다.
	if ctx != null and ctx.engine != null and not ctx.engine.is_free(part.def.id):
		free = false
		blockers = ctx.engine.blockers_of(part.def.id)
		part.settle_home()
		_reject(Vector3.ZERO)
		return
	_done = true
	part.state = Part.State.REMOVED if part.def.leaves_device() else Part.State.SETTLED
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
