extends Node3D
## 메인 화면. 시안 3 에서 재화·우편함·미션을 뺀 것 —
## 아직 없는 기능의 자리를 미리 만들어 두지 않는다 (기획서 15번).
##
## 배경에 실제 장치가 천천히 돈다. 이 게임이 무엇에 관한 것인지
## 문장보다 저게 먼저 말한다.

const HERO_MODEL := "res://assets/models/device_001.glb"
const SPIN_SPEED := 9.0        ## 초당 도

@onready var _display: Node3D = $Display

var _hero: Node3D
var _settings: SettingsPanel

func _ready() -> void:
	_spawn_hero()
	_build_ui()

func _process(delta: float) -> void:
	if _hero != null:
		_hero.rotate_y(deg_to_rad(SPIN_SPEED) * delta)

func _spawn_hero() -> void:
	if not ResourceLoader.exists(HERO_MODEL):
		push_warning("[MainMenu] 히어로 모델이 없다: %s" % HERO_MODEL)
		return
	var packed: PackedScene = load(HERO_MODEL)
	_hero = packed.instantiate()
	_display.add_child(_hero)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	SafeArea.bind(root)

	# ── 워드마크 ──────────────────────────────────────────────────
	var title := UiStyle.label("ZERO", 132, UiStyle.WHITE, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(title, 0, 0, 1, 0, 0, 150, 0, 330)
	root.add_child(title)

	var sub := UiStyle.label("DISASSEMBLE TO DISCOVER", 26, Color(UiStyle.CYAN, 0.8), 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(sub, 0, 0, 1, 0, 0, 316, 0, 356)
	root.add_child(sub)

	# ── 진행 요약 ─────────────────────────────────────────────────
	var chip := UiStyle.chip(_progress_text(), 24, UiStyle.WHITE, Color(UiStyle.DIM, 0.55))
	UiStyle.anchor(chip, 0.5, 1, 0.5, 1, -260, -524, 260, -462)
	(chip.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(chip)

	# ── 버튼 ──────────────────────────────────────────────────────
	var start := UiStyle.button(_start_label(), 44, UiStyle.AMBER, UiStyle.AMBER)
	UiStyle.anchor(start, 0, 1, 1, 1, 120, -430, -120, -290)
	start.pressed.connect(_on_start)
	root.add_child(start)

	var chapters := UiStyle.button("챕터", 32, UiStyle.WHITE, Color(UiStyle.CYAN, 0.7))
	UiStyle.anchor(chapters, 0, 1, 1, 1, 120, -262, -120, -152)
	chapters.pressed.connect(func() -> void: Session.goto_select())
	root.add_child(chapters)

	var gear := UiStyle.button("⚙", 40, UiStyle.WHITE, Color(UiStyle.DIM, 0.55))
	UiStyle.anchor(gear, 1, 0, 1, 0, -132, 44, -40, 136)
	gear.pressed.connect(func() -> void: _settings.open_panel())
	root.add_child(gear)

	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	# 진행을 지우면 "이어서/시작" 과 진행 칩이 거짓말이 된다. 화면을 다시 만든다.
	_settings.progress_cleared.connect(func() -> void:
		await get_tree().create_timer(0.6).timeout
		Session.goto_menu())
	layer.add_child(_settings)

	var version := UiStyle.label("v%s  ·  VERTICAL SLICE" % _version(), 18,
		Color(UiStyle.DIM, 0.7), 3)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.anchor(version, 0, 1, 1, 1, 0, -96, 0, -56)
	root.add_child(version)

## 캡처용.
func debug_open_settings() -> void:
	if _settings != null:
		_settings.open_panel()

## 안드로이드 뒤로 가기. 메인에서는 설정을 닫고, 없으면 앱을 끈다
## (project.godot 의 quit_on_go_back 을 꺼 뒀으므로 직접 끊어야 한다).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _settings != null and _settings.visible:
		_settings.close_panel()
		return
	get_tree().quit()

func _on_start() -> void:
	var target := Session.continue_target()
	if target.is_empty():
		push_error("[MainMenu] 플레이할 스테이지가 없다")
		return
	Sfx.play("snap", -6.0)
	Session.play(target)

func _start_label() -> String:
	for c in Session.catalog.chapters:
		for id in Session.stage_ids_of(c):
			if not id.is_empty() and Progress.is_cleared(id):
				return "이어서"
	return "시작"

func _progress_text() -> String:
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
	return "STAGE  %d / %d      ★  %d / %d" % [cleared, total, stars, total * 3]

func _version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	if v is String and not (v as String).is_empty():
		return v
	return "0.1.0"
