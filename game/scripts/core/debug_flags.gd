extends Node
## 개발 빌드 전용 스위치 (기획서 20번). 릴리스에서는 available 이 false 라
## 오버레이 노드가 아예 트리에 붙지 않는다.

signal changed

var available: bool = OS.is_debug_build()
var show_overlay: bool = false
var show_collision: bool = false

func toggle_overlay() -> void:
	if not available:
		return
	show_overlay = not show_overlay
	changed.emit()

func toggle_collision() -> void:
	if not available:
		return
	show_collision = not show_collision
	changed.emit()
