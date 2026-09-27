class_name OrbitCamera
extends Node3D
## 장치를 도는 카메라. 자유 비행이 아니라 "퍼즐하기 좋은 범위"로 묶어둔다 (기획서 6번).

@export var min_pitch: float = -12.0
@export var max_pitch: float = 72.0
@export var min_distance: float = 1.7
@export var max_distance: float = 4.2
@export var default_distance: float = 2.9
@export var orbit_speed: float = 0.32       ## 화면 픽셀당 도
@export var smoothing: float = 14.0

var camera: Camera3D

var _yaw: float = -34.0
var _pitch: float = 21.0
var _distance: float = 2.9
var _target_yaw: float = -34.0
var _target_pitch: float = 21.0
var _target_distance: float = 2.9

func _ready() -> void:
	camera = get_node_or_null("Camera3D")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.fov = 44.0
		camera.near = 0.05
		camera.far = 40.0
		add_child(camera)
	_distance = default_distance
	_target_distance = default_distance
	_apply(true)

func _process(delta: float) -> void:
	var t: float = 1.0 - exp(-smoothing * delta)
	_yaw = lerp(_yaw, _target_yaw, t)
	_pitch = lerp(_pitch, _target_pitch, t)
	_distance = lerp(_distance, _target_distance, t)
	_apply(false)

func _apply(_instant: bool) -> void:
	rotation_degrees = Vector3(-_pitch, _yaw, 0.0)
	if camera != null:
		camera.position = Vector3(0, 0, _distance)

## 스테이지가 정한 구도로 맞춘다.
func configure(yaw: float, pitch: float, dist: float, height: float,
		dist_min: float, dist_max: float) -> void:
	min_distance = dist_min
	max_distance = dist_max
	default_distance = clampf(dist, dist_min, dist_max)
	position.y = height
	_yaw = yaw
	_target_yaw = yaw
	_pitch = clampf(pitch, min_pitch, max_pitch)
	_target_pitch = _pitch
	_distance = default_distance
	_target_distance = default_distance
	_apply(true)

func orbit(drag_px: Vector2) -> void:
	_target_yaw -= drag_px.x * orbit_speed
	_target_pitch = clampf(_target_pitch + drag_px.y * orbit_speed, min_pitch, max_pitch)

func zoom(factor: float) -> void:
	_target_distance = clampf(_target_distance / maxf(factor, 0.01), min_distance, max_distance)

## 거리를 직접 지정한다. 항상 허용 범위 안으로 묶는다.
func set_distance(value: float) -> void:
	_target_distance = clampf(value, min_distance, max_distance)

func distance() -> float:
	return _target_distance

func nudge_distance(amount: float) -> void:
	_target_distance = clampf(_target_distance + amount, min_distance, max_distance)

func frame_default() -> void:
	_target_distance = default_distance

## 특정 부품이 잘 보이도록 살짝 돌아본다 (힌트/새로 열린 부품용).
##
## 예전에는 부품을 정면으로 보도록 카메라를 통째로 옮겼는데,
## 구도가 확 바뀌어서 플레이어가 방향을 잃었다. 지금 각도에서
## 조금만 튼다.
const LOOK_YAW_LIMIT := 34.0
const LOOK_PITCH_LIMIT := 14.0

func look_toward(world_pos: Vector3) -> void:
	var local := world_pos - global_position
	if local.length_squared() < 0.0001:
		return
	var want_yaw := rad_to_deg(atan2(local.x, local.z))
	var delta := wrapf(want_yaw - _target_yaw, -180.0, 180.0)
	_target_yaw += clampf(delta, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)

	var want_pitch := rad_to_deg(asin(clampf(local.normalized().y, -1.0, 1.0))) + 14.0
	var pitch_delta := want_pitch - _target_pitch
	_target_pitch = clampf(
		_target_pitch + clampf(pitch_delta, -LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT),
		min_pitch, max_pitch)
