class_name TouchRouter
extends Node
## 손가락 하나가 부품 위에 닿았으면 조작, 빈 곳이면 카메라 회전.
## 두 손가락이면 핀치 줌. 입력 해석은 전부 여기 한 곳에서만 한다.

const RAY_LENGTH := 100.0
const PINCH_DEADZONE := 6.0

signal part_engaged(part: Part)
signal part_completed(part: Part)
signal part_rejected(part: Part, blockers: PackedStringArray)
signal interaction_progress(value: float)
signal empty_tapped()

var ctx: InteractionContext
var orbit: OrbitCamera
var input_locked: bool = false

var _touches: Dictionary = {}          ## index -> Vector2
var _primary: int = -1
var _interaction: PartInteraction
var _orbiting: bool = false
var _pinching: bool = false
var _pinch_base: float = 0.0
var _pinch_base_distance: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _moved: bool = false

func _process(delta: float) -> void:
	if _interaction != null:
		_interaction.tick(delta)

func _unhandled_input(event: InputEvent) -> void:
	if ctx == null or ctx.camera == null:
		return

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
		get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_on_drag(d.index, d.position, d.relative)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		# 데스크톱에서 테스트할 때만 쓰는 휠 줌.
		var m := event as InputEventMouseButton
		if m.pressed and orbit != null:
			if m.button_index == MOUSE_BUTTON_WHEEL_UP:
				orbit.nudge_distance(-0.22)
			elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				orbit.nudge_distance(0.22)

func _on_press(index: int, pos: Vector2) -> void:
	_touches[index] = pos

	if _touches.size() >= 2:
		_abort_interaction()
		_orbiting = false
		_begin_pinch()
		return

	_primary = index
	_press_pos = pos
	_moved = false

	if input_locked:
		_orbiting = true
		return

	var part := pick(pos)
	# 제자리에 남는 부품(밀린 걸쇠, 눌린 버튼)은 해결된 뒤에도 거기 있다.
	# 다시 집히면 안 된다.
	if part != null and ctx.engine != null and ctx.engine.is_resolved(part.def.id):
		part = null
	if part != null:
		_begin_interaction(part, pos)
	else:
		_orbiting = true

func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	_touches[index] = pos

	if _touches.size() >= 2:
		_update_pinch()
		return

	if index != _primary:
		return
	if (pos - _press_pos).length() > 6.0:
		_moved = true

	if _interaction != null:
		_interaction.update(pos)
	elif _orbiting and orbit != null:
		orbit.orbit(relative)

func _on_release(index: int) -> void:
	_touches.erase(index)

	if _touches.size() < 2:
		_pinching = false

	if index != _primary:
		return

	if _interaction != null:
		_interaction.finish()
		_interaction = null
	elif _orbiting and not _moved:
		empty_tapped.emit()

	_orbiting = false
	_primary = -1

	# 두 손가락에서 하나가 떨어진 경우, 남은 손가락을 새 주 손가락으로 삼되
	# 부품 조작은 다시 시작하지 않는다 (의도치 않은 제거 방지).
	if _touches.size() == 1:
		for k in _touches:
			_primary = k
			_press_pos = _touches[k]
		_orbiting = true
		_moved = true

func _begin_interaction(part: Part, pos: Vector2) -> void:
	var inter: PartInteraction
	match part.def.interaction:
		PartDef.Interaction.PULL:
			inter = PullInteraction.new()
		PartDef.Interaction.ROTATE:
			inter = RotateInteraction.new()
		PartDef.Interaction.SLIDE:
			inter = SlideInteraction.new()
		PartDef.Interaction.PRESS:
			inter = PressInteraction.new()
		PartDef.Interaction.ALIGN:
			inter = AlignInteraction.new()
		_:
			inter = PullInteraction.new()

	inter.completed.connect(_on_completed)
	inter.rejected.connect(_on_rejected)
	inter.progress_changed.connect(func(v: float) -> void: interaction_progress.emit(v))
	inter.begin(part, ctx)
	inter.set_start(pos)
	_interaction = inter
	part_engaged.emit(part)

func _abort_interaction() -> void:
	if _interaction == null:
		return
	_interaction.cancel()
	_interaction = null
	interaction_progress.emit(0.0)

func _on_completed(part: Part) -> void:
	_interaction = null
	interaction_progress.emit(0.0)
	part_completed.emit(part)

func _on_rejected(part: Part, blockers: PackedStringArray) -> void:
	part_rejected.emit(part, blockers)

func _begin_pinch() -> void:
	var pts := _touch_points()
	if pts.size() < 2:
		return
	_pinching = true
	_pinch_base = pts[0].distance_to(pts[1])
	_pinch_base_distance = orbit.distance() if orbit != null else 0.0

func _update_pinch() -> void:
	if not _pinching or orbit == null:
		return
	var pts := _touch_points()
	if pts.size() < 2:
		return
	var d := pts[0].distance_to(pts[1])
	if _pinch_base < PINCH_DEADZONE:
		return
	var factor: float = d / _pinch_base
	orbit.set_distance(_pinch_base_distance / maxf(factor, 0.05))

func _touch_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in _touches:
		out.append(_touches[k])
	return out

## 화면 좌표 아래에 있는 부품. 없으면 null.
func pick(pos: Vector2) -> Part:
	var space := ctx.camera.get_world_3d().direct_space_state
	var from := ctx.camera.project_ray_origin(pos)
	var to := from + ctx.camera.project_ray_normal(pos) * RAY_LENGTH
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = DeviceRig.PICK_LAYER
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var c: Object = hit.get("collider")
	return c as Part

func has_active_interaction() -> bool:
	return _interaction != null
