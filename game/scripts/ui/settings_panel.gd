class_name SettingsPanel
extends Control
## 설정 패널. 메인 화면의 톱니바퀴와 게임 중 일시정지, 두 곳에서 같은 것을 띄운다.
##
## 켜고 끄는 것만 둔다. 슬라이더는 폰에서 정확히 못 누른다.

signal closed()
signal progress_cleared()

var _confirm_reset: bool = false
var _reset_button: Button

func _ready() -> void:
	# 앵커만 잡으면 오프셋이 그대로 남아 크기가 0 이 된다.
	# 그러면 자식들이 좌상단에 뭉친다. 실제로 그랬다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.NAVY, 0.975)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner)
	SafeArea.bind(inner)

	var title := UiStyle.label("설정", 52, UiStyle.WHITE, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(title, 0, 0.16, 1, 0.16, 0, 0, 0, 76)
	inner.add_child(title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	UiStyle.anchor(box, 0, 0.30, 1, 0.30, 90, 0, -90, 480)
	inner.add_child(box)

	box.add_child(_toggle("소리", Settings.sound,
		func(on: bool) -> void: Settings.sound = on))
	box.add_child(_toggle("진동", Settings.haptics,
		func(on: bool) -> void: Settings.haptics = on))
	box.add_child(_toggle("화면 흔들림", Settings.screen_shake,
		func(on: bool) -> void: Settings.screen_shake = on))

	_reset_button = UiStyle.button("진행 초기화", 28,
		Color(UiStyle.DANGER, 0.95), Color(UiStyle.DANGER, 0.55))
	_reset_button.custom_minimum_size = Vector2(0, 112)
	_reset_button.pressed.connect(_on_reset)
	UiStyle.anchor(_reset_button, 0, 1, 1, 1, 90, -340, -90, -228)
	inner.add_child(_reset_button)

	var close := UiStyle.button("닫기", 32, UiStyle.WHITE, Color(UiStyle.CYAN, 0.6))
	UiStyle.anchor(close, 0, 1, 1, 1, 90, -190, -90, -70)
	close.pressed.connect(close_panel)
	inner.add_child(close)

## 켜짐/꺼짐이 글자로 바로 보이게. 스위치 그림보다 이게 확실하다.
func _toggle(label: String, initial: bool, on_change: Callable) -> Button:
	var b := UiStyle.button("", 30, UiStyle.WHITE, Color(UiStyle.CYAN, 0.55))
	b.custom_minimum_size = Vector2(0, 116)
	var state := {"on": initial}
	var paint := func() -> void:
		b.text = "%s        %s" % [label, "켜짐" if state["on"] else "꺼짐"]
		b.add_theme_color_override("font_color",
			UiStyle.WHITE if state["on"] else Color(UiStyle.DIM, 0.9))
	paint.call()
	b.pressed.connect(func() -> void:
		state["on"] = not state["on"]
		paint.call()
		on_change.call(state["on"])
		Sfx.play("click", -10.0))
	return b

## 되돌릴 수 없는 일은 한 번 더 묻는다.
func _on_reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_reset_button.text = "정말 지울까? 다시 누르면 지워진다"
		Sfx.play("clack", -8.0)
		return
	Progress.clear_all()
	_confirm_reset = false
	_reset_button.text = "지웠다"
	Sfx.play("relock", -6.0)
	progress_cleared.emit()

func open_panel() -> void:
	_confirm_reset = false
	if _reset_button != null:
		_reset_button.text = "진행 초기화"
	visible = true
	Sfx.play("click", -8.0)

func close_panel() -> void:
	visible = false
	Sfx.play("click", -10.0)
	closed.emit()
