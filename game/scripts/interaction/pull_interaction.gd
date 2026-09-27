class_name PullInteraction
extends PartInteraction
## 손가락으로 당겨 뽑는다.
## 막혀 있으면 resist_distance 만큼만 움직이고 고무줄처럼 버틴다.

var _world_dir: Vector3
var _screen_dir: Vector2
var _px_per_unit: float = 400.0
var _start_screen: Vector2
var _home: Vector3
var _travel: float = 0.0
var _engaged_sfx: bool = false

func _on_begin() -> void:
	_world_dir = (part.get_parent().global_transform.basis * part.def.remove_direction).normalized()
	var axis := screen_axis_of(_world_dir)
	_screen_dir = axis["dir"]
	_px_per_unit = axis["px_per_unit"]
	_home = part.home_transform.origin
	_travel = 0.0
	_engaged_sfx = false
	part.set_outline(Part.OUTLINE_FREE if free else Part.OUTLINE_BLOCKED, 0.35)

func set_start(screen_pos: Vector2) -> void:
	_start_screen = screen_pos

func update(screen_pos: Vector2) -> void:
	var px: float = (screen_pos - _start_screen).dot(_screen_dir)
	var raw: float = px / maxf(_px_per_unit, 1.0)

	if free:
		_travel = clampf(raw, 0.0, part.def.remove_distance)
		if not _engaged_sfx and _travel > 0.012:
			_engaged_sfx = true
			Sfx.play_varied(part.def.sfx_engage, -6.0)
			Haptics.tick()
	else:
		# 걸림. 저항 한계에 가까워질수록 안 움직인다.
		var limit: float = part.def.resist_distance
		var eased: float = limit * (1.0 - exp(-maxf(raw, 0.0) / maxf(limit, 0.001)))
		_travel = clampf(eased, 0.0, limit)
		if raw > limit * 0.75:
			_reject(_world_dir)

	part.position = _home + part.def.remove_direction * _travel

	if free and _travel >= part.def.remove_distance - 0.0001:
		_complete()

func _on_finish() -> void:
	if free and _travel >= part.def.remove_distance * 0.72:
		# 충분히 당겼으면 놓아도 빠진다. 끝까지 끌게 강요하지 않는다.
		_complete()
		return
	part.state = Part.State.IDLE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	if not free:
		_reject(_world_dir)
	part.settle_home()
