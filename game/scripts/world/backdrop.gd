class_name Backdrop
extends Node3D
## 장치 뒤의 연구실. 기획서 8번 "배경 → 단순화된 3D 또는 이미지".
##
## 지금까지 배경이 검정이라 장치가 허공에 떠 있었다. 시안의 흐릿한 실험실을
## 값싸게 흉내 낸다 — 멀리 있는 덩어리 실루엣 + 초점 나간 불빛.
##
## 비용을 아끼는 방법:
##  - 실루엣은 조명을 받지 않는다(UNSHADED). 그림자도 안 만든다
##  - 불빛은 빌보드 쿼드 한 장씩. 진짜 광원이 아니다
##  - 안개가 멀수록 지워 주므로 디테일이 필요 없다
## 카메라가 360도 도니까 뒤쪽만 세우면 들킨다. 빙 둘러 세운다.

const BOKEH := "res://assets/textures/bokeh.png"

const BLOCK_COUNT := 34
const LIGHT_COUNT := 80
## 세로 화면이라 가로 시야각이 23도밖에 안 된다. 가까이 두면 링의 대부분이
## 화면 밖으로 나가고, 걸린 하나는 거대하게 보인다. 멀리 넓게 흩는다.
const NEAR := 5.5
const FAR := 15.0

## 카메라가 장치를 내려다보므로 화면 위쪽 끝은 거의 수평선이다.
## 멀리 있는 것은 바닥선과 수평선 사이 **얇은 띠**에만 보인다.
## 게다가 바닥판이 그 아래를 다 가린다 — 배경을 바닥에 세워야 한다.
## (처음에 눈높이에 세웠다가 통째로 안 보였다)
const GROUND := -0.77

@export var seed_value: int = 20260927

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_blocks(rng)
	_build_lights(rng)

## 멀리 있는 장비 덩어리. 형태만 있고 색은 거의 없다.
func _build_blocks(rng: RandomNumberGenerator) -> void:
	var shades: Array[Color] = [
		Color(0.075, 0.094, 0.137),
		Color(0.098, 0.122, 0.169),
		Color(0.055, 0.071, 0.110),
	]
	for i in BLOCK_COUNT:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(NEAR, FAR)
		var w := rng.randf_range(1.0, 3.2)
		var h := rng.randf_range(0.9, 3.4)
		var d := rng.randf_range(0.9, 2.6)

		var box := BoxMesh.new()
		box.size = Vector3(w, h, d)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = shades[i % shades.size()]
		mat.disable_receive_shadows = true

		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(angle) * dist, GROUND + h * 0.5, sin(angle) * dist)
		mi.rotation.y = rng.randf_range(-0.5, 0.5)
		add_child(mi)

## 초점 나간 불빛. 이게 배경을 "연구실" 로 읽히게 만드는 유일한 요소다.
func _build_lights(rng: RandomNumberGenerator) -> void:
	if not ResourceLoader.exists(BOKEH):
		push_warning("[Backdrop] 보케 텍스처가 없다. python3 tools/make_fx_textures.py")
		return
	var tex: Texture2D = load(BOKEH)
	var palette: Array[Color] = [
		Color(0.180, 0.780, 0.980),   # 시안
		Color(0.180, 0.780, 0.980),
		Color(1.000, 0.616, 0.180),   # 앰버
		Color(0.700, 0.820, 1.000),   # 차가운 흰빛
	]
	for i in LIGHT_COUNT:
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(NEAR - 1.0, FAR)
		# 크기를 거리에 비례시킨다. 안 그러면 가까운 것만 풍선처럼 커진다.
		var size: float = rng.randf_range(0.022, 0.052) * dist

		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(palette[i % palette.size()],
			rng.randf_range(0.10, 0.34))
		mat.disable_receive_shadows = true
		mat.no_depth_test = false

		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 바닥선과 수평선 사이. 여기 말고는 화면에 안 걸린다.
		mi.position = Vector3(cos(angle) * dist,
			rng.randf_range(GROUND + 0.10, GROUND + 1.70), sin(angle) * dist)
		add_child(mi)
