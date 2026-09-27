class_name HoldInteraction
extends PartInteraction
## 코어 안정화. 길게 누르고 있어야 한다 — 마지막 한 수는 손이 기억하게 만든다.

const CANCEL_SLOP := 90.0

var _held: float = 0.0
var _start_screen: Vector2
var _hum_playing: bool = false

func _on_begin() -> void:
	_held = 0.0
	_hum_playing = false
	part.set_outline(Part.OUTLINE_FREE if free else Part.OUTLINE_BLOCKED, 0.4)
	if not free:
		_reject(Vector3.ZERO)

func set_start(screen_pos: Vector2) -> void:
	_start_screen = screen_pos

func update(screen_pos: Vector2) -> void:
	# 너무 많이 미끄러지면 누르기를 놓친 것으로 본다.
	if free and (screen_pos - _start_screen).length() > CANCEL_SLOP:
		_held = 0.0
		progress_changed.emit(0.0)

func tick(delta: float) -> void:
	if not free:
		return
	if not _hum_playing:
		_hum_playing = true
		Sfx.play(part.def.sfx_engage, -4.0)
	_held += delta
	var t: float = clampf(_held / maxf(part.def.hold_seconds, 0.01), 0.0, 1.0)
	progress_changed.emit(t)
	part.set_outline(Part.OUTLINE_FREE, 0.3 + 0.6 * t)
	var pulse: float = 1.0 + 0.05 * sin(_held * 26.0) * t
	part.scale = Vector3.ONE * pulse
	if t >= 1.0:
		part.scale = Vector3.ONE
		_complete()

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.scale = Vector3.ONE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	progress_changed.emit(0.0)
