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
signal next_pressed()
signal replay_pressed()
signal select_pressed()
signal paused()
signal retry_pressed()
signal resumed()


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
var _stars: HBoxContainer
var _clear_actions: HBoxContainer
var _next_button: Button
var _bottom_bar: HBoxContainer
var _busy: bool = false
var _pause_layer: Control
var _settings: SettingsPanel
var _timer_label: Label
var _timer_chip: PanelContainer
var _mode_label: Label
var _fail_layer: Control
var _fail_title: Label
var _fail_sub: Label
var _vignette: DangerVignette
var _strikes: HBoxContainer
var _flash: ColorRect
var _bar: InstabilityBar
var _undo_left: int = 0
var _hint_left: int = 0
var _part_label_tween: Tween

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 안드로이드는 전체 화면이다. 상단 카메라 구멍 아래로 UI 가 들어가지 않게.
	SafeArea.bind(_root)

	_build_top()
	_build_ring()
	_build_tray()
	_build_bottom()
	# 화면 전체를 덮는 것들은 안전 영역 안이 아니라 **화면 끝까지** 가야 한다.
	# _root 에 붙이면 노치 밑으로 3D 가 그대로 비친다.
	_vignette = DangerVignette.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_build_clear_overlay()
	_build_fail()
	_build_pause()

# --- 상단 ---------------------------------------------------------------

func _build_top() -> void:
	# 게임 중에는 나가는 길이 항상 보여야 한다. 워드마크보다 이게 먼저다.
	var pause := UiStyle.button("←", 40, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	UiStyle.anchor(pause, 0, 0, 0, 0, 40, 40, 132, 132)
	pause.pressed.connect(open_pause)
	_root.add_child(pause)

	var wordmark := UiStyle.label("ZERO", 34, Color(UiStyle.WHITE, 0.85), 9)
	UiStyle.anchor(wordmark, 0, 0, 0, 0, 152, 62, 152 + 190, 62 + 56)
	_root.add_child(wordmark)

	var stage_chip := UiStyle.chip("STAGE 01", 28, UiStyle.WHITE, Color(UiStyle.CYAN, 0.55))
	UiStyle.anchor(stage_chip, 0.5, 0, 0.5, 0, -118, 44, 118, 112)
	_root.add_child(stage_chip)
	_stage_label = stage_chip.get_child(0)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 12)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.anchor(_dots, 0.5, 0, 0.5, 0, -220, 126, 220, 150)
	_root.add_child(_dots)

	_timer_chip = UiStyle.chip("00:00", 28, UiStyle.DANGER, Color(UiStyle.DANGER, 0.7))
	UiStyle.anchor(_timer_chip, 1, 0, 1, 0, -250, 48, -46, 112)
	_timer_chip.visible = false
	_root.add_child(_timer_chip)
	_timer_label = _timer_chip.get_child(0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_mode_label = UiStyle.label("", 18, UiStyle.DANGER, 6)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiStyle.anchor(_mode_label, 1, 0, 1, 0, -250, 122, -50, 152)
	_root.add_child(_mode_label)

	var moves_chip := UiStyle.chip("MOVES  0", 24, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	UiStyle.anchor(moves_chip, 1, 0, 1, 0, -250, 48, -46, 110)
	_root.add_child(moves_chip)
	_moves_label = moves_chip.get_child(0)
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_bar = InstabilityBar.new()
	UiStyle.anchor(_bar, 0, 0, 1, 0, 150, 168, -260, 216)
	_root.add_child(_bar)

	# 남은 경고. 죽는 것이 예고돼야 한다 — 모르고 죽으면 억울하다.
	_strikes = HBoxContainer.new()
	_strikes.add_theme_constant_override("separation", 10)
	_strikes.alignment = BoxContainer.ALIGNMENT_END
	_strikes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.anchor(_strikes, 1, 0, 1, 0, -250, 172, -150, 212)
	_root.add_child(_strikes)

	# 지금 만지고 있는 부품 이름. 짧게 떴다 사라지는 자막에 가깝다.
	_part_label = UiStyle.label("", 30, Color(UiStyle.CYAN, 0.0), 3)
	_part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(_part_label, 0, 0, 1, 0, 0, 232, 0, 280)
	_root.add_child(_part_label)

func _build_ring() -> void:
	ring = ProgressRing.new()
	UiStyle.anchor(ring, 0.5, 0.5, 0.5, 0.5, -95, -10, 95, 180)
	_root.add_child(ring)

func _build_tray() -> void:
	var caption := UiStyle.label("RECOVERED PARTS", 18, Color(UiStyle.DIM, 0.85), 5)
	UiStyle.anchor(caption, 0, 1, 0, 1, 52, -608, 452, -572)
	_root.add_child(caption)

	tray = PartTray.new()
	tray.name = "Tray"
	UiStyle.anchor(tray, 0, 1, 1, 1, 40, -564, -40, -204)
	_root.add_child(tray)

func _build_bottom() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 22)
	UiStyle.anchor(bar, 0, 1, 1, 1, 46, -176, -46, -50)
	_root.add_child(bar)
	_bottom_bar = bar

	_undo = UiStyle.button("되돌리기", 28, UiStyle.WHITE, UiStyle.CYAN)
	_hint = UiStyle.button("힌트", 28, UiStyle.AMBER, UiStyle.AMBER)
	var reset := UiStyle.button("다시", 30, Color(UiStyle.DIM, 0.95), Color(UiStyle.DIM, 0.6))
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	_hint.pressed.connect(func() -> void: hint_pressed.emit())
	reset.pressed.connect(func() -> void: reset_pressed.emit())
	for b: Button in [_undo, _hint, reset]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(b)

# --- 일시정지 ---------------------------------------------------------

func _build_pause() -> void:
	_pause_layer = Control.new()
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.visible = false
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(UiStyle.NAVY, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 뒤쪽 3D 조작이 새지 않게 여기서 입력을 먹는다.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)

	var title := UiStyle.label("일시정지", 56, UiStyle.WHITE, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(title, 0, 0.30, 1, 0.30, 0, 0, 0, 80)
	_pause_layer.add_child(title)

	var note := UiStyle.label("진행은 이 판을 나가면 사라진다", 20,
		Color(UiStyle.DIM, 0.9), 2)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(note, 0, 0.30, 1, 0.30, 0, 92, 0, 132)
	_pause_layer.add_child(note)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	UiStyle.anchor(box, 0, 0.40, 1, 0.40, 110, 0, -110, 600)
	_pause_layer.add_child(box)

	var resume := UiStyle.button("계속하기", 34, UiStyle.AMBER, UiStyle.AMBER)
	resume.custom_minimum_size = Vector2(0, 124)
	resume.pressed.connect(close_pause)
	box.add_child(resume)

	var again := UiStyle.button("처음부터", 32, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	again.custom_minimum_size = Vector2(0, 124)
	again.pressed.connect(func() -> void:
		close_pause()
		replay_pressed.emit())
	box.add_child(again)

	var opts := UiStyle.button("설정", 32, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	opts.custom_minimum_size = Vector2(0, 124)
	opts.pressed.connect(func() -> void: _settings.open_panel())
	box.add_child(opts)

	var out := UiStyle.button("스테이지 선택", 32, UiStyle.WHITE, Color(UiStyle.CYAN, 0.6))
	out.custom_minimum_size = Vector2(0, 124)
	out.pressed.connect(func() -> void:
		close_pause()
		select_pressed.emit())
	box.add_child(out)

	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	add_child(_settings)

## 연출이 진행 중일 때는 일시정지를 막는다.
## 코어 안정화 1.1초 사이에 나가면 다 푼 판이 기록되지 않고 날아간다.
func set_busy(on: bool) -> void:
	_busy = on

func open_pause() -> void:
	if _pause_layer == null or _pause_layer.visible or _clear_layer.visible or _busy:
		return
	_pause_layer.visible = true
	Sfx.play("click", -8.0)
	paused.emit()

func close_pause() -> void:
	if _pause_layer == null or not _pause_layer.visible:
		return
	_pause_layer.visible = false
	Sfx.play("click", -10.0)
	resumed.emit()

func is_paused() -> bool:
	return _pause_layer != null and _pause_layer.visible

func is_settings_open() -> bool:
	return _settings != null and _settings.visible

## 뒤로 가기 한 번에 한 겹씩 닫는다. 닫을 게 있었으면 true.
func close_topmost() -> bool:
	if is_settings_open():
		_settings.close_panel()
		return true
	if is_paused():
		close_pause()
		return true
	return false

# --- 성공 연출 ----------------------------------------------------------

func _build_clear_overlay() -> void:
	_clear_layer = Control.new()
	_clear_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clear_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_layer.visible = false
	add_child(_clear_layer)
	SafeArea.bind(_clear_layer)

	_dim = ColorRect.new()
	_dim.color = Color(UiStyle.NAVY, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_layer.add_child(_dim)

	_stable_label = UiStyle.label("SYSTEM STABLE", 46, Color(UiStyle.GREEN, 0.0), 14)
	_stable_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(_stable_label, 0, 0.37, 1, 0.37, 0, 0, 0, 66)
	_clear_layer.add_child(_stable_label)

	_clear_box = VBoxContainer.new()
	_clear_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_clear_box.add_theme_constant_override("separation", 14)
	_clear_box.modulate = Color(1, 1, 1, 0)
	_clear_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.anchor(_clear_box, 0, 0.43, 1, 0.43, 0, 0, 0, 240)
	_clear_layer.add_child(_clear_box)

	var title := UiStyle.label("STAGE CLEAR", 84, UiStyle.WHITE, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_box.add_child(title)

	var sub := UiStyle.label("MISSION SUCCESS", 24, Color(UiStyle.CYAN, 0.9), 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clear_box.add_child(sub)

	_stars = HBoxContainer.new()
	_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars.add_theme_constant_override("separation", 18)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_box.add_child(_stars)
	for i in 3:
		var star := UiStyle.label("★", 64, Color(UiStyle.DIM, 0.35))
		_stars.add_child(star)

	_clear_actions = HBoxContainer.new()
	_clear_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_clear_actions.add_theme_constant_override("separation", 20)
	_clear_actions.modulate = Color(1, 1, 1, 0)
	# modulate 는 입력을 막지 않는다. 안 보이는 동안 눌려서 별이 뜨기도 전에
	# 다음 판으로 넘어가는 일이 있었다.
	_clear_actions.visible = false
	_clear_layer.add_child(_clear_actions)
	UiStyle.anchor(_clear_actions, 0, 1, 1, 1, 46, -176, -46, -50)

	var again := UiStyle.button("다시", 30, UiStyle.WHITE, Color(UiStyle.DIM, 0.7))
	again.custom_minimum_size = Vector2(0, 118)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void: replay_pressed.emit())
	_clear_actions.add_child(again)

	var select := UiStyle.button("스테이지", 30, UiStyle.WHITE, Color(UiStyle.DIM, 0.7))
	select.custom_minimum_size = Vector2(0, 118)
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.pressed.connect(func() -> void: select_pressed.emit())
	_clear_actions.add_child(select)

	_next_button = UiStyle.button("다음 →", 32, UiStyle.AMBER, UiStyle.AMBER)
	_next_button.custom_minimum_size = Vector2(0, 118)
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(func() -> void: next_pressed.emit())
	_clear_actions.add_child(_next_button)

## 코어가 잡히고 나서 호출. 연출 순서는 기획서 12번 그대로다.
func play_clear_sequence(moves: int, par: int, stars: int, has_next: bool) -> void:
	_clear_layer.visible = true
	# 게임 중 버튼과 클리어 버튼이 같은 자리를 쓴다. 게임 쪽을 접는다.
	if _bottom_bar != null:
		_bottom_bar.visible = false
	_next_button.disabled = not has_next
	_next_button.text = "다음 →" if has_next else "마지막"
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.66, 0.8)
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
	# 별은 하나씩 떨어뜨린다. 한꺼번에 켜면 몇 개인지 안 읽힌다.
	for i in 3:
		tw.tween_interval(0.16)
		tw.tween_callback(_light_star.bind(i, i < stars))
	tw.tween_callback(func() -> void: _clear_actions.visible = true)
	tw.tween_property(_clear_actions, "modulate:a", 1.0, 0.35)

func _light_star(index: int, lit: bool) -> void:
	if index >= _stars.get_child_count():
		return
	var star: Label = _stars.get_child(index)
	star.add_theme_color_override("font_color",
		UiStyle.AMBER if lit else Color(UiStyle.DIM, 0.3))
	if not lit:
		return
	Sfx.play_varied("click", -6.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	star.pivot_offset = star.size * 0.5
	star.scale = Vector2(1.8, 1.8)
	tw.tween_property(star, "scale", Vector2.ONE, 0.28)

func hide_clear() -> void:
	_clear_layer.visible = false
	if _bottom_bar != null:
		_bottom_bar.visible = true
	_dim.color = Color(UiStyle.NAVY, 0.0)
	_stable_label.add_theme_color_override("font_color", Color(UiStyle.GREEN, 0.0))
	_clear_box.modulate = Color(1, 1, 1, 0)
	_clear_actions.modulate = Color(1, 1, 1, 0)
	_clear_actions.visible = false

# --- 실패 (위험/보스 모드) ---------------------------------------------

func _build_fail() -> void:
	_fail_layer = Control.new()
	_fail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fail_layer.visible = false
	add_child(_fail_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.02, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_fail_layer.add_child(dim)

	_fail_title = UiStyle.label("CONTAINMENT FAILED", 50, UiStyle.DANGER, 10)
	_fail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(_fail_title, 0, 0.36, 1, 0.36, 0, 0, 0, 80)
	_fail_layer.add_child(_fail_title)

	_fail_sub = UiStyle.label("", 26, Color(UiStyle.WHITE, 0.85), 4)
	_fail_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(_fail_sub, 0, 0.36, 1, 0.36, 0, 92, 0, 136)
	_fail_layer.add_child(_fail_sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	UiStyle.anchor(row, 0, 1, 1, 1, 60, -176, -60, -50)
	_fail_layer.add_child(row)

	var again := UiStyle.button("다시", 34, UiStyle.AMBER, UiStyle.AMBER)
	again.custom_minimum_size = Vector2(0, 118)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(again)

	var out := UiStyle.button("스테이지", 32, UiStyle.WHITE, Color(UiStyle.DIM, 0.6))
	out.custom_minimum_size = Vector2(0, 118)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out.pressed.connect(func() -> void: select_pressed.emit())
	row.add_child(out)

func show_fail(title: String, reason: String) -> void:
	if _fail_layer == null or _fail_layer.visible:
		return
	if _bottom_bar != null:
		_bottom_bar.visible = false
	_fail_title.text = title
	_fail_sub.text = reason
	_fail_layer.visible = true
	if _vignette != null:
		_vignette.intensity = 0.0
	Sfx.play("overload", 0.0)
	Haptics.bump()

## 폭발 섬광. 실패 화면보다 이게 먼저 온다.
func flash_white(strength: float = 0.9) -> void:
	if _flash == null:
		return
	_flash.color = Color(1, 0.86, 0.72, strength)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.55)

## 남은 경고 표시를 다시 그린다.
func set_strikes(left: int, total: int) -> void:
	if _strikes == null:
		return
	for c in _strikes.get_children():
		c.queue_free()
	for i in total:
		var pip := UiStyle.label("▲", 24,
			UiStyle.DANGER if i < left else Color(UiStyle.DIM, 0.28))
		_strikes.add_child(pip)

func set_danger_level(v: float) -> void:
	if _vignette != null:
		_vignette.intensity = v

func is_failed() -> bool:
	return _fail_layer != null and _fail_layer.visible

# --- 갱신 ---------------------------------------------------------------

func setup_stage(stage: StageDef) -> void:
	_stage_label.text = "STAGE %02d" % stage.index
	# 제한 시간이 있으면 MOVES 를 접고 그 자리에 시계를 띄운다.
	# 위험 모드에서 플레이어가 봐야 할 숫자는 남은 시간이다.
	var timed := stage.is_timed()
	_timer_chip.visible = timed
	_moves_label.get_parent().visible = not timed
	_mode_label.text = stage.mode_name() if stage.mode != StageDef.Mode.NORMAL else ""
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
		_undo.disabled = not on or _undo_left <= 0

## 도구는 개수가 정해져 있다 (시안 기준). 무제한이면 고민할 이유가 없다.
func set_tools(undo_left: int, hint_left: int, undo_available: bool) -> void:
	_undo_left = undo_left
	_hint_left = hint_left
	if _undo != null:
		_undo.text = "되돌리기 %d" % undo_left
		_undo.disabled = undo_left <= 0 or not undo_available
	if _hint != null:
		_hint.text = "힌트 %d" % hint_left
		_hint.disabled = hint_left <= 0

func set_time_left(seconds: float, danger: bool) -> void:
	if _timer_label == null or not _timer_chip.visible:
		return
	var s: int = int(ceilf(maxf(0.0, seconds)))
	_timer_label.text = "%02d:%02d" % [s / 60, s % 60]
	var col: Color = UiStyle.DANGER if danger else UiStyle.WHITE
	_timer_label.add_theme_color_override("font_color", col)

func set_instability(value: float, level: int) -> void:
	if _bar != null:
		_bar.set_state(value, level)
	# 게이지는 찾아가서 봐야 하지만 화면 테두리는 안 보려 해도 보인다.
	set_danger_level(maxf(0.0, (value - Instability.WARN_AT)
		/ maxf(1.0 - Instability.WARN_AT, 0.01)))

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
