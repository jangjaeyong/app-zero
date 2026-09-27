class_name PuzzleEngine
extends RefCounted
## 퍼즐 판정의 단일 진실. Physics 에 맡기지 않는다 (기획서 5번).
## 렌더링/입력은 여기 묻기만 하고, 여기는 노드를 모른다.
##
## "해결됨(resolved)" 은 빠진 것과 제자리에 잠긴 것을 함께 가리킨다.
## 밀어 넣은 걸쇠나 눌러 잠근 버튼도 남의 blocked_by 를 푼다.

signal part_resolved(id: String)
signal part_restored(id: String)
signal newly_freed(ids: PackedStringArray)
signal stage_cleared()

var stage: StageDef
var _resolved: Dictionary = {}          ## id -> true
var _history: Array[String] = []        ## 되돌리기용 순서
var moves: int = 0

func _init(stage_def: StageDef) -> void:
	stage = stage_def

func reset() -> void:
	_resolved.clear()
	_history.clear()
	moves = 0

func is_resolved(id: String) -> bool:
	return _resolved.has(id)

## 아직 해결되지 않은 채로 이 부품을 막고 있는 것들.
func blockers_of(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var p: PartDef = stage.parts.get(id)
	if p == null:
		return out
	for b in p.blocked_by:
		if not _resolved.has(b):
			out.append(b)
	return out

func is_free(id: String) -> bool:
	return not is_resolved(id) and blockers_of(id).is_empty()

func free_parts() -> PackedStringArray:
	var out := PackedStringArray()
	for id in stage.part_order:
		if is_free(id):
			out.append(id)
	return out

func remaining() -> int:
	return stage.part_order.size() - _resolved.size()

func total() -> int:
	return stage.part_order.size()

func done_count() -> int:
	return _resolved.size()

func history() -> Array[String]:
	return _history.duplicate()

func mark_resolved(id: String) -> void:
	if _resolved.has(id):
		return
	var before := free_parts()
	_resolved[id] = true
	_history.append(id)
	moves += 1
	part_resolved.emit(id)

	# 이번 수로 새로 열린 것들. "오, 안쪽에 또 뭐가 있네" 를 만드는 신호다.
	var opened := PackedStringArray()
	for f in free_parts():
		if not before.has(f):
			opened.append(f)
	if not opened.is_empty():
		newly_freed.emit(opened)

	if is_cleared():
		stage_cleared.emit()

## 되돌리기. 마지막 한 수만 되돌린다.
## refund_move 가 false 면 수를 돌려주지 않는다 — 벌칙으로 되돌릴 때 쓴다.
## 진행만 잃고 쓴 수는 남아야 아프다.
func undo(refund_move: bool = true) -> String:
	if _history.is_empty():
		return ""
	var id: String = _history.pop_back()
	_resolved.erase(id)
	if refund_move:
		moves = max(0, moves - 1)
	part_restored.emit(id)
	return id

func is_cleared() -> bool:
	return _resolved.size() >= stage.part_order.size()

# --- 순서 그룹 -----------------------------------------------------------

## 이 그룹에서 지금 눌러야 할 차례인가.
func sequence_expects(group: String, index: int) -> bool:
	if group.is_empty():
		return true
	return index == group_progress(group)

## 그룹에서 이미 해결된 개수 = 다음에 와야 할 번호.
func group_progress(group: String) -> int:
	var n := 0
	for id in members_of(group):
		if _resolved.has(id):
			n += 1
	return n

## 그룹 구성원을 순서대로.
func members_of(group: String) -> PackedStringArray:
	var out: Array[String] = []
	for id in stage.part_order:
		var p: PartDef = stage.parts[id]
		if p.sequence_group == group and not group.is_empty():
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return (stage.parts[a] as PartDef).sequence_index \
			< (stage.parts[b] as PartDef).sequence_index)
	var packed := PackedStringArray()
	for id in out:
		packed.append(id)
	return packed

## 순서를 틀렸다. 그룹을 처음으로 되돌린다.
## 쓴 수는 돌려주지 않는다 — 틀린 것은 대가가 있어야 한다.
func reset_group(group: String) -> PackedStringArray:
	var undone := PackedStringArray()
	for id in members_of(group):
		if not _resolved.has(id):
			continue
		_resolved.erase(id)
		var at := _history.find(id)
		if at >= 0:
			_history.remove_at(at)
		undone.append(id)
		part_restored.emit(id)
	return undone

## 힌트: 지금 건드릴 수 있는 것 중 하나. 코어는 마지막에만 고른다.
func hint() -> String:
	var free := free_parts()
	if free.is_empty():
		return ""
	for id in free:
		var p: PartDef = stage.parts[id]
		if not p.is_core:
			return id
	return free[0]
