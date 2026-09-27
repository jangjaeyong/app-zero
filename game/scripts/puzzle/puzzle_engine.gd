class_name PuzzleEngine
extends RefCounted
## 퍼즐 판정의 단일 진실. Physics 에 맡기지 않는다 (기획서 5번).
## 렌더링/입력은 여기 묻기만 하고, 여기는 노드를 모른다.

signal part_removed(id: String)
signal part_restored(id: String)
signal newly_freed(ids: PackedStringArray)
signal stage_cleared()

var stage: StageDef
var _removed: Dictionary = {}          ## id -> true
var _history: Array[String] = []       ## 되돌리기용 제거 순서
var moves: int = 0

func _init(stage_def: StageDef) -> void:
	stage = stage_def

func reset() -> void:
	_removed.clear()
	_history.clear()
	moves = 0

func is_removed(id: String) -> bool:
	return _removed.has(id)

## 아직 안 빠진 채로 이 부품을 막고 있는 것들.
func blockers_of(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var p: PartDef = stage.parts.get(id)
	if p == null:
		return out
	for b in p.blocked_by:
		if not _removed.has(b):
			out.append(b)
	return out

func is_free(id: String) -> bool:
	return not is_removed(id) and blockers_of(id).is_empty()

func free_parts() -> PackedStringArray:
	var out := PackedStringArray()
	for id in stage.part_order:
		if is_free(id):
			out.append(id)
	return out

func remaining() -> int:
	return stage.part_order.size() - _removed.size()

func total() -> int:
	return stage.part_order.size()

func history() -> Array[String]:
	return _history.duplicate()

func mark_removed(id: String) -> void:
	if _removed.has(id):
		return
	var before := free_parts()
	_removed[id] = true
	_history.append(id)
	moves += 1
	part_removed.emit(id)

	# 이번 제거로 새로 열린 것들. "오, 안쪽에 또 뭐가 있네" 를 만드는 신호다.
	var opened := PackedStringArray()
	for f in free_parts():
		if not before.has(f):
			opened.append(f)
	if not opened.is_empty():
		newly_freed.emit(opened)

	if is_cleared():
		stage_cleared.emit()

## 되돌리기. 마지막에 뺀 것만 되돌린다.
func undo() -> String:
	if _history.is_empty():
		return ""
	var id: String = _history.pop_back()
	_removed.erase(id)
	moves = max(0, moves - 1)
	part_restored.emit(id)
	return id

func is_cleared() -> bool:
	return _removed.size() >= stage.part_order.size()

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
