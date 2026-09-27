class_name Hud
extends CanvasLayer
## 기획서 15번: UI 가 장치를 가리지 않는 게 최우선.
## 상단은 정보만, 하단은 버튼 세 개. 상점/이벤트/광고 자리는 만들지 않는다.
##
## 노드를 코드로 짓는다. 배치가 전부 계산값이라 .tscn 으로 두면
## 숫자가 두 군데로 갈라진다.

signal undo_pressed()
signal hint_pressed()
signal reset_pressed()


var tray: PartTray
var ring: ProgressRing

var _root: Control
var _stage_label: Label
var _moves_label: Label
var _dots: HBoxContainer
var _dot_nodes: Array[Panel] = []
var _part_label: Label
var _undo: Button
var _hint: Button
var _clear_layer: Control
var _dim: ColorRect
var _stable_label: Label
var _clear_box: VBoxContainer
var _part_label_tween: Tween

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_top()
	_build_ring()
	_build_tray()
	_build_bottom()
	_build_clear_overlay()

# --- 배치 헬퍼 -----------------------------------------------------------
#
# stretch aspect 가 "expand" 라 뷰포트는 1080x1920 에서 한쪽으로 늘어난다.
# 절대 좌표로 오른쪽 끝을 계산하면 기기마다 어긋난다. 전부 앵커로 붙인다.

static func _anchor(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob

# --- 상단 ---------------------------------------------------------------

func _build_top() -> void:
	var wordmark := VBoxContainer.new()
	wordmark.add_theme_constant_override("separation", 2)
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wordmark.add_child(UiStyle.label("ZERO", 52, UiStyle.WHITE, 12))
	wordmark.add_child(UiStyle.label("DISASSEMBLE TO DISCOVER", 16,
		Color(UiStyle.CYAN, 0.75), 5))
	_anchor(wordmark, 0, 0, 0, 0, 46, 42, 46 + 420, 42 + 100)
	_root.add_child(wordmark)

	var stage_chip := UiStyle.chip("STAGE 01", 28, UiStyle.WHITE, Color(UiStyle.CYAN, 0.55))
	_anchor(stage_chip, 0.5, 0, 0.5, 0, -118, 44, 118, 112)
	_root.add_child(stage_chip)
	_stage_label = stage_chip.get_child(0)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 12)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_dots, 0.5, 0, 0.5, 0, -220, 126, 220, 150)
	_root.add_child(_dots)

	var moves_chip := UiStyle.chip("MOVES  0", 24, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	_anchor(moves_chip, 1, 0, 1, 0, -250, 48, -46, 110)
	_root.add_child(moves_chip)
	_moves_label = moves_chip.get_child(0)
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 지금 만지고 있는 부품 이름. 짧게 떴다 사라지는 자막에 가깝다.
	_part_label = UiStyle.label("", 30, Color(UiStyle.CYAN, 0.0), 3)
	_part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_part_label, 0, 0, 1, 0, 0, 178, 0, 226)
	_root.add_child(_part_label)

func _build_ring() -> void:
	ring = ProgressRing.new()
	_anchor(ring, 0.5, 0.5, 0.5, 0.5, -95, -10, 95, 180)
	_root.add_child(ring)

func _build_tray() -> void:
	var caption := UiStyle.label("RECOVERED PARTS", 18, Color(UiStyle.DIM, 0.85), 5)
	_anchor(caption, 0, 1, 0, 1, 52, -608, 452, -572)
	_root.add_child(caption)

	tray = PartTray.new()
	tray.name = "Tray"
	_anchor(tray, 0, 1, 1, 1, 40, -564, -40, -204)
	_root.add_child(tray)

func _build_bottom() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 22)
	_anchor(bar, 0, 1, 1, 1, 46, -176, -46, -50)
	_root.add_child(bar)

	_undo = UiStyle.button("되돌리기", 30, UiStyle.WHITE, UiStyle.CYAN)
	_hint = UiStyle.button("힌트", 30, UiStyle.AMBER, UiStyle.AMBER)
	var reset := UiStyle.button("다시", 30, Color(UiStyle.DIM, 0.95), Color(UiStyle.DIM, 0.6))
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_hint.pressed.connect(func() -> void: hint_pressed.emit())
	reset.pressed.connect(func() -> void: reset_pressed.emit())
	for b: Button in [_undo, _hint, reset]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(b)

# --- 성공 연출 ----------------------------------------------------------

func _build_clear_overlay() -> void:
	_clear_layer = Control.new()
	_clear_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clear_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_layer.visible = false
	_root.add_child(_clear_layer)

	_dim = ColorRect.new()
	_dim.color = Color(UiStyle.NAVY, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_layer.add_child(_dim)

	_stable_label = UiStyle.label("SYSTEM STABLE", 46, Color(UiStyle.GREEN, 0.0), 14)
	_stable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_stable_label, 0, 0.37, 1, 0.37, 0, 0, 0, 66)
	_clear_layer.add_child(_stable_label)

	_clear_box = VBoxContainer.new()
	_clear_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_clear_box.add_theme_constant_override("separation", 14)
	_clear_box.modulate = Color(1, 1, 1, 0)
	_clear_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_clear_box, 0, 0.43, 1, 0.43, 0, 0, 0, 240)
	_clear_layer.add_child(_clear_box)

	var title := UiStyle.label("STAGE CLEAR", 84, UiStyle.WHITE, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_box.add_child(title)

	var sub := UiStyle.label("MISSION SUCCESS", 24, Color(UiStyle.CYAN, 0.9), 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_box.add_child(sub)

## 코어가 잡히고 나서 호출. 연출 순서는 기획서 12번 그대로다.
func play_clear_sequence(moves: int, par: int) -> void:
	_clear_layer.visible = true
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.45, 0.8)
	tw.tween_interval(0.9)                                   ## 약 1초 정적
	tw.tween_property(_stable_label, "theme_override_colors/font_color:a", 1.0, 0.45)
	tw.tween_callback(func() -> void: Sfx.play("stable", -2.0))
	tw.tween_interval(0.95)
	tw.tween_callback(func() -> void:
		var extra := ""
		if par > 0:
			extra = "  ·  %d / %d MOVES" % [moves, par]
		_clear_box.get_child(1).text = "MISSION SUCCESS" + extra)
	tw.parallel().tween_property(_clear_box, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: Haptics.success())

func hide_clear() -> void:
	_clear_layer.visible = false
	_dim.color = Color(UiStyle.NAVY, 0.0)
	_stable_label.add_theme_color_override("font_color", Color(UiStyle.GREEN, 0.0))
	_clear_box.modulate = Color(1, 1, 1, 0)

# --- 갱신 ---------------------------------------------------------------

func setup_stage(stage: StageDef) -> void:
	_stage_label.text = "STAGE %02d" % stage.index
	for c in _dots.get_children():
		c.queue_free()
	_dot_nodes.clear()
	var count: int = stage.part_order.size()
	for i in count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_dot(dot, false)
		_dots.add_child(dot)
		_dot_nodes.append(dot)

func _style_dot(dot: Panel, done: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(9)
	sb.bg_color = UiStyle.CYAN if done else Color(UiStyle.DIM, 0.28)
	sb.border_color = Color(UiStyle.CYAN, 0.9) if done else Color(UiStyle.DIM, 0.5)
	sb.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", sb)

func set_progress(removed: int, moves: int) -> void:
	_moves_label.text = "MOVES  %d" % moves
	for i in _dot_nodes.size():
		_style_dot(_dot_nodes[i], i < removed)

func set_undo_enabled(on: bool) -> void:
	if _undo != null:
		_undo.disabled = not on

## 부품 이름을 잠깐 띄웠다 지운다.
func flash_part_name(text: String, color: Color = UiStyle.CYAN) -> void:
	if _part_label_tween != null and _part_label_tween.is_valid():
		_part_label_tween.kill()
	_part_label.text = text
	_part_label.add_theme_color_override("font_color", Color(color, 0.0))
	_part_label_tween = create_tween()
	_part_label_tween.tween_property(_part_label, "theme_override_colors/font_color:a", 0.95, 0.12)
	_part_label_tween.tween_interval(0.85)
	_part_label_tween.tween_property(_part_label, "theme_override_colors/font_color:a", 0.0, 0.4)
