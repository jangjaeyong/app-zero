extends Control
## 챕터와 스테이지 고르기. 시안 2 의 3D 맵은 아직 아니고,
## 같은 정보를 담은 목록이다. 맵은 스테이지가 쌓인 뒤에 만든다.
##
## 스테이지를 늘려도 이 화면은 손대지 않는다 — chapters.json 만 보고 그린다.

const CARD_HEIGHT := 150

var _list: VBoxContainer
var _content: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# 배경은 화면 끝까지, 내용은 안전 영역 안으로.
	SafeArea.bind(_content)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.NAVY
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var title := UiStyle.label("CHAPTERS", 44, UiStyle.WHITE, 14)
	UiStyle.anchor(title, 0, 0, 1, 0, 52, 56, -52, 120)
	_content.add_child(title)

	var total := UiStyle.label(_total_text(), 22, Color(UiStyle.DIM, 0.9), 4)
	UiStyle.anchor(total, 0, 0, 1, 0, 54, 126, -52, 166)
	_content.add_child(total)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiStyle.anchor(scroll, 0, 0, 1, 1, 40, 200, -40, -160)
	_content.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 26)
	scroll.add_child(_list)

	for chapter in Session.catalog.chapters:
		_list.add_child(_chapter_block(chapter))

	var back := UiStyle.button("← 메인", 30, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	UiStyle.anchor(back, 0, 1, 1, 1, 40, -130, -40, -40)
	back.pressed.connect(func() -> void: Session.goto_menu())
	_content.add_child(back)

func _total_text() -> String:
	var cleared := 0
	var total := 0
	var stars := 0
	for c in Session.catalog.chapters:
		for id in Session.stage_ids_of(c):
			if id.is_empty():
				continue
			total += 1
			stars += Progress.stars(id)
			if Progress.is_cleared(id):
				cleared += 1
	return "CLEARED %d / %d      ★ %d / %d" % [cleared, total, stars, total * 3]

func _chapter_block(chapter: StageCatalog.Chapter) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	box.add_child(head)
	head.add_child(UiStyle.label("%02d" % chapter.index, 38, chapter.accent, 2))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UiStyle.label(chapter.title, 32, UiStyle.WHITE, 6))
	names.add_child(UiStyle.label(chapter.subtitle, 17, Color(UiStyle.DIM, 0.95), 4))
	head.add_child(names)

	if chapter.is_playable():
		var ids := Session.stage_ids_of(chapter)
		head.add_child(UiStyle.label("★ %d / %d" % [
			Progress.chapter_stars(ids), chapter.count() * 3],
			22, UiStyle.AMBER, 2))
	else:
		head.add_child(UiStyle.label("준비 중", 20, Color(UiStyle.DIM, 0.8), 3))

	var desc := UiStyle.label(chapter.description, 19, Color(UiStyle.DIM, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	if not chapter.is_playable():
		return box

	var ids := Session.stage_ids_of(chapter)
	for i in chapter.stages.size():
		box.add_child(_stage_card(chapter, i, ids))
	return box

func _stage_card(chapter: StageCatalog.Chapter, index: int,
		ids: PackedStringArray) -> Control:
	var path := chapter.stages[index]
	var def := Session.load_stage(path)
	var sid := ids[index] if index < ids.size() else ""
	var unlocked := Progress.is_unlocked(ids, index)
	var stars := Progress.stars(sid)

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.disabled = not unlocked
	var border: Color = chapter.accent if unlocked else Color(UiStyle.DIM, 0.35)
	card.add_theme_stylebox_override("normal",
		UiStyle.panel(Color(UiStyle.PANEL, 0.75), Color(border, 0.7), 18, 2))
	card.add_theme_stylebox_override("hover",
		UiStyle.panel(Color(UiStyle.PANEL, 0.95), border, 18, 2))
	card.add_theme_stylebox_override("pressed",
		UiStyle.panel(Color(border, 0.25), border, 18, 2))
	card.add_theme_stylebox_override("disabled",
		UiStyle.panel(Color(UiStyle.PANEL, 0.35), Color(UiStyle.DIM, 0.25), 18, 2))
	if unlocked:
		card.pressed.connect(func() -> void:
			Sfx.play("snap", -8.0)
			Session.play(path))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -26
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var dim: float = 1.0 if unlocked else 0.45
	row.add_child(UiStyle.label("%02d" % (index + 1), 40,
		Color(chapter.accent, dim), 2))

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := def.title if def != null and not def.title.is_empty() else "???"
	text.add_child(UiStyle.label(name if unlocked else "잠김", 26,
		Color(UiStyle.WHITE, dim), 2))
	var note := "%d개 부품  ·  기준 %d수" % [
		def.part_order.size() if def != null else 0,
		def.par_moves if def != null else 0]
	if not unlocked:
		note = "앞 스테이지를 먼저 해결한다"
	elif Progress.is_cleared(sid):
		note = "최고 %d수  ·  %s" % [Progress.best_moves(sid), note]
	text.add_child(UiStyle.label(note, 17, Color(UiStyle.DIM, dim)))
	row.add_child(text)

	var marks := ""
	for i in 3:
		marks += "★" if unlocked and i < stars else "☆"
	var mark_color: Color = Color(UiStyle.DIM, 0.4 if unlocked else 0.22)
	if unlocked and stars > 0:
		mark_color = UiStyle.AMBER
	row.add_child(UiStyle.label(marks, 26, mark_color, 3))
	return card
