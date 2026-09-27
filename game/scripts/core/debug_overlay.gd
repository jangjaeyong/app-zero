class_name DebugOverlay
extends CanvasLayer
## 개발 빌드 전용 (기획서 20번). 릴리스에서는 game.gd 가 아예 붙이지 않는다.

signal force_remove_requested()
signal reset_requested()
signal open_core_requested()

var engine: PuzzleEngine
var rig: DeviceRig

var _panel: PanelContainer
var _body: Label
var _selected: String = ""
var _accum: float = 0.0

func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.position = Vector2(40, 250)
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.add_theme_stylebox_override("panel",
		UiStyle.panel(Color(0, 0, 0, 0.72), Color(UiStyle.GREEN, 0.5), 10, 1))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	box.add_child(UiStyle.label("DEBUG  ·  F1 닫기  ·  F2 픽범위  ·  F5 리셋", 18,
		Color(UiStyle.GREEN, 0.9), 2))

	_body = UiStyle.label("", 19, UiStyle.WHITE)
	box.add_child(_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_mini("강제 제거", func() -> void: force_remove_requested.emit()))
	row.add_child(_mini("코어 개방", func() -> void: open_core_requested.emit()))
	row.add_child(_mini("리셋", func() -> void: reset_requested.emit()))
	row.add_child(_mini("픽 범위", func() -> void: DebugFlags.toggle_collision()))

	DebugFlags.changed.connect(_on_flags_changed)
	visible = DebugFlags.show_overlay

func _mini(text: String, cb: Callable) -> Button:
	var b := UiStyle.button(text, 20, UiStyle.WHITE, Color(UiStyle.GREEN, 0.7))
	b.custom_minimum_size = Vector2(0, 60)
	b.pressed.connect(cb)
	return b

func _on_flags_changed() -> void:
	visible = DebugFlags.show_overlay
	_apply_pick_view()

func _apply_pick_view() -> void:
	if rig == null:
		return
	for p in rig.all_parts():
		if engine != null and engine.is_removed(p.def.id):
			continue
		if DebugFlags.show_collision:
			p.set_outline(UiStyle.GREEN, 0.5)
		else:
			p.set_outline(UiStyle.GREEN, 0.0)

func set_selected(id: String) -> void:
	_selected = id

func _process(delta: float) -> void:
	if not visible or engine == null:
		return
	_accum += delta
	if _accum < 0.2:
		return
	_accum = 0.0
	_body.text = _compose()

func _compose() -> String:
	var lines: Array[String] = []
	lines.append("FPS %d   DRAW %d   남은 부품 %d/%d   MOVES %d" % [
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		engine.remaining(), engine.total(), engine.moves,
	])
	if not _selected.is_empty():
		lines.append("선택: %s" % _selected)
	lines.append("")
	for id in engine.stage.part_order:
		var d: PartDef = engine.stage.parts[id]
		var mark := "·"
		var note := ""
		if engine.is_removed(id):
			mark = "x"
			note = "REMOVED"
		elif engine.is_free(id):
			mark = "o"
			note = "FREE"
		else:
			mark = "-"
			note = "blocked_by " + ", ".join(engine.blockers_of(id))
		var cursor := ">" if id == _selected else " "
		lines.append("%s %s %-12s %-7s %s" % [cursor, mark, id, d.interaction_name(), note])
	return "\n".join(lines)
