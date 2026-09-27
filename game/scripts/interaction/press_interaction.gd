class_name PressInteraction
extends PartInteraction
## 버튼이나 잠금 장치를 **길게 누른다** (기획서 3번 Press).
##
## 톡 누르면 끝나는 버튼은 손맛이 없다. 누르고 있는 동안 버튼이 서서히 들어가고
## 링이 차오른다. 끝까지 눌러야 잠긴다.
##
## 막혀 있으면 살짝 들어갔다 튕겨 나온다. 안 눌리는 버튼이라는 걸 손가락이 먼저 안다.

const CANCEL_SLOP := 90.0

var _held: float = 0.0
var _start_screen: Vector2
var _home: Vector3
var _sound_started: bool = false

func _on_begin() -> void:
	_held = 0.0
	_sound_started = false
	_home = part.home_transform.origin
	if not free:
		part.set_outline(Part.OUTLINE_BLOCKED, 0.45)
		_bounce()
		_reject(part.def.remove_direction)
		return
	part.set_outline(Part.OUTLINE_FREE, 0.4)

func set_start(screen_pos: Vector2) -> void:
	_start_screen = screen_pos

func update(screen_pos: Vector2) -> void:
	# 손가락이 많이 미끄러지면 누르기를 놓친 것으로 본다.
	if free and (screen_pos - _start_screen).length() > CANCEL_SLOP:
		_held = 0.0
		progress_changed.emit(0.0)

func tick(delta: float) -> void:
	if not free:
		return
	if not _sound_started:
		_sound_started = true
		if not part.def.sfx_engage.is_empty():
			Sfx.play(part.def.sfx_engage, -4.0)
	_held += delta
	var span: float = maxf(part.def.press_seconds, 0.05)
	var t: float = clampf(_held / span, 0.0, 1.0)
	progress_changed.emit(t)
	part.set_outline(Part.OUTLINE_FREE, 0.3 + 0.6 * t)

	# 누르는 동안 실제로 들어간다. 코어처럼 깊이가 없는 것은 대신 맥동한다.
	if part.def.press_depth > 0.0:
		part.position = _home + part.def.remove_direction * (part.def.press_depth * t)
	else:
		part.scale = Vector3.ONE * (1.0 + 0.05 * sin(_held * 26.0) * t)

	if t >= 1.0:
		part.scale = Vector3.ONE
		_complete()

## 안 눌리는 버튼: 조금 들어갔다 바로 나온다.
func _bounce() -> void:
	var dir: Vector3 = part.def.remove_direction * (part.def.press_depth * 0.35)
	var tw := part.create_tween()
	tw.tween_property(part, "position", _home + dir, 0.05)
	tw.tween_property(part, "position", _home, 0.09)

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.scale = Vector3.ONE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	progress_changed.emit(0.0)
	if free and part.def.press_depth > 0.0:
		part.settle_home(0.12)
