class_name StageCatalog
extends RefCounted
## 챕터와 스테이지 목록. 코드가 아니라 chapters.json 에서 온다.
## 스테이지를 늘릴 때 고칠 곳은 이 JSON 하나다.

const PATH := "res://resources/stages/chapters.json"

class Chapter extends RefCounted:
	var id: String = ""
	var index: int = 0
	var title: String = ""
	var subtitle: String = ""
	var description: String = ""
	var accent: Color = Color(0.180, 0.780, 0.980)
	var stages: PackedStringArray = PackedStringArray()

	func count() -> int:
		return stages.size()

	func is_playable() -> bool:
		return not stages.is_empty()

var chapters: Array[Chapter] = []

static func load_default() -> StageCatalog:
	var c := StageCatalog.new()
	if not FileAccess.file_exists(PATH):
		push_error("[StageCatalog] 목록 파일이 없다: %s" % PATH)
		return c
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[StageCatalog] JSON 파싱 실패: %s" % PATH)
		return c

	for raw in (parsed as Dictionary).get("chapters", []):
		var ch := Chapter.new()
		ch.id = String(raw.get("id", ""))
		ch.index = int(raw.get("index", c.chapters.size() + 1))
		ch.title = String(raw.get("title", ch.id))
		ch.subtitle = String(raw.get("subtitle", ""))
		ch.description = String(raw.get("description", ""))
		ch.accent = Color(String(raw.get("accent", "#2EC7FA")))
		for s in raw.get("stages", []):
			var path := String(s)
			if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
				push_error("[StageCatalog] %s 의 스테이지 파일이 없다: %s" % [ch.id, path])
				continue
			ch.stages.append(path)
		c.chapters.append(ch)
	return c

func chapter(id: String) -> Chapter:
	for c in chapters:
		if c.id == id:
			return c
	return null

func chapter_of(stage_path: String) -> Chapter:
	for c in chapters:
		if c.stages.has(stage_path):
			return c
	return null

## 이 스테이지 다음 것. 챕터의 마지막이면 빈 문자열.
func next_of(stage_path: String) -> String:
	var c := chapter_of(stage_path)
	if c == null:
		return ""
	var i := Array(c.stages).find(stage_path)
	if i < 0 or i + 1 >= c.stages.size():
		return ""
	return c.stages[i + 1]

func first_playable() -> String:
	for c in chapters:
		if c.is_playable():
			return c.stages[0]
	return ""

func total_stages() -> int:
	var n := 0
	for c in chapters:
		n += c.stages.size()
	return n
