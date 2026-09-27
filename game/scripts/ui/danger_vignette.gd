class_name DangerVignette
extends Control
## 위험할 때 화면 가장자리가 붉어진다.
##
## 막대만으로는 안 읽힌다는 지적을 받았다. 게이지는 눈으로 찾아가서 봐야 하지만
## 화면 테두리는 안 보려고 해도 보인다. 긴장은 여기서 온다.

const BANDS := 16

var intensity: float = 0.0:
	set(v):
		var c: float = clampf(v, 0.0, 1.0)
		if is_equal_approx(c, intensity):
			return
		intensity = c
		visible = intensity > 0.005
		queue_redraw()

var _phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(delta: float) -> void:
	if intensity <= 0.005:
		return
	# 셀수록 빨리 뛴다. 심장 박동처럼.
	_phase += delta * (1.6 + intensity * 4.0)
	queue_redraw()

func _draw() -> void:
	if intensity <= 0.005:
		return
	var pulse: float = 0.72 + 0.28 * sin(_phase)
	var depth: float = minf(size.x, size.y) * 0.34 * (0.45 + 0.55 * intensity)
	for i in BANDS:
		var t: float = float(i) / float(BANDS - 1)
		var inset: float = depth * t
		var alpha: float = (1.0 - t) * (1.0 - t) * 0.42 * intensity * pulse
		if alpha <= 0.002:
			continue
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			Color(UiStyle.DANGER, alpha), false, maxf(1.0, depth / BANDS) + 1.0)
