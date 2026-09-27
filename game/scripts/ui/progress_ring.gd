class_name ProgressRing
extends Control
## 돌리기/누르기 진행도. 숫자 대신 손가락 옆에서 차오르는 링 하나로 보여준다.

const THICKNESS := 9.0

var value: float = 0.0:
	set(v):
		var clamped: float = clampf(v, 0.0, 1.0)
		if is_equal_approx(clamped, value):
			return
		value = clamped
		visible = value > 0.001
		queue_redraw()

var ring_color: Color = UiStyle.CYAN

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5 - THICKNESS
	draw_arc(c, r, 0.0, TAU, 64, Color(UiStyle.DIM, 0.35), THICKNESS, true)
	if value > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * value, 64, ring_color, THICKNESS, true)
