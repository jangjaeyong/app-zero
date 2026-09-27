class_name PartTray
extends Control
## 뜯어낸 부품이 쌓이는 하단 격납 트레이 (시안의 그 칸들).
##
## 3D 부품을 UI 위에 얹어야 하는데, 메인 월드에 그대로 두면 카메라를 당겼을 때
## 장치에 파묻힌다. 그래서 자기만의 World3D 를 가진 SubViewport 안에 놓고
## 정사영 카메라로 격자에 배치한다. 깊이 문제도 조명 문제도 여기서 끊긴다.

const COLS := 4
const ROWS := 2
const ORTHO_HEIGHT := 1.0
const SLOT_FIT := 0.46          ## 칸 안에서 부품의 최대 변이 차지할 크기
const SCALE_RANGE := Vector2(0.34, 1.0)
const PRESENT_TILT := Vector2(-15.0, 22.0)

var _viewport: SubViewport
var _slots_root: Node3D
var _slot_frames: Array[MeshInstance3D] = []
var _occupants: Dictionary = {}     ## slot index -> Part
var _part_slot: Dictionary = {}     ## part id -> slot index

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.name = "TrayViewportContainer"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.name = "TrayViewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	# 내용이 바뀔 때만 그린다. 매 프레임 3D 패스를 한 번 더 도는 것은
	# 중급 폰에서 그냥 버리는 비용이다.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)

	_build_world()
	# stretch 가 켜져 있으면 SubViewport 크기는 컨테이너가 잡는다.
	# 우리는 크기가 확정된 뒤에 칸 위치만 다시 계산하면 된다.
	_viewport.size_changed.connect(_relayout_slots)
	_relayout_slots()

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.46, 0.58)
	env.ambient_light_energy = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.96, 0.90)
	key.shadow_enabled = false
	_viewport.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(16, 145, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.45, 0.78, 1.0)
	rim.shadow_enabled = false
	_viewport.add_child(rim)

	var cam := Camera3D.new()
	cam.name = "TrayCamera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO_HEIGHT
	cam.position = Vector3(0, 0, 3.0)
	cam.near = 0.05
	cam.far = 10.0
	_viewport.add_child(cam)

	_slots_root = Node3D.new()
	_slots_root.name = "Slots"
	_viewport.add_child(_slots_root)

	for i in COLS * ROWS:
		var frame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.58, 0.42)
		frame.mesh = quad
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.075, 0.110, 0.180, 0.34)
		frame.material_override = m
		frame.position = _slot_position(i) + Vector3(0, 0, -0.6)
		_slots_root.add_child(frame)
		_slot_frames.append(frame)

## 뷰포트 크기가 바뀌면 격자가 어긋난다. 칸틀과 이미 담긴 부품을 같이 옮긴다.
## 잠깐 그리고 다시 멈춘다.
func _wake(seconds: float) -> void:
	if _viewport == null:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _relayout_slots() -> void:
	if _viewport == null:
		return
	_wake(0.1)
	for i in _slot_frames.size():
		_slot_frames[i].position = _slot_position(i) + Vector3(0, 0, -0.6)
	for index in _occupants:
		var p: Part = _occupants[index]
		if is_instance_valid(p):
			p.position = _slot_position(index)

func _slot_position(index: int) -> Vector3:
	var aspect: float = 1080.0 / 420.0
	if _viewport != null and _viewport.size.y > 0:
		aspect = float(_viewport.size.x) / float(_viewport.size.y)
	var half_w: float = ORTHO_HEIGHT * 0.5 * aspect
	var col: int = index % COLS
	var row: int = index / COLS
	var step_x: float = (half_w * 2.0) / float(COLS)
	var x: float = -half_w + step_x * (float(col) + 0.5)
	var y: float = ORTHO_HEIGHT * 0.25 - float(row) * (ORTHO_HEIGHT * 0.5)
	return Vector3(x, y, 0.0)

## 제거된 부품을 트레이로 받는다. 여기서부터 이 부품은 메인 월드를 떠난다.
func accept(part: Part, index: int) -> void:
	if index < 0 or index >= _slot_frames.size():
		index = _occupants.size()
	if index >= COLS * ROWS:
		part.visible = false
		return

	part.collision_layer = 0
	part.input_ray_pickable = false
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	if part.mesh != null:
		part.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var present := _present_transform(part)
	part.reparent(_slots_root, false)
	part.transform = Transform3D(present, _slot_position(index))
	# 크기 0 은 행렬식이 0 이라 엔진이 역행렬을 못 구한다. 아주 작게 시작한다.
	part.scale = Vector3.ONE * 0.001
	part.visible = true

	_occupants[index] = part
	_part_slot[part.def.id] = index

	var tw := part.track(part.create_tween())
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(part, "scale", Vector3.ONE * _present_scale(part), 0.32)
	_wake(0.45)

## 얇은 판은 옆에서 보면 카드 한 장이다. 가장 얇은 축을 화면 쪽으로 돌려
## 제일 넓은 면이 보이게 한 다음, 살짝 기울여 입체감을 준다.
func _present_transform(part: Part) -> Basis:
	var size := _extent(part)
	var order := [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return size[a] > size[b])
	var axis_x := Vector3.ZERO
	var axis_y := Vector3.ZERO
	var axis_z := Vector3.ZERO
	axis_x[order[0]] = 1.0      ## 가장 긴 축 → 화면 가로
	axis_y[order[1]] = 1.0      ## 중간 축   → 화면 세로
	axis_z[order[2]] = 1.0      ## 가장 얇은 축 → 화면 안쪽
	if axis_x.cross(axis_y).dot(axis_z) < 0.0:
		axis_z = -axis_z
	var align := Basis(axis_x, axis_y, axis_z).transposed()
	return Basis(Vector3.RIGHT, deg_to_rad(PRESENT_TILT.x)) \
		* Basis(Vector3.UP, deg_to_rad(PRESENT_TILT.y)) * align

func _present_scale(part: Part) -> float:
	var size := _extent(part)
	var longest: float = maxf(size.x, maxf(size.y, size.z))
	if longest <= 0.0001:
		return SCALE_RANGE.x
	return clampf(SLOT_FIT / longest, SCALE_RANGE.x, SCALE_RANGE.y)

func _extent(part: Part) -> Vector3:
	if part.mesh == null or part.mesh.mesh == null:
		return Vector3.ONE
	return part.mesh.mesh.get_aabb().size

## 되돌리기. 부품을 장치로 돌려보낸다.
func release(part: Part, device_parts_root: Node3D) -> void:
	var id := part.def.id
	if _part_slot.has(id):
		_occupants.erase(_part_slot[id])
		_part_slot.erase(id)
	part.reparent(device_parts_root, false)
	part.reset_to_origin()
	part.visible = true
	part.collision_layer = DeviceRig.PICK_LAYER
	part.input_ray_pickable = true
	if part.mesh != null:
		part.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_wake(0.1)

func clear() -> void:
	_occupants.clear()
	_part_slot.clear()

func filled() -> int:
	return _occupants.size()
