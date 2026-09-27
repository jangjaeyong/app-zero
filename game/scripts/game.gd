extends Node3D
## DEVICE_001 버티컬 슬라이스의 조립 지점.
## 규칙은 PuzzleEngine, 입력은 TouchRouter, 표현은 Part/Hud 가 맡는다.
## 여기서는 그것들을 잇고 "제거 → 트레이 → 다음 상태" 흐름만 진행시킨다.

const FALLBACK_STAGE := "res://resources/stages/stage_001.json"

@onready var _orbit: OrbitCamera = $OrbitCamera
@onready var _rig: DeviceRig = $DeviceRig

var stage: StageDef
var engine: PuzzleEngine
var router: TouchRouter
var hud: Hud
var overlay: DebugOverlay

var _ctx: InteractionContext
var _core: Part
var _core_stable: bool = false
var _core_phase: float = 0.0
var _clearing: bool = false
var _slot_of: Dictionary = {}          ## part id -> 트레이 칸

func _ready() -> void:
	stage = StageDef.load_from(_stage_path())
	if stage == null:
		push_error("[Game] 스테이지를 못 읽었다. 여기서 더 진행해도 의미 없다.")
		return

	_orbit.configure(stage.cam_yaw, stage.cam_pitch, stage.cam_distance,
		stage.cam_height, stage.cam_min, stage.cam_max)

	var missing := _rig.build(stage)
	if not missing.is_empty():
		push_error("[Game] 모델에 없는 부품: %s" % ", ".join(missing))

	engine = PuzzleEngine.new(stage)
	engine.part_resolved.connect(_on_part_resolved)
	engine.newly_freed.connect(_on_newly_freed)
	engine.stage_cleared.connect(_on_stage_cleared)

	_ctx = InteractionContext.new()
	_ctx.camera = _orbit.camera
	_ctx.rig = _rig
	_ctx.engine = engine

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup_stage(stage)
	hud.set_progress(0, 0)
	hud.set_undo_enabled(false)
	hud.undo_pressed.connect(_on_undo)
	hud.hint_pressed.connect(_on_hint)
	hud.reset_pressed.connect(_restart)
	hud.replay_pressed.connect(_restart)
	hud.next_pressed.connect(func() -> void: Session.play_next())
	hud.select_pressed.connect(func() -> void: Session.goto_select())

	router = TouchRouter.new()
	router.name = "TouchRouter"
	router.ctx = _ctx
	router.orbit = _orbit
	router.part_engaged.connect(_on_part_engaged)
	router.part_completed.connect(_on_part_completed)
	router.part_rejected.connect(_on_part_rejected)
	router.interaction_progress.connect(func(v: float) -> void: hud.ring.value = v)
	add_child(router)

	_core = _rig.get_part(_core_id())
	if _core != null:
		_core.set_emission(Color(1.0, 0.45, 0.08), 8.0)
		# 코어 등은 장치마다 코어가 있는 자리로 옮긴다.
		# 씬에 고정해 두면 장치가 바뀔 때마다 엉뚱한 데를 밝힌다.
		var lamp := get_node_or_null("CoreLight") as OmniLight3D
		if lamp != null:
			lamp.global_position = _core.global_position

	if DebugFlags.available:
		overlay = DebugOverlay.new()
		overlay.name = "DebugOverlay"
		overlay.engine = engine
		overlay.rig = _rig
		overlay.force_remove_requested.connect(_debug_force_remove)
		overlay.reset_requested.connect(_restart)
		overlay.open_core_requested.connect(_debug_open_core)
		add_child(overlay)

	# 시작할 때 지금 만질 수 있는 것들을 한 번 짚어준다. 튜토리얼 문구 없이.
	await get_tree().create_timer(0.7).timeout
	_pulse_free(Part.OUTLINE_FREE, 2)

## 어느 스테이지를 열 것인가.
## 보통은 Session 이 정한다. 캡처 하네스처럼 게임 씬을 바로 띄우는 경우를 위해
## --stage 인자와 기본값을 남겨 둔다.
func _stage_path() -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--stage" and i + 1 < args.size():
			Session.current_stage_path = args[i + 1]
			return args[i + 1]
	if not Session.current_stage_path.is_empty():
		return Session.current_stage_path
	Session.current_stage_path = FALLBACK_STAGE
	return FALLBACK_STAGE

func _core_id() -> String:
	for id in stage.part_order:
		if (stage.parts[id] as PartDef).is_core:
			return id
	return ""

func _process(delta: float) -> void:
	# 불안정한 코어는 계속 맥동한다. 마지막에 이게 멎는 게 보상이다.
	if _core != null and not _core_stable and _core.has_surface_material():
		_core_phase += delta
		var e: float = 6.5 + 3.0 * sin(_core_phase * 5.2) + 1.2 * sin(_core_phase * 13.7)
		_core.set_emission(Color(1.0, 0.45, 0.08), e)

# --- 조작 결과 ----------------------------------------------------------

func _on_part_engaged(part: Part) -> void:
	if overlay != null:
		overlay.set_selected(part.def.id)
	var blocked := not engine.is_free(part.def.id)
	hud.flash_part_name(part.def.label, UiStyle.DANGER if blocked else UiStyle.CYAN)

func _on_part_completed(part: Part) -> void:
	Sfx.play_varied(part.def.sfx_release, -3.0)
	Haptics.release()
	if part.def.is_core:
		_stabilize_core(part)
		return
	if part.def.leaves_device():
		_fly_to_tray(part)
	else:
		_settle_in_place(part)
	engine.mark_resolved(part.def.id)

## 막혔다. 말로 알리지 않는다 — 부품은 걸려서 되돌아가고,
## 막고 있는 놈이 붉게 점등한다 (기획서 4번).
func _on_part_rejected(_part: Part, blockers: PackedStringArray) -> void:
	Sfx.play_varied("clack", -4.0)
	Haptics.bump()
	for id in blockers:
		var b: Part = _rig.get_part(id)
		if b != null:
			b.flash_blocker()

func _on_part_resolved(id: String) -> void:
	hud.set_progress(engine.total() - engine.remaining(), engine.moves)
	hud.set_undo_enabled(not engine.history().is_empty())
	if overlay != null:
		overlay.set_selected("")

## 이번 제거로 새로 열린 부품을 짧게 점등. "안쪽에 또 뭐가 있네" 의 신호.
func _on_newly_freed(ids: PackedStringArray) -> void:
	await get_tree().create_timer(0.34).timeout
	for id in ids:
		var p: Part = _rig.get_part(id)
		if p != null and not engine.is_resolved(id):
			p.pulse(Part.OUTLINE_FREE, 2)
			Sfx.play("click", -14.0)

## 빠지지 않고 제자리에 남는 부품. 밀린 걸쇠, 눌린 버튼, 맞춰진 기어.
## 위치는 조작 쪽에서 이미 잡아 놨다. 여기서는 "됐다"는 신호만 준다.
func _settle_in_place(part: Part) -> void:
	if part.def.interaction == PartDef.Interaction.PRESS:
		var target: Vector3 = part.home_transform.origin \
			+ part.def.remove_direction * part.def.press_depth
		var tw := part.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(part, "position", target, 0.13)
		tw.tween_callback(func() -> void:
			if is_instance_valid(part):
				part.commit_home())
	part.pulse(UiStyle.GREEN, 1)

func _fly_to_tray(part: Part) -> void:
	var slot: int = _slot_of.size()
	_slot_of[part.def.id] = slot
	var out: Vector3 = part.def.remove_direction * (part.def.remove_distance + 0.28)
	var tw := part.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(part, "position", part.home_transform.origin + out, 0.26)
	tw.tween_property(part, "scale", Vector3.ONE * 0.45, 0.26)
	tw.chain().tween_callback(func() -> void: hud.tray.accept(part, slot))

# --- 코어 안정화 (기획서 12번) ------------------------------------------

func _stabilize_core(part: Part) -> void:
	if _clearing:
		return
	_clearing = true
	router.input_locked = true
	_core_stable = true

	var tw := create_tween()
	# 주황 → 시안. 회전이 잦아들고 빛이 가라앉는다.
	tw.tween_method(func(t: float) -> void:
			var col: Color = Color(1.0, 0.45, 0.08).lerp(Color(0.18, 0.86, 0.95), t)
			part.set_emission(col, lerpf(9.5, 4.0, t)),
		0.0, 1.0, 1.1)
	tw.parallel().tween_property(part, "scale", Vector3.ONE * 0.94, 1.1)
	tw.parallel().tween_method(_orbit.set_distance, _orbit.distance(),
			clampf(stage.cam_distance * 0.86, _orbit.min_distance, _orbit.max_distance), 1.2)
	tw.tween_callback(func() -> void: part.fade_outline(UiStyle.GREEN, 0.7, 0.4))
	tw.tween_callback(func() -> void: engine.mark_resolved(part.def.id))

func _on_stage_cleared() -> void:
	var stars := Progress.record_clear(stage.id, engine.moves, stage.par_moves)
	hud.play_clear_sequence(engine.moves, stage.par_moves, stars, Session.has_next())

# --- 버튼 ---------------------------------------------------------------

func _on_undo() -> void:
	if _clearing:
		return
	var id := engine.undo()
	if id.is_empty():
		return
	var part: Part = _rig.get_part(id)
	if part != null:
		if _slot_of.has(id):
			hud.tray.release(part, _rig.parts_root())
			_slot_of.erase(id)
		else:
			# 제자리에 남았던 부품은 원래 자리로 되돌린다.
			part.reset_to_origin()
		part.state = Part.State.IDLE
		part.pulse(Part.OUTLINE_HINT, 1)
	Sfx.play_varied("slide", -8.0)
	hud.set_progress(engine.total() - engine.remaining(), engine.moves)
	hud.set_undo_enabled(not engine.history().is_empty())

func _on_hint() -> void:
	if _clearing:
		return
	var id := engine.hint()
	if id.is_empty():
		return
	var part: Part = _rig.get_part(id)
	if part == null:
		return
	part.pulse(Part.OUTLINE_HINT, 3)
	_orbit.look_toward(part.global_position)
	hud.flash_part_name(part.def.label, UiStyle.AMBER)
	Sfx.play("click", -8.0)

func _pulse_free(color: Color, cycles: int) -> void:
	for id in engine.free_parts():
		var p: Part = _rig.get_part(id)
		if p != null:
			p.pulse(color, cycles)

func _restart() -> void:
	get_tree().reload_current_scene()

# --- 디버그 -------------------------------------------------------------

func _debug_force_remove() -> void:
	for id in stage.part_order:
		if not engine.is_resolved(id):
			var p: Part = _rig.get_part(id)
			if p != null and not p.def.is_core:
				_fly_to_tray(p)
			engine.mark_resolved(id)
			return

func _debug_open_core() -> void:
	for id in stage.part_order:
		if engine.is_resolved(id):
			continue
		var p: Part = _rig.get_part(id)
		if p == null:
			continue
		if p.def.is_core:
			_stabilize_core(p)
		else:
			_fly_to_tray(p)
			engine.mark_resolved(id)

## 캡처용: 카메라를 원하는 각도로 돌려놓는다.
func debug_spin(yaw_degrees: float) -> void:
	_orbit._target_yaw = yaw_degrees

func _unhandled_key_input(event: InputEvent) -> void:
	if not DebugFlags.available:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_F1:
			DebugFlags.toggle_overlay()
		KEY_F2:
			DebugFlags.toggle_collision()
		KEY_F5:
			_restart()
