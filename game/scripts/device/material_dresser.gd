class_name MaterialDresser
extends RefCounted
## GLB 재질에 표면 디테일을 입힌다 (기획서 8번: 작은 디테일은 Normal Map 으로).
##
## **UV 를 펴지 않는다.** 장치를 60개 깎아야 하는데 Blender 에서 UV 를 일일이
## 펴면 장치당 반나절이 날아간다. Godot 의 삼중평면 매핑은 좌표만으로 텍스처를
## 감아 준다. 대신 타일링이 완벽해야 하는데, 텍스처를 그렇게 만들어 뒀다
## (tools/make_textures.py).
##
## 새 장치를 만들 때 할 일이 없다 — DeviceRig 가 알아서 부른다.

const NORMAL_PATH := "res://assets/textures/surface_normal.png"
const ROUGH_PATH := "res://assets/textures/surface_rough.png"
const GRIME_PATH := "res://assets/textures/surface_grime.png"

## 재질 이름별 세기. 흰 도장면은 얌전하게, 금속은 세게, 유리와 발광체는 건드리지 않는다.
##   [노멀 세기, 텍스처 반복(1유닛당), 거칠기 변화, 때]
const RECIPE := {
	"M_Panel": [0.50, 4.0, 0.88, 0.14],
	"M_Gun":   [0.70, 5.0, 0.94, 0.18],
	"M_Dark":  [0.65, 5.0, 0.94, 0.20],
	"M_Steel": [0.60, 7.0, 0.92, 0.14],
	"M_Brass": [0.50, 8.0, 0.92, 0.14],
	"M_Base":  [0.45, 4.0, 0.94, 0.16],
}
const DEFAULT := [0.0, 3.0, 0.0, 0.0]        ## 유리·발광체는 그대로 둔다

static var _normal: Texture2D
static var _rough: Texture2D
static var _grime: Texture2D
static var _loaded: bool = false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(NORMAL_PATH):
		_normal = load(NORMAL_PATH)
	if ResourceLoader.exists(ROUGH_PATH):
		_rough = load(ROUGH_PATH)
	if ResourceLoader.exists(GRIME_PATH):
		_grime = load(GRIME_PATH)
	if _normal == null:
		push_warning("[MaterialDresser] 표면 텍스처가 없다. python3 tools/make_textures.py")

## 메시의 모든 표면에 디테일을 입힌다. 원본 재질은 건드리지 않고 사본을 덮어쓴다
## (GLB 재질은 여러 부품이 공유한다).
static func dress(mesh: MeshInstance3D) -> void:
	_load()
	if mesh == null or mesh.mesh == null or _normal == null:
		return
	for i in mesh.mesh.get_surface_count():
		var src := mesh.mesh.surface_get_material(i)
		if not (src is StandardMaterial3D):
			continue
		var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
		_apply(mat, src.resource_name)
		mesh.set_surface_override_material(i, mat)

static func _apply(mat: StandardMaterial3D, name: String) -> void:
	var r: Array = RECIPE.get(name, DEFAULT)
	var strength: float = r[0]
	if strength <= 0.0:
		return

	var repeat: float = r[1]
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(repeat, repeat, repeat)
	mat.uv1_triplanar_sharpness = 1.0

	mat.normal_enabled = true
	mat.normal_texture = _normal
	mat.normal_scale = strength

	if _rough != null and r[2] > 0.0:
		mat.roughness_texture = _rough
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		# 텍스처는 곱해진다. 원래 거칠기가 낮으면 변화도 작아야 자연스럽다.
		mat.roughness = clampf(mat.roughness / maxf(r[2], 0.01), 0.0, 1.0)

	if _grime != null and r[3] > 0.0:
		mat.ao_enabled = true
		mat.ao_texture = _grime
		mat.ao_on_uv2 = false
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		mat.ao_light_affect = r[3]
