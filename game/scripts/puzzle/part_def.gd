class_name PartDef
extends RefCounted
## 부품 한 개의 퍼즐 정의. 코드가 아니라 스테이지 JSON 에서 온다 (기획서 10번).

## 기획서 3번의 조작 이름을 그대로 쓴다.
## Press 는 "길게 누름" 이다. 짧게 톡 누르는 것이 아니다.
## (기획서의 Hold — 한 부품을 고정하면서 다른 부품 조작 — 은 아직 없다)
enum Interaction { PULL, ROTATE, SLIDE, PRESS, ALIGN, ROUTE, SEQUENCE }

## 조작이 끝났을 때 이 부품이 어떻게 되는가.
##   REMOVE — 장치에서 빠져 트레이로 간다 (패널, 셀, 커버)
##   SETTLE — 제자리에 남는다. 밀려 들어갔거나, 눌려 잠겼거나, 정렬됐다
## 둘 다 "해결됨"이고, 둘 다 남의 blocked_by 를 푼다.
enum Resolve { REMOVE, SETTLE }

const _INTERACTIONS := {
	"pull": Interaction.PULL,
	"rotate": Interaction.ROTATE,
	"slide": Interaction.SLIDE,
	"press": Interaction.PRESS,
	"hold": Interaction.PRESS,     ## 예전 데이터 호환. 기획서의 Hold 와는 다른 것이었다
	"align": Interaction.ALIGN,
	"route": Interaction.ROUTE,
	"sequence": Interaction.SEQUENCE,
}

## 따로 적지 않으면 조작 종류가 결과를 정한다.
const _DEFAULT_RESOLVE := {
	Interaction.PULL: Resolve.REMOVE,
	Interaction.ROTATE: Resolve.REMOVE,
	Interaction.SLIDE: Resolve.SETTLE,
	Interaction.PRESS: Resolve.SETTLE,
	Interaction.ALIGN: Resolve.SETTLE,
	Interaction.ROUTE: Resolve.SETTLE,
	Interaction.SEQUENCE: Resolve.SETTLE,
}

var id: String = ""
var label: String = ""
var interaction: Interaction = Interaction.PULL
var resolve: Resolve = Resolve.REMOVE
var blocked_by: PackedStringArray = PackedStringArray()
var is_core: bool = false

# 당기기 / 밀기 공통 (직선 이동)
var remove_direction: Vector3 = Vector3.UP
var remove_distance: float = 0.35
var resist_distance: float = 0.04

# 돌리기 / 맞추기 (도 단위. 부호가 방향)
var rotation_axis: Vector3 = Vector3.UP
var rotation_target: float = 120.0
var resist_angle: float = 8.0
var align_tolerance: float = 7.0      ## 맞추기: 이 오차 안에서 손을 떼야 걸린다
var align_range: float = 180.0        ## 맞추기: 돌릴 수 있는 범위(±)

# 누르기 (길게)
var press_depth: float = 0.045
var press_seconds: float = 0.5

# Route — 케이블·파이프를 정해진 경로로 끌고 간다
var route_points: Array[Vector3] = []     ## 장치 로컬 좌표. 첫 점이 출발지
var route_tolerance: float = 0.16         ## 경로에서 이만큼 벗어나면 걸린다

# Sequence — 같은 그룹을 정해진 순서로 누른다
var sequence_group: String = ""
var sequence_index: int = 0

# Multi-step — 한 부품을 여러 단계 조작한 뒤에야 풀린다
var steps: Array[PartDef] = []

# 사운드
var sfx_engage: String = ""
var sfx_release: String = ""
var sfx_tick: String = ""

static func from_dict(d: Dictionary) -> PartDef:
	var p := PartDef.new()
	p.id = String(d.get("id", ""))
	p.label = String(d.get("label", p.id))
	p.interaction = _INTERACTIONS.get(
		String(d.get("interaction", "pull")).to_lower(), Interaction.PULL)
	p.resolve = _DEFAULT_RESOLVE.get(p.interaction, Resolve.REMOVE)
	if d.has("resolve"):
		p.resolve = Resolve.SETTLE if String(d["resolve"]).to_lower() == "settle" \
			else Resolve.REMOVE
	for b in d.get("blocked_by", []):
		p.blocked_by.append(String(b))
	p.is_core = bool(d.get("is_core", false))

	# slide 는 방향/거리를 제 이름으로도 적을 수 있게 한다. 읽기 좋으라고.
	p.remove_direction = _vec(d.get("remove_direction",
		d.get("slide_direction", [0, 1, 0])), Vector3.UP).normalized()
	p.remove_distance = float(d.get("remove_distance", d.get("slide_distance", 0.35)))
	p.resist_distance = float(d.get("resist_distance", 0.04))

	p.rotation_axis = _vec(d.get("rotation_axis", [0, 1, 0]), Vector3.UP).normalized()
	p.rotation_target = float(d.get("rotation_target", 120.0))
	p.resist_angle = float(d.get("resist_angle", 8.0))
	p.align_tolerance = float(d.get("align_tolerance", 7.0))
	p.align_range = float(d.get("align_range", 180.0))

	p.press_depth = float(d.get("press_depth", 0.045))
	p.press_seconds = float(d.get("press_seconds", d.get("hold_seconds", 0.5)))

	for v in d.get("route_points", []):
		p.route_points.append(_vec(v, Vector3.ZERO))
	p.route_tolerance = float(d.get("route_tolerance", 0.16))

	p.sequence_group = String(d.get("sequence_group", ""))
	p.sequence_index = int(d.get("sequence_index", 0))

	p.sfx_engage = String(d.get("sfx_engage", ""))
	p.sfx_release = String(d.get("sfx_release", ""))
	p.sfx_tick = String(d.get("sfx_tick", ""))

	# 여러 단계. 각 단계가 제 조작과 값을 갖는다.
	# 단계는 부모의 값을 물려받고 적힌 것만 덮어쓴다 — 매번 다 적지 않게.
	for raw in d.get("steps", []):
		var merged: Dictionary = d.duplicate()
		merged.erase("steps")
		for k in (raw as Dictionary):
			merged[k] = raw[k]
		merged["id"] = p.id
		var step := PartDef.from_dict(merged)
		p.steps.append(step)
	return p

func has_steps() -> bool:
	return not steps.is_empty()

func step_count() -> int:
	return maxi(1, steps.size())

## index 번째 단계의 값 묶음. 단계가 없으면 자기 자신.
func step_at(index: int) -> PartDef:
	if steps.is_empty():
		return self
	return steps[clampi(index, 0, steps.size() - 1)]

static func _vec(v: Variant, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback

func leaves_device() -> bool:
	return resolve == Resolve.REMOVE

func interaction_name() -> String:
	match interaction:
		Interaction.PULL: return "PULL"
		Interaction.ROTATE: return "ROTATE"
		Interaction.SLIDE: return "SLIDE"
		Interaction.PRESS: return "PRESS"
		Interaction.ALIGN: return "ALIGN"
		Interaction.ROUTE: return "ROUTE"
		Interaction.SEQUENCE: return "SEQUENCE"
	return "?"
