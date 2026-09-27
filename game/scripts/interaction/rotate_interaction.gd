class_name RotateInteraction
extends PartInteraction
## 링·기어를 원형으로 돌려 잠금을 푼다.
## 막혀 있으면 resist_angle 만큼 덜컹거리고 되돌아온다.

const TICK_DEGREES := 12.0

var _axis_world: Vector3
var _sign: float = 1.0                 ## 화면 회전 방향 → 축 회전 부호
var _center: Vector2
var _last_angle: float = 0.0
var _accum: float = 0.0                ## 목표 방향 기준 누적 각(항상 0 이상)
var _applied: float = 0.0
var _next_tick: float = TICK_DEGREES
var _home_basis: Basis
var _target: float = 120.0

func _on_begin() -> void:
	_home_basis = part.home_transform.basis
	_target = absf(part.def.rotation_target)
	_axis_world = (part.get_parent().global_transform.basis * part.def.rotation_axis).normalized()

	# 축이 화면 쪽을 향하면 화면상 시계방향이 축 기준 음의 회전이 된다.
	var cam_forward := -ctx.camera.global_transform.basis.z
	var toward := -signf(_axis_world.dot(cam_forward))
	if is_zero_approx(toward):
		toward = 1.0
	# rotation_target 의 부호가 "어느 쪽으로 돌려야 하는가"다.
	_sign = -toward * signf(part.def.rotation_target)

	_center = ctx.camera.unproject_position(part.global_position)
	_accum = 0.0
	_applied = 0.0
	_next_tick = TICK_DEGREES
	part.set_outline(Part.OUTLINE_FREE if free else Part.OUTLINE_BLOCKED, 0.35)

func set_start(screen_pos: Vector2) -> void:
	_last_angle = _angle_at(screen_pos)

func _angle_at(screen_pos: Vector2) -> float:
	var v := screen_pos - _center
	if v.length() < 8.0:
		return _last_angle
	return rad_to_deg(atan2(v.y, v.x))

func update(screen_pos: Vector2) -> void:
	var a := _angle_at(screen_pos)
	var d: float = wrapf(a - _last_angle, -180.0, 180.0)
	_last_angle = a

	# 목표 방향으로 돈 만큼만 쌓는다. 반대로 돌리면 도로 줄어든다.
	_accum = maxf(0.0, _accum + d * _sign)

	var limit: float = _target if free else part.def.resist_angle
	_applied = minf(_accum, limit)

	if not free and _accum > part.def.resist_angle * 0.8:
		_reject(Vector3.ZERO)

	_apply_rotation(_applied)

	while free and _applied >= _next_tick and _next_tick < _target:
		Sfx.play_varied(part.def.sfx_tick, -9.0)
		Haptics.tick()
		_next_tick += TICK_DEGREES

	progress_changed.emit(clampf(_applied / maxf(_target, 0.001), 0.0, 1.0))

	if free and _applied >= _target - 0.001:
		_complete()

func _apply_rotation(degrees: float) -> void:
	var signed: float = degrees * signf(part.def.rotation_target)
	var basis := _home_basis * Basis(part.def.rotation_axis.normalized(), deg_to_rad(signed))
	part.transform = Transform3D(basis, part.home_transform.origin)

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	if not free:
		_reject(Vector3.ZERO)
		part.settle_home()
		return
	# 중간까지만 돌렸으면 스르륵 제자리로. 부분 진행은 남기지 않는다.
	progress_changed.emit(0.0)
	part.settle_home(0.22)
