extends Node
## 지금 어느 스테이지를 하고 있는지와 화면 전환. 게임 전체에서 하나.
##
## 씬을 직접 바꾸는 코드를 여기 한 곳에 모아 둔다. 화면이 늘어나도
## 경로 문자열이 여기저기 흩어지지 않게.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const SELECT_SCENE := "res://scenes/ui/stage_select.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"

var catalog: StageCatalog
var current_stage_path: String = ""
var current_chapter_id: String = ""
## 경로 → 스테이지 id. 메뉴와 선택 화면이 스테이지마다 여러 번 묻는다.
## 캐시가 없으면 60판에서 화면을 열 때마다 JSON 60개를 다시 읽는다.
var _id_cache: Dictionary = {}

func _ready() -> void:
	catalog = StageCatalog.load_default()

## 스테이지 파일을 읽어 정의를 돌려준다. 못 읽으면 null.
func load_stage(path: String) -> StageDef:
	return StageDef.load_from(path)

func stage_id_of(path: String) -> String:
	if _id_cache.has(path):
		return _id_cache[path]
	var s := load_stage(path)
	var id := s.id if s != null else ""
	_id_cache[path] = id
	return id

func play(stage_path: String) -> void:
	if stage_path.is_empty():
		push_error("[Session] 빈 스테이지 경로로 시작하려 했다")
		return
	current_stage_path = stage_path
	var c := catalog.chapter_of(stage_path)
	current_chapter_id = c.id if c != null else ""
	get_tree().change_scene_to_file(GAME_SCENE)

func play_next() -> bool:
	var nxt := catalog.next_of(current_stage_path)
	if nxt.is_empty():
		return false
	play(nxt)
	return true

func has_next() -> bool:
	return not catalog.next_of(current_stage_path).is_empty()

func replay() -> void:
	get_tree().reload_current_scene()

func goto_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func goto_select(chapter_id: String = "") -> void:
	if not chapter_id.is_empty():
		current_chapter_id = chapter_id
	get_tree().change_scene_to_file(SELECT_SCENE)

## 아직 아무것도 안 깼으면 첫 스테이지, 아니면 이어서 할 것.
func continue_target() -> String:
	for c in catalog.chapters:
		for i in c.stages.size():
			var sid := stage_id_of(c.stages[i])
			if not sid.is_empty() and not Progress.is_cleared(sid):
				if Progress.is_unlocked(_ids_of(c), i):
					return c.stages[i]
	return catalog.first_playable()

func _ids_of(c: StageCatalog.Chapter) -> PackedStringArray:
	var out := PackedStringArray()
	for path in c.stages:
		out.append(stage_id_of(path))
	return out

func stage_ids_of(c: StageCatalog.Chapter) -> PackedStringArray:
	return _ids_of(c)
