class_name PartDef
extends RefCounted
## 부품 한 개의 퍼즐 정의. 코드가 아니라 스테이지 JSON 에서 온다 (기획서 10번).

enum Interaction { PULL, ROTATE, HOLD }

const _INTERACTION_NAMES := {
	"pull": Interaction.PULL,
	"rotate": Interaction.ROTATE,
	"hold": Interaction.HOLD,
}

var id: String = ""
var label: String = ""
var interaction: Interaction = Interaction.PULL
var blocked_by: PackedStringArray = PackedStringArray()
var is_core: bool = false

# Pull
var remove_direction: Vector3 = Vector3.UP
var remove_distance: float = 0.35
var resist_distance: float = 0.04

# Rotate (도 단위로 저장. 부호가 회전 방향이다)
var rotation_axis: Vector3 = Vector3.UP
var rotation_target: float = 120.0
var resist_angle: float = 8.0

# Hold
var hold_seconds: float = 1.5

# 사운드
var sfx_engage: String = ""
var sfx_release: String = ""
var sfx_tick: String = ""

static func from_dict(d: Dictionary) -> PartDef:
	var p := PartDef.new()
	p.id = String(d.get("id", ""))
	p.label = String(d.get("label", p.id))
	p.interaction = _INTERACTION_NAMES.get(String(d.get("interaction", "pull")).to_lower(),
		Interaction.PULL)
	for b in d.get("blocked_by", []):
		p.blocked_by.append(String(b))
	p.is_core = bool(d.get("is_core", false))

	p.remove_direction = _vec(d.get("remove_direction", [0, 1, 0]), Vector3.UP).normalized()
	p.remove_distance = float(d.get("remove_distance", 0.35))
	p.resist_distance = float(d.get("resist_distance", 0.04))

	p.rotation_axis = _vec(d.get("rotation_axis", [0, 1, 0]), Vector3.UP).normalized()
	p.rotation_target = float(d.get("rotation_target", 120.0))
	p.resist_angle = float(d.get("resist_angle", 8.0))

	p.hold_seconds = float(d.get("hold_seconds", 1.5))

	p.sfx_engage = String(d.get("sfx_engage", ""))
	p.sfx_release = String(d.get("sfx_release", ""))
	p.sfx_tick = String(d.get("sfx_tick", ""))
	return p

static func _vec(v: Variant, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback

func interaction_name() -> String:
	match interaction:
		Interaction.PULL: return "PULL"
		Interaction.ROTATE: return "ROTATE"
		Interaction.HOLD: return "HOLD"
	return "?"
