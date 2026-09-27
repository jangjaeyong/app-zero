class_name AlignInteraction
extends PartInteraction
## 눈금을 맞춘다. 돌리기와 다른 점: **목표 각에서 손을 떼야** 걸린다.
## 얼마나 돌렸는가가 아니라 어디에 세웠는가를 본다.
##
## 빗나가도 되돌아가지 않는다. 그 자리에 남아서 조금씩 고쳐 잡을 수 있다.
## 이게 "정렬" 의 손맛이다.

const TICK_DEGREES := 10.0
const PIVOT_DEADZONE := 8.0

var _axis_world: Vector3
var _sign: float = 1.0
var _center: Vector2
var _last_pos: Vector2 = Vector2.ZERO
var _has_reference: bool = false
var _angle: float = 0.0             ## 기준 자세로부터의 현재 각(도)
var _home_basis: Basis
var _next_tick: float = TICK_DEGREES

func _on_begin() -> void:
	_home_basis = part.home_transform.basis
	_angle = part.align_angle
	_axis_world = (part.get_parent().global_transform.basis
		* part.params().rotation_axis).normalized()

	var cam_forward := -ctx.camera.global_transform.basis.z
	var toward := -signf(_axis_world.dot(cam_forward))
	if is_zero_approx(toward):
		toward = 1.0
	_sign = -toward

	_center = ctx.camera.unproject_position(part.global_position)
	_next_tick = absf(_angle) + TICK_DEGREES
	part.set_outline(Part.OUTLINE_FREE if free else Part.OUTLINE_BLOCKED, 0.35)
	_emit_closeness()

func set_start(screen_pos: Vector2) -> void:
	_grab_reference(screen_pos)

## 중심 근처에서는 각을 잴 수 없다. 기준을 못 잡았으면 이번 프레임은 버린다 —
## 0도를 기준으로 삼으면 손가락을 조금 옮긴 것이 큰 회전으로 들어간다.
func _grab_reference(screen_pos: Vector2) -> bool:
	_center = ctx.camera.unproject_position(home_world())
	if (screen_pos - _center).length() < PIVOT_DEADZONE:
		return false
	_last_pos = screen_pos
	_has_reference = true
	return true

## 중심이 화면에서 움직여도(카메라 관성) 회전이 끼어들지 않게,
## 각이 아니라 **두 화면 위치의 차이** 로 잰다.
func _delta_degrees(screen_pos: Vector2) -> float:
	_center = ctx.camera.unproject_position(home_world())
	var a := _last_pos - _center
	var b := screen_pos - _center
	if a.length() < PIVOT_DEADZONE or b.length() < PIVOT_DEADZONE:
		return 0.0
	return wrapf(rad_to_deg(b.angle() - a.angle()), -180.0, 180.0)

func update(screen_pos: Vector2) -> void:
	if not _has_reference:
		_grab_reference(screen_pos)
		return
	var raw: float = _delta_degrees(screen_pos)
	if is_zero_approx(raw):
		return
	_last_pos = screen_pos
	var d: float = raw * _sign

	if not free:
		# 막혀 있으면 저항각까지만 덜컹거린다.
		_angle = clampf(_angle + d, -part.params().resist_angle, part.params().resist_angle)
		if absf(_angle) > part.params().resist_angle * 0.8:
			_reject(Vector3.ZERO)
	else:
		_angle = clampf(_angle + d, -part.params().align_range, part.params().align_range)

	_apply()
	while free and absf(_angle) >= _next_tick:
		Sfx.play_varied(part.params().sfx_tick, -10.0)
		Haptics.tick()
		_next_tick += TICK_DEGREES
	if absf(_angle) < _next_tick - TICK_DEGREES:
		_next_tick = maxf(TICK_DEGREES, absf(_angle) + TICK_DEGREES)
	_emit_closeness()

func _apply() -> void:
	var basis := _home_basis * Basis(part.params().rotation_axis.normalized(),
		deg_to_rad(_angle))
	part.transform = Transform3D(basis, part.home_transform.origin)

## 목표에 얼마나 가까운가. 링이 차오르는 것으로 보여 준다.
func _emit_closeness() -> void:
	var err: float = absf(_angle - part.params().rotation_target)
	var span: float = maxf(part.params().align_range, 1.0)
	progress_changed.emit(clampf(1.0 - err / span, 0.0, 1.0))

## 취소돼도 지금 각도는 남겨야 한다. 안 그러면 다음에 잡을 때 튄다.
func _on_cancel() -> void:
	part.align_angle = _angle

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.align_angle = _angle

	if not free:
		part.set_outline(Part.OUTLINE_FREE, 0.0)
		_reject(Vector3.ZERO)
		_angle = 0.0
		part.align_angle = 0.0
		part.settle_home(0.18)
		progress_changed.emit(0.0)
		return

	var err: float = absf(_angle - part.params().rotation_target)
	if err <= part.params().align_tolerance:
		_angle = part.params().rotation_target
		part.align_angle = _angle
		_apply()
		part.commit_home()
		part.set_outline(Part.OUTLINE_FREE, 0.0)
		progress_changed.emit(0.0)
		_complete()
		return

	# 빗나갔다. 되돌리지 않고 그 자리에 둔다 — 조금씩 고쳐 잡으라고.
	Sfx.play_varied("click", -12.0)
	part.set_outline(Part.OUTLINE_HINT, 0.0)
	progress_changed.emit(0.0)
