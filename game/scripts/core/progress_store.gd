extends Node
## 진행 저장. `user://progress.cfg` 한 파일.
##
## 저장은 매 클리어마다 즉시 한다. 모바일은 앱이 언제 죽을지 모른다 —
## 종료 시점에 몰아서 쓰면 그 판이 통째로 날아간다.

const PATH := "user://progress.cfg"
const SECTION := "cleared"

signal changed()

var _cfg := ConfigFile.new()

func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[Progress] 진행 파일을 못 읽었다 (%d). 새로 시작한다." % err)
		_cfg = ConfigFile.new()

func _save() -> void:
	var err := _cfg.save(PATH)
	if err != OK:
		push_error("[Progress] 진행 저장 실패 (%d)" % err)
	changed.emit()

## 별 계산: 기준 수 이하면 3, 세 수까지 더 썼으면 2, 그 이상은 1.
static func stars_for(moves: int, par: int) -> int:
	if par <= 0:
		return 3
	if moves <= par:
		return 3
	if moves <= par + 3:
		return 2
	return 1

func record_clear(stage_id: String, moves: int, par: int) -> int:
	var stars := stars_for(moves, par)
	var prev: Dictionary = _cfg.get_value(SECTION, stage_id, {})
	# 더 잘한 기록만 덮어쓴다.
	var best_moves: int = moves
	var best_stars: int = stars
	if not prev.is_empty():
		best_moves = min(int(prev.get("moves", moves)), moves)
		best_stars = max(int(prev.get("stars", stars)), stars)
	_cfg.set_value(SECTION, stage_id, {
		"moves": best_moves,
		"stars": best_stars,
		"clears": int(prev.get("clears", 0)) + 1,
	})
	_save()
	return stars

func is_cleared(stage_id: String) -> bool:
	return not (_cfg.get_value(SECTION, stage_id, {}) as Dictionary).is_empty()

func stars(stage_id: String) -> int:
	return int((_cfg.get_value(SECTION, stage_id, {}) as Dictionary).get("stars", 0))

func best_moves(stage_id: String) -> int:
	return int((_cfg.get_value(SECTION, stage_id, {}) as Dictionary).get("moves", 0))

## 챕터 안에서 앞 스테이지를 깼는지로 잠금을 판단한다.
## 단, **이미 깬 스테이지는 무슨 일이 있어도 열려 있어야 한다.**
## (디버그로 건너뛰거나 챕터 구성이 바뀌면 깬 판이 잠기는 일이 생긴다)
func is_unlocked(stage_ids: PackedStringArray, index: int) -> bool:
	if index < 0 or index >= stage_ids.size():
		return false
	if is_cleared(stage_ids[index]):
		return true
	if index == 0:
		return true
	return is_cleared(stage_ids[index - 1])

func chapter_stars(stage_ids: PackedStringArray) -> int:
	var n := 0
	for id in stage_ids:
		n += stars(id)
	return n

func clear_all() -> void:
	_cfg = ConfigFile.new()
	_save()
