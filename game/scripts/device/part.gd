class_name Part
extends StaticBody3D
## 장치의 조작 가능한 부품 하나.
## 메시는 GLB 에서 그대로 가져오고, 퍼즐 로직은 여기 안 들어간다 (기획서 9번).
## 이 클래스가 아는 것은 "어떻게 보이고 어떻게 반응하는가" 뿐이다.

enum State { IDLE, ENGAGED, REMOVED }

const OUTLINE_BLOCKED := Color(1.0, 0.32, 0.28)
const OUTLINE_FREE := Color(0.18, 0.78, 0.98)
const OUTLINE_HINT := Color(1.0, 0.72, 0.22)

var def: PartDef
var state: State = State.IDLE
var home_transform: Transform3D
var mesh: MeshInstance3D

var _outline: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _surface_mat: StandardMaterial3D
var _base_emission: Color = Color.BLACK
var _base_emission_energy: float = 0.0
var _shake_tween: Tween
var _outline_tween: Tween

func setup(part_def: PartDef, mesh_node: MeshInstance3D) -> void:
	def = part_def
	name = "Part_" + def.id
	mesh = mesh_node
	home_transform = transform

	_build_collision()
	_build_outline()
	_grab_surface_material()

func _build_collision() -> void:
	# 레이캐스트 픽킹 전용. 물리 시뮬레이션은 안 돌린다 (중력 0).
	# 냉각 튜브처럼 휜 부품은 볼록 껍질로 만들면 앞면을 통째로 덮어버려
	# 뒤에 있는 부품의 터치를 가로챈다. 그래서 trimesh 를 쓴다.
	if mesh == null or mesh.mesh == null:
		return
	var shape := mesh.mesh.create_trimesh_shape()
	if shape == null:
		push_warning("[Part] %s 충돌 형상 생성 실패" % def.id)
		return
	var cs := CollisionShape3D.new()
	cs.name = "Pick"
	cs.shape = shape
	cs.transform = mesh.transform
	add_child(cs)

func _build_outline() -> void:
	## 셰이더 없이 만드는 외곽선: 같은 메시를 살짝 부풀려 앞면 컬링으로 그린다.
	if mesh == null or mesh.mesh == null:
		return
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_outline_mat.grow = true
	_outline_mat.grow_amount = 0.016
	_outline_mat.albedo_color = Color(OUTLINE_FREE, 0.0)
	_outline_mat.render_priority = 1

	_outline = MeshInstance3D.new()
	_outline.name = "Outline"
	_outline.mesh = mesh.mesh
	_outline.transform = mesh.transform
	_outline.material_override = _outline_mat
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	add_child(_outline)

func _grab_surface_material() -> void:
	## 코어 발광을 연출하려면 재질을 만져야 하는데, GLB 재질은 여러 부품이
	## 공유할 수 있다. 사본을 만들어 이 부품에만 덮어쓴다.
	if mesh == null or mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return
	var src := mesh.mesh.surface_get_material(0)
	if src is StandardMaterial3D:
		_surface_mat = (src as StandardMaterial3D).duplicate()
		mesh.set_surface_override_material(0, _surface_mat)
		_base_emission = _surface_mat.emission
		_base_emission_energy = _surface_mat.emission_energy_multiplier

# --- 외곽선 -------------------------------------------------------------

func set_outline(color: Color, alpha: float) -> void:
	if _outline == null:
		return
	if _outline_tween != null and _outline_tween.is_valid():
		_outline_tween.kill()
	_outline.visible = alpha > 0.001
	_outline_mat.albedo_color = Color(color, alpha)

func fade_outline(color: Color, alpha: float, time: float) -> void:
	if _outline == null:
		return
	if _outline_tween != null and _outline_tween.is_valid():
		_outline_tween.kill()
	_outline.visible = true
	_outline_mat.albedo_color = Color(color, _outline_mat.albedo_color.a)
	_outline_tween = create_tween()
	_outline_tween.tween_property(_outline_mat, "albedo_color:a", alpha, time)
	if alpha <= 0.001:
		_outline_tween.tween_callback(func() -> void:
			if is_instance_valid(_outline):
				_outline.visible = false)

## 막고 있는 부품에 붉은 점등 — "얘 때문이다" 를 말로 안 하고 보여준다.
func flash_blocker() -> void:
	if _outline == null:
		return
	if _outline_tween != null and _outline_tween.is_valid():
		_outline_tween.kill()
	_outline.visible = true
	_outline_mat.albedo_color = Color(OUTLINE_BLOCKED, 0.0)
	_outline_tween = create_tween()
	_outline_tween.tween_property(_outline_mat, "albedo_color:a", 0.95, 0.07)
	_outline_tween.tween_property(_outline_mat, "albedo_color:a", 0.0, 0.45)
	_outline_tween.tween_callback(func() -> void:
		if is_instance_valid(_outline):
			_outline.visible = false)

func pulse(color: Color, cycles: int = 3) -> void:
	if _outline == null:
		return
	if _outline_tween != null and _outline_tween.is_valid():
		_outline_tween.kill()
	_outline.visible = true
	_outline_mat.albedo_color = Color(color, 0.0)
	_outline_tween = create_tween()
	for i in cycles:
		_outline_tween.tween_property(_outline_mat, "albedo_color:a", 0.85, 0.28)
		_outline_tween.tween_property(_outline_mat, "albedo_color:a", 0.05, 0.32)
	_outline_tween.tween_callback(func() -> void:
		if is_instance_valid(_outline):
			_outline.visible = false)

# --- 걸림 연출 ----------------------------------------------------------

## 덜컥. 팝업 대신 이걸 쓴다 (기획서 4번).
func shake(axis: Vector3 = Vector3.ZERO) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var dir := axis
	if dir.length_squared() < 0.0001:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized() * 0.018
	var home := home_transform.origin
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position", home + dir, 0.035)
	_shake_tween.tween_property(self, "position", home - dir * 0.7, 0.045)
	_shake_tween.tween_property(self, "position", home + dir * 0.35, 0.045)
	_shake_tween.tween_property(self, "position", home, 0.06)

func settle_home(time: float = 0.14) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_property(self, "transform", home_transform, time)

func snap_home() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	transform = home_transform

# --- 발광 (코어) --------------------------------------------------------

func has_surface_material() -> bool:
	return _surface_mat != null

func set_emission(color: Color, energy: float) -> void:
	if _surface_mat == null:
		return
	_surface_mat.emission = color
	_surface_mat.emission_energy_multiplier = energy

func base_emission() -> Color:
	return _base_emission

func base_emission_energy() -> float:
	return _base_emission_energy

func surface_material() -> StandardMaterial3D:
	return _surface_mat
