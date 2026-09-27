class_name DeviceFx
extends Node3D
## 장치 주변 파티클 (기획서 8번: "Particle → 필요한 순간만").
##
## 상시로 뿌리지 않는다. 코어에서 나는 옅은 증기만 늘 있고,
## 나머지는 뭔가 일어났을 때만 터진다. 모바일이고, 무엇보다
## 늘 있는 효과는 아무 의미도 전달하지 못한다.

const SMOKE := "res://assets/textures/smoke.png"
const SPARK := "res://assets/textures/spark.png"

const STEAM_BASE := 10        ## 평상시 증기 입자 수
const STEAM_MAX := 34         ## 불안정도 최대일 때

var _steam: GPUParticles3D
var _sparks: GPUParticles3D

func _ready() -> void:
	_steam = _make_steam()
	add_child(_steam)
	_sparks = _make_sparks()
	add_child(_sparks)

## 코어 자리로 옮긴다. 장치마다 코어 위치가 다르다.
func follow(world_pos: Vector3) -> void:
	global_position = world_pos

## 불안정도에 따라 증기가 늘고 붉어진다. 숫자를 안 봐도 장치가 말해 준다.
func set_heat(heat: float) -> void:
	if _steam == null:
		return
	_steam.amount_ratio = clampf(0.35 + heat * 0.65, 0.0, 1.0)
	var mat := _steam.process_material as ParticleProcessMaterial
	if mat != null:
		mat.initial_velocity_min = 0.10 + heat * 0.30
		mat.initial_velocity_max = 0.28 + heat * 0.55
	var draw := _steam.draw_pass_1 as QuadMesh
	if draw != null and draw.material is StandardMaterial3D:
		var m := draw.material as StandardMaterial3D
		m.albedo_color = Color(0.85, 0.80, 0.74).lerp(Color(1.0, 0.42, 0.26), heat)
		m.albedo_color.a = 0.20 + heat * 0.30

## 과부하. 한 번 터지고 끝난다.
func burst() -> void:
	if _sparks == null:
		return
	_sparks.restart()
	_sparks.emitting = true

func stop_steam() -> void:
	if _steam != null:
		_steam.emitting = false

func _quad(texture_path: String, color: Color, size: float,
		additive: bool) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	mat.albedo_color = color
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if ResourceLoader.exists(texture_path):
		mat.albedo_texture = load(texture_path)
	else:
		push_warning("[DeviceFx] 파티클 텍스처가 없다: %s" % texture_path)

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	return quad

func _make_steam() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.13
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.10
	pm.initial_velocity_max = 0.28
	pm.gravity = Vector3(0, 0.06, 0)
	pm.damping_min = 0.15
	pm.damping_max = 0.35
	pm.scale_min = 0.35
	pm.scale_max = 0.95
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -22.0
	pm.angular_velocity_max = 22.0

	# 태어날 때 옅고, 커지면서 사라진다
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1.0, 1.6))
	var tex := CurveTexture.new()
	tex.curve = curve
	pm.scale_curve = tex

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.22, Color(1, 1, 1, 1.0))
	ramp.add_point(0.62, Color(1, 1, 1, 0.55))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var p := GPUParticles3D.new()
	p.name = "Steam"
	p.amount = STEAM_MAX
	p.amount_ratio = 0.35
	p.lifetime = 2.8
	p.preprocess = 1.5
	p.process_material = pm
	p.draw_pass_1 = _quad(SMOKE, Color(0.85, 0.80, 0.74, 0.20), 0.30, false)
	p.position = Vector3(0, 0.10, 0)
	return p

func _make_sparks() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.10
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.1
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3(0, -3.2, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.8
	pm.scale_min = 0.35
	pm.scale_max = 0.9

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.55, 1.0))
	ramp.set_color(1, Color(1.0, 0.28, 0.06, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = 44
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.process_material = pm
	p.draw_pass_1 = _quad(SPARK, Color(1.0, 0.72, 0.30, 1.0), 0.075, true)
	return p
