class_name InstabilityBar
extends Control
## 장치가 얼마나 화가 났는지 보여 주는 막대.
##
## 숫자를 쓰지 않는다. 색과 길이와 떨림으로만 말한다 —
## 플레이어가 계기판을 읽는 게 아니라 장치를 느껴야 한다.

const TRACK_H := 12.0
const LABEL_H := 22.0

var value: float = 0.0
var level: int = Instability.Level.CALM

var _pulse: float = 0.0
var _shake: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(v: float, lv: int) -> void:
	var was := level
	value = clampf(v, 0.0, 1.0)
	level = lv
	if lv == Instability.Level.CRITICAL and was != lv:
		_shake = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if level == Instability.Level.CALM and value <= 0.001:
		return
	_pulse += delta * (2.2 + 6.0 * value)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
	queue_redraw()

func _tint() -> Color:
	match level:
		Instability.Level.CRITICAL:
			return UiStyle.DANGER
		Instability.Level.WARN:
			return UiStyle.AMBER
	return UiStyle.CYAN

func _draw() -> void:
	var w := size.x
	var top := LABEL_H
	var h := TRACK_H
	var jitter := 0.0
	if _shake > 0.0:
		jitter = sin(_pulse * 40.0) * 3.0 * _shake

	var tint := _tint()
	var font := UiStyle.font()
	if font != null:
		var caption := "INSTABILITY"
		if level == Instability.Level.CRITICAL:
			caption = "CRITICAL"
		elif level == Instability.Level.WARN:
			caption = "UNSTABLE"
		var alpha: float = 0.55 if level == Instability.Level.CALM else 0.95
		draw_string(font, Vector2(0, LABEL_H - 6), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(tint, alpha))

	# 트랙
	draw_rect(Rect2(0, top + jitter, w, h), Color(UiStyle.DIM, 0.18), true)

	# 눈금 두 개 — 어디서 뭔가 나빠지는지 미리 보여 준다
	for mark in [Instability.RELOCK_AT, 1.0]:
		draw_rect(Rect2(w * mark - 2.0, top - 3.0 + jitter, 2.0, h + 6.0),
			Color(UiStyle.DIM, 0.5), true)

	if value <= 0.001:
		return

	var glow: float = 1.0
	if level != Instability.Level.CALM:
		glow = 0.72 + 0.28 * sin(_pulse * 3.0)
	draw_rect(Rect2(0, top + jitter, w * value, h), Color(tint, glow), true)
