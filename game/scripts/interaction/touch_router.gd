class_name TouchRouter
extends Node
## 손가락 하나가 부품 위에 닿았으면 조작, 빈 곳이면 카메라 회전.
## 두 개 이상이면 핀치 줌. 입력 해석은 전부 여기 한 곳에서만 한다.
##
## 손가락이 늘고 주는 경우의 수가 생각보다 많다. 예전 판은 그때마다
## 남은 손가락이 죽거나, 잠긴 뒤에도 조작이 계속되거나, OS 가 릴리스를
## 흘리면 영원히 핀치 모드에 갇혔다. 그래서 상태를 하나로 모았다.

const RAY_LENGTH := 100.0
const PINCH_DEADZONE := 6.0

signal part_engaged(part: Part)
signal part_completed(part: Part)
signal part_rejected(part: Part, blockers: PackedStringArray)
signal interaction_progress(value: float)
signal empty_tapped()

enum Mode { IDLE, PART, ORBIT, PINCH }

var ctx: InteractionContext
var orbit: OrbitCamera

## 잠그면 **진행 중인 조작까지** 끊는다. 예전에는 새 터치만 막아서,
## 시간이 다 된 뒤에도 쥐고 있던 부품이 계속 진행해 클리어까지 됐다.
var input_locked: bool = false:
	set(v):
		input_locked = v
		if v:
			_abort_interaction()
			_mode = Mode.IDLE

var _touches: Dictionary = {}          ## index -> Vector2
var _mode: int = Mode.IDLE
var _primary: int = -1
var _interaction: PartInteraction
var _press_pos: Vector2 = Vector2.ZERO
var _moved: bool = false

var _pinch_pair: Array[int] = []
var _pinch_base: float = 0.0
var _pinch_base_distance: float = 0.0

func _process(delta: float) -> void:
	if input_locked:
		return
	if _interaction != null:
		_interaction.tick(delta)

## 앱이 뒤로 가거나 창을 잃으면 OS 가 릴리스를 흘릴 수 있다.
## 그러면 남은 유령 손가락 때문에 이후 모든 터치가 두 번째 손가락 취급이 된다.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
		NOTIFICATION_APPLICATION_PAUSED:
			_reset_all()

func _reset_all() -> void:
	_abort_interaction()
	_touches.clear()
	_pinch_pair.clear()
	_primary = -1
	_mode = Mode.IDLE

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

# --- 손가락 수에 따라 상태를 다시 고른다 ---------------------------------

func _on_press(index: int, pos: Vector2) -> void:
	_touches[index] = pos
	if _touches.size() >= 2:
		_enter_pinch()
		return

	_primary = index
	_press_pos = pos
	_moved = false

	if input_locked:
		_mode = Mode.ORBIT
		return

	var part := pick(pos)
	# 제자리에 남는 부품(밀린 걸쇠, 눌린 버튼)은 해결된 뒤에도 거기 있다.
	if part != null and ctx.engine != null and ctx.engine.is_resolved(part.def.id):
		part = null
	if part != null:
		_begin_interaction(part, pos)
	else:
		_mode = Mode.ORBIT

func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(index):
		return                       # 누른 적 없는 손가락. 유령이다
	_touches[index] = pos
	if input_locked:
		return

	if _mode == Mode.PINCH:
		_update_pinch()
		return
	if index != _primary:
		return
	if (pos - _press_pos).length() > 6.0:
		_moved = true

	if _mode == Mode.PART and _interaction != null:
		_interaction.update(pos)
	elif _mode == Mode.ORBIT and orbit != null:
		orbit.orbit(relative)

func _on_release(index: int) -> void:
	if not _touches.has(index):
		return
	_touches.erase(index)

	if _mode == Mode.PART and index == _primary and _interaction != null:
		_interaction.finish()
		_interaction = null
	elif _mode == Mode.ORBIT and index == _primary and not _moved:
		empty_tapped.emit()

	if _touches.is_empty():
		_primary = -1
		_pinch_pair.clear()
		_mode = Mode.IDLE
		return

	if _touches.size() >= 2:
		# 아직 두 개 이상 남았다. 참여하는 짝이 바뀌었을 수 있으니 다시 잡는다.
		_enter_pinch()
		return

	# 하나만 남았다. 남은 손가락을 카메라로 넘긴다 — 부품 조작을 새로
	# 시작하지는 않는다(의도치 않은 제거 방지). 예전에는 이 손가락이 죽어 있었다.
	for k in _touches:
		_primary = k
		_press_pos = _touches[k]
	_pinch_pair.clear()
	_moved = true
	_mode = Mode.ORBIT

# --- 부품 조작 -----------------------------------------------------------

func _begin_interaction(part: Part, pos: Vector2) -> void:
	var inter: PartInteraction
	match part.active_interaction():
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
		PartDef.Interaction.ROUTE:
			inter = RouteInteraction.new()
		PartDef.Interaction.SEQUENCE:
			inter = SequenceInteraction.new()
		_:
			inter = PullInteraction.new()

	inter.completed.connect(_on_completed)
	inter.rejected.connect(_on_rejected)
	inter.progress_changed.connect(func(v: float) -> void: interaction_progress.emit(v))
	# 등록과 알림을 먼저. begin() 안에서 바로 완료되는 조작(순서 버튼)이 있다.
	_interaction = inter
	_mode = Mode.PART
	part_engaged.emit(part)
	inter.begin(part, ctx)
	if _interaction == inter:
		inter.set_start(pos)

func _abort_interaction() -> void:
	if _interaction == null:
		return
	_interaction.cancel()
	_interaction = null
	interaction_progress.emit(0.0)

func _on_completed(part: Part) -> void:
	_interaction = null
	if _mode == Mode.PART:
		_mode = Mode.IDLE if _touches.is_empty() else Mode.ORBIT
	interaction_progress.emit(0.0)
	part_completed.emit(part)

func _on_rejected(part: Part, blockers: PackedStringArray) -> void:
	part_rejected.emit(part, blockers)

# --- 핀치 ----------------------------------------------------------------

## 참여하는 두 손가락이 바뀌면 기준 거리를 다시 잡는다.
## 안 그러면 손가락 하나를 바꿔 짚었을 때 화면이 확 튄다.
func _enter_pinch() -> void:
	var keys: Array = _touches.keys()
	keys.sort()
	var pair: Array[int] = [keys[0], keys[1]]
	if _mode == Mode.PINCH and pair == _pinch_pair:
		return
	_abort_interaction()
	_pinch_pair = pair
	_mode = Mode.PINCH
	_primary = -1
	_pinch_base = (_touches[pair[0]] as Vector2).distance_to(_touches[pair[1]])
	_pinch_base_distance = orbit.distance() if orbit != null else 0.0

func _update_pinch() -> void:
	if orbit == null or _pinch_pair.size() < 2:
		return
	if not (_touches.has(_pinch_pair[0]) and _touches.has(_pinch_pair[1])):
		return
	var d: float = (_touches[_pinch_pair[0]] as Vector2).distance_to(
		_touches[_pinch_pair[1]])
	if _pinch_base < PINCH_DEADZONE:
		return
	orbit.set_distance(_pinch_base_distance / maxf(d / _pinch_base, 0.05))

# --- 픽킹 ----------------------------------------------------------------

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
