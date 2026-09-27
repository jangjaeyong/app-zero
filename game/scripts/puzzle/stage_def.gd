class_name StageDef
extends RefCounted
## 스테이지 = GLB 하나 + 부품 정의 목록. 새 스테이지는 코드 수정 없이
## 이 JSON 과 GLB 만 추가하면 된다 (기획서 10번).

var id: String = ""
var chapter: String = ""
var index: int = 1
var title: String = ""
var device_model: String = ""
var static_nodes: PackedStringArray = PackedStringArray()
var par_moves: int = 0
var rewards: Dictionary = {}

var part_order: PackedStringArray = PackedStringArray()   ## JSON 에 적힌 순서 보존
var parts: Dictionary = {}                                ## id -> PartDef

static func load_from(path: String) -> StageDef:
	if not FileAccess.file_exists(path):
		push_error("[StageDef] 스테이지 파일 없음: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[StageDef] JSON 파싱 실패: %s" % path)
		return null

	var d: Dictionary = parsed
	var s := StageDef.new()
	s.id = String(d.get("id", "STAGE"))
	s.chapter = String(d.get("chapter", ""))
	s.index = int(d.get("index", 1))
	s.title = String(d.get("title", ""))
	s.device_model = String(d.get("device_model", ""))
	for n in d.get("static_nodes", []):
		s.static_nodes.append(String(n))
	s.par_moves = int(d.get("par_moves", 0))
	s.rewards = d.get("rewards", {})

	for raw in d.get("parts", []):
		var p := PartDef.from_dict(raw)
		if p.id.is_empty():
			push_error("[StageDef] id 없는 부품이 있다: %s" % path)
			continue
		if s.parts.has(p.id):
			push_error("[StageDef] 부품 id 중복: %s" % p.id)
			continue
		s.parts[p.id] = p
		s.part_order.append(p.id)

	s._validate(path)
	return s

## blocked_by 가 존재하지 않는 id 를 가리키거나 순환하면 스테이지가 절대 안 풀린다.
## 조용히 넘어가면 나중에 "왜 안 빠지지"로 몇 시간 날린다. 여기서 크게 터뜨린다.
func _validate(path: String) -> void:
	for id in part_order:
		var p: PartDef = parts[id]
		for b in p.blocked_by:
			if not parts.has(b):
				push_error("[StageDef] %s 의 blocked_by '%s' 가 정의에 없다 (%s)" % [id, b, path])
	var cycle := _find_cycle()
	if not cycle.is_empty():
		push_error("[StageDef] 의존 관계에 순환이 있다: %s (%s)" % [" -> ".join(cycle), path])

func _find_cycle() -> PackedStringArray:
	var state: Dictionary = {}   # 0=미방문 1=방문중 2=완료
	var stack: PackedStringArray = PackedStringArray()
	for id in part_order:
		var found := _walk(id, state, stack)
		if not found.is_empty():
			return found
	return PackedStringArray()

func _walk(id: String, state: Dictionary, stack: PackedStringArray) -> PackedStringArray:
	var s: int = state.get(id, 0)
	if s == 2:
		return PackedStringArray()
	if s == 1:
		var out := stack.duplicate()
		out.append(id)
		return out
	state[id] = 1
	stack.append(id)
	var p: PartDef = parts.get(id)
	if p != null:
		for b in p.blocked_by:
			if parts.has(b):
				var found := _walk(b, state, stack)
				if not found.is_empty():
					return found
	stack.remove_at(stack.size() - 1)
	state[id] = 2
	return PackedStringArray()
