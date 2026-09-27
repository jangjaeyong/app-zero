class_name RouteInteraction
extends PartInteraction
## 케이블이나 파이프를 **정해진 경로를 따라** 끌고 간다 (기획서 3번 Route).
##
## 목적지로 직행하면 안 된다. 경로를 벗어나면 걸린다.
##
## 판정을 화면 좌표에서 한다: 경로 점들을 화면에 투영해 꺾은선을 만들고,
## 손가락이 그 선 위 어디쯤인지를 잰다. 카메라가 어느 각도에 있든 똑같이
## 동작하고, 3D 평면 투영 같은 것을 안 해도 된다.

const DEVIATE_PX := 78.0        ## 이만큼 벗어나면 안 따라온다
const BLOCKED_PROGRESS := 0.09  ## 막혀 있을 때 갈 수 있는 비율
const FINISH_AT := 0.97

var _world: PackedVector3Array = PackedVector3Array()
var _screen: PackedVector2Array = PackedVector2Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()   ## 누적 화면 길이
var _total: float = 0.0
var _progress: float = 0.0
var _next_tick: float = 0.12
var _engaged: bool = false

func _on_begin() -> void:
	_progress = 0.0
	_next_tick = 0.12
	_engaged = false
	_build_path()
	part.set_outline(Part.OUTLINE_FREE if free else Part.OUTLINE_BLOCKED, 0.35)

func _build_path() -> void:
	_world.clear()
	_screen.clear()
	_lengths.clear()
	_total = 0.0
	var pts := part.params().route_points
	if pts.size() < 2:
		push_error("[Route] %s 의 route_points 가 2개 미만이다" % part.def.id)
		return
	var rig := part.get_parent() as Node3D
	if rig == null:
		return
	var to_world := rig.global_transform
	for p in pts:
		var w: Vector3 = to_world * p
		_world.append(w)
		_screen.append(ctx.camera.unproject_position(w))
	_lengths.append(0.0)
	for i in range(1, _screen.size()):
		_total += _screen[i].distance_to(_screen[i - 1])
		_lengths.append(_total)

func set_start(_screen_pos: Vector2) -> void:
	pass

func update(screen_pos: Vector2) -> void:
	if _total <= 0.0:
		return
	var hit := _closest_on_path(screen_pos)
	var t: float = hit["t"]
	var dist: float = hit["dist"]

	if dist > DEVIATE_PX:
		# 경로를 벗어났다. 부품은 따라오지 않는다 — 손가락만 떠난다.
		_reject(Vector3.ZERO)
		return

	var limit: float = 1.0 if free else BLOCKED_PROGRESS
	if not free and t > BLOCKED_PROGRESS * 0.8:
		_reject(Vector3.ZERO)
	_progress = clampf(t, 0.0, limit)
	_place(_progress)

	if not _engaged and _progress > 0.02:
		_engaged = true
		Sfx.play_varied(part.params().sfx_engage, -7.0)
	while free and _progress >= _next_tick:
		Sfx.play_varied(part.params().sfx_tick, -13.0)
		Haptics.tick()
		_next_tick += 0.12
	progress_changed.emit(_progress)

	if free and _progress >= FINISH_AT:
		_place(1.0)
		part.commit_home()
		progress_changed.emit(0.0)
		_complete()

## 화면 꺾은선 위에서 손가락과 가장 가까운 지점. t 는 0~1 진행도.
func _closest_on_path(p: Vector2) -> Dictionary:
	var best_d := INF
	var best_t := 0.0
	for i in range(1, _screen.size()):
		var a := _screen[i - 1]
		var b := _screen[i]
		var ab := b - a
		var len_sq := ab.length_squared()
		var u: float = 0.0 if len_sq < 0.001 else clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
		var proj := a + ab * u
		var d := p.distance_to(proj)
		if d < best_d:
			best_d = d
			best_t = (_lengths[i - 1] + ab.length() * u) / _total
	return {"t": best_t, "dist": best_d}

## 진행도에 해당하는 3D 위치로 부품을 옮긴다.
func _place(t: float) -> void:
	if _world.size() < 2:
		return
	var target: float = clampf(t, 0.0, 1.0) * _total
	for i in range(1, _world.size()):
		if target <= _lengths[i] or i == _world.size() - 1:
			var seg: float = _lengths[i] - _lengths[i - 1]
			var u: float = 0.0 if seg < 0.001 else (target - _lengths[i - 1]) / seg
			var w: Vector3 = _world[i - 1].lerp(_world[i], clampf(u, 0.0, 1.0))
			part.global_position = w
			return

func _on_finish() -> void:
	part.state = Part.State.IDLE
	part.set_outline(Part.OUTLINE_FREE, 0.0)
	progress_changed.emit(0.0)
	if not free:
		_reject(Vector3.ZERO)
	# 끝까지 못 갔으면 출발점으로 돌아간다. 중간에 매달린 케이블은 없다.
	part.settle_home(0.22)
