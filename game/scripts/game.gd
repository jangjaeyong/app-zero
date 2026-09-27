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

const TOOL_UNDO := 3                   ## 시안 기준. 무제한이면 고민할 이유가 없다
const TOOL_HINT := 3
var _instability: Instability
var _fx: DeviceFx
var _time_left: float = 0.0
var _failed: bool = false
var _alarm_cooldown: float = 0.0
var _hint_guide: HintGuide
var _undo_left: int = TOOL_UNDO
var _hint_left: int = TOOL_HINT

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

	_instability = Instability.new()
	_instability.overload_limit = stage.overload_limit
	_instability.detonated.connect(_on_detonated)
	_instability.changed.connect(_on_instability)
	_instability.warned.connect(_on_warned)
	_instability.relocked.connect(_on_relocked)
	_instability.overloaded.connect(_on_overloaded)

	engine = PuzzleEngine.new(stage)
	engine.part_resolved.connect(_on_part_resolved)
	engine.newly_freed.connect(_on_newly_freed)
	engine.part_restored.connect(_on_part_restored)
	engine.group_reset.connect(_on_group_reset)
	engine.stage_cleared.connect(_on_stage_cleared)

	_ctx = InteractionContext.new()
	_ctx.camera = _orbit.camera
	_ctx.rig = _rig
	_ctx.engine = engine

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	_time_left = stage.time_limit
	hud.setup_stage(stage)
	if stage.is_timed():
		hud.set_time_left(_time_left, false)
	hud.set_progress(0, 0)
	hud.set_tools(_undo_left, _hint_left, false)
	hud.set_instability(0.0, Instability.Level.CALM)
	hud.set_strikes(_instability.strikes_left(), stage.overload_limit)
	hud.undo_pressed.connect(_on_undo)
	hud.hint_pressed.connect(_on_hint)
	hud.reset_pressed.connect(_restart)
	hud.replay_pressed.connect(_restart)
	hud.retry_pressed.connect(_restart)
	hud.next_pressed.connect(func() -> void: Session.play_next())
	hud.select_pressed.connect(func() -> void: Session.goto_select())
	# 일시정지 중에는 3D 조작이 먹으면 안 된다.
	hud.paused.connect(func() -> void: router.input_locked = true)
	hud.resumed.connect(func() -> void:
		router.input_locked = _clearing or _failed)

	router = TouchRouter.new()
	router.name = "TouchRouter"
	router.ctx = _ctx
	router.orbit = _orbit
	router.part_engaged.connect(_on_part_engaged)
	router.part_completed.connect(_on_part_completed)
	router.part_rejected.connect(_on_part_rejected)
	router.interaction_progress.connect(func(v: float) -> void: hud.ring.value = v)
	add_child(router)

	_fx = DeviceFx.new()
	_fx.name = "DeviceFx"
	add_child(_fx)

	_core = _rig.get_part(_core_id())
	if _core != null:
		_core.set_emission(Color(1.0, 0.45, 0.08), 8.0)
		# 코어 등은 장치마다 코어가 있는 자리로 옮긴다.
		# 씬에 고정해 두면 장치가 바뀔 때마다 엉뚱한 데를 밝힌다.
		var lamp := get_node_or_null("CoreLight") as OmniLight3D
		if lamp != null:
			lamp.global_position = _core.global_position
		_fx.follow(_core.global_position)

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
	_tick_clock(delta)
	if _instability != null and not _clearing:
		_instability.tick(delta)
		_tick_alarm(delta)

	# 불안정한 코어는 계속 맥동한다. 마지막에 이게 멎는 게 보상이다.
	# 장치가 화가 날수록 빨라지고 붉어진다 — 계기판보다 이게 먼저 읽힌다.
	if _core != null and not _core_stable and _core.has_surface_material():
		var heat: float = _instability.value if _instability != null else 0.0
		_core_phase += delta * (1.0 + heat * 2.4)
		var e: float = 6.5 + 3.0 * sin(_core_phase * 5.2) + 1.2 * sin(_core_phase * 13.7)
		var col := Color(1.0, 0.45, 0.08).lerp(Color(1.0, 0.16, 0.06), heat)
		_core.set_emission(col, e * (1.0 + heat * 0.5))

	if _fx != null and not _core_stable:
		_fx.set_heat(_instability.value if _instability != null else 0.0)

	# 위태로울 때는 장치 전체가 미세하게 떤다. (설정에서 끌 수 있다)
	if _instability != null and not _clearing and Settings.screen_shake:
		var shake: float = maxf(0.0, _instability.value - Instability.WARN_AT) * 0.014
		if shake > 0.0:
			_rig.position = Vector3(randf_range(-shake, shake), 0.0,
				randf_range(-shake, shake))
		elif _rig.position != Vector3.ZERO:
			_rig.position = Vector3.ZERO
	elif _rig.position != Vector3.ZERO:
		_rig.position = Vector3.ZERO

## 위태로울 때 경보가 반복해서 울린다. 조용하면 위험한 줄 모른다.
func _tick_alarm(delta: float) -> void:
	if _failed or _instability.level() != Instability.Level.CRITICAL:
		_alarm_cooldown = 0.0
		return
	_alarm_cooldown -= delta
	if _alarm_cooldown <= 0.0:
		_alarm_cooldown = 1.5
		Sfx.play("alarm", -14.0)

## 위험·보스 모드의 시계. 노멀에는 제한이 없다 (기획서 13·14번).
func _tick_clock(delta: float) -> void:
	if not stage.is_timed() or _clearing or _failed:
		return
	if hud == null or hud.is_paused():
		return
	_time_left = maxf(0.0, _time_left - delta)
	hud.set_time_left(_time_left, _time_left <= 20.0)
	if _time_left <= 0.0:
		_fail()

func _fail(title: String = "CONTAINMENT FAILED",
		reason: String = "시간이 다 됐다") -> void:
	if _failed:
		return
	_failed = true
	router.input_locked = true
	if _fx != null:
		_fx.burst()
	hud.show_fail(title, reason)

# --- 조작 결과 ----------------------------------------------------------

func _on_part_engaged(part: Part) -> void:
	if overlay != null:
		overlay.set_selected(part.def.id)
	var blocked := not engine.is_free(part.def.id)
	hud.flash_part_name(part.def.label, UiStyle.DANGER if blocked else UiStyle.CYAN)

func _on_part_completed(part: Part) -> void:
	Sfx.play_varied(part.def.sfx_release, -3.0)
	Haptics.release()
	# 여러 단계 부품은 아직 끝난 게 아니다. 다음 단계로만 넘어간다.
	if part.advance_step():
		Sfx.play_varied("lock_release", -8.0)
		Haptics.tick()
		part.pulse(Part.OUTLINE_FREE, 1)
		hud.flash_part_name("%s  %d / %d" % [part.def.label,
			part.step_index + 1, part.def.step_count()], UiStyle.CYAN)
		return

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
func _on_part_rejected(part: Part, blockers: PackedStringArray) -> void:
	Sfx.play_varied("clack", -4.0)
	Haptics.bump()
	if _instability != null:
		_instability.fail(part.def.id)
	if stage.is_timed() and not _failed:
		_time_left = maxf(0.0, _time_left - stage.time_penalty)
		hud.set_time_left(_time_left, true)
		hud.flash_part_name("-%d초" % int(stage.time_penalty), UiStyle.DANGER)
		if _time_left <= 0.0:
			_fail()
	for id in blockers:
		var b: Part = _rig.get_part(id)
		if b != null:
			b.flash_blocker()

func _on_part_resolved(id: String) -> void:
	if _instability != null:
		_instability.resolve()
	hud.set_progress(engine.total() - engine.remaining(), engine.moves)
	hud.set_tools(_undo_left, _hint_left, not engine.history().is_empty())
	if overlay != null:
		overlay.set_selected("")

## 이번 제거로 새로 열린 부품을 짧게 점등. "안쪽에 또 뭐가 있네" 의 신호.
func _on_newly_freed(ids: PackedStringArray) -> void:
	await get_tree().create_timer(0.34).timeout
	var shown_groups: Dictionary = {}
	for id in ids:
		var p: Part = _rig.get_part(id)
		if p == null or engine.is_resolved(id):
			continue
		var group := (stage.parts[id] as PartDef).sequence_group
		if not group.is_empty():
			# 순서를 외우라고만 하면 불친절하다. 열리는 순간 한 번 보여 준다.
			if not shown_groups.has(group):
				shown_groups[group] = true
				_demo_sequence(group)
			continue
		p.pulse(Part.OUTLINE_FREE, 2, true)
		Sfx.play("click", -14.0)

## 순서 시범. 그룹 구성원을 차례로 한 번 점등한다.
func _demo_sequence(group: String) -> void:
	hud.flash_part_name("순서를 기억해라", UiStyle.AMBER)
	for id in engine.members_of(group):
		var p: Part = _rig.get_part(id)
		if p == null:
			continue
		p.pulse(Part.OUTLINE_HINT, 1, true)
		Sfx.play_varied("ratchet", -8.0)
		await get_tree().create_timer(0.42).timeout

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
	if _fx != null:
		_fx.set_heat(0.0)
		_fx.stop_steam()

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
	var penalty: int = _instability.overloads if _instability != null else 0
	var stars := Progress.record_clear(stage.id, engine.moves, stage.par_moves, penalty)
	hud.play_clear_sequence(engine.moves, stage.par_moves, stars, Session.has_next())

## 엔진이 어떤 이유로든 해결을 취소했을 때 (순서 오류, 벌칙, 되돌리기).
## 여기서는 순서 그룹만 챙긴다 — 나머지는 각자 부르는 쪽에서 처리한다.
func _on_part_restored(id: String) -> void:
	var def: PartDef = stage.parts.get(id)
	if def == null or def.sequence_group.is_empty():
		return
	var part: Part = _rig.get_part(id)
	if part == null:
		return
	part.reset_to_origin()
	part.state = Part.State.IDLE
	part.flash_blocker()

## 순서를 틀렸다. 되돌리는 것으로 끝내면 눈 감고 찍는 게 된다.
## 잠깐 뒤에 시범을 다시 보여 준다.
func _on_group_reset(group: String) -> void:
	if _clearing or _failed:
		return
	hud.flash_part_name("순서가 틀렸다", UiStyle.DANGER)
	await get_tree().create_timer(0.85).timeout
	if _clearing or _failed:
		return
	_demo_sequence(group)

# --- 불안정도 ------------------------------------------------------------

func _on_instability(value: float, level: int) -> void:
	hud.set_instability(value, level)

func _on_warned() -> void:
	Sfx.play("alarm", -8.0)
	Haptics.bump()
	hud.flash_part_name("장치가 불안정하다", UiStyle.AMBER)

## 75% — 열어 둔 잠금 하나가 다시 걸린다 (기획서 13번 "새로운 잠금 활성화").
func _on_relocked() -> void:
	Sfx.play("relock", -2.0)
	Haptics.bump()
	hud.flash_part_name("잠금이 다시 걸렸다", UiStyle.DANGER)
	_return_recent(1)

## 100% — 과부하. 뜯은 것 둘이 도로 박히고 별 하나를 잃는다.
## 노멀에서는 여기까지다. 게임오버는 없다 (기획서 13번).
func _on_overloaded(strike: int, limit: int) -> void:
	if _fx != null:
		_fx.burst()
	Sfx.play("overload", 0.0)
	Haptics.success()
	hud.flash_white(0.45)
	hud.set_strikes(_instability.strikes_left(), limit)
	hud.flash_part_name("과부하 %d / %d — 한 번 더면 터진다" % [strike, limit],
		UiStyle.DANGER)
	_return_recent(2)

## 경고를 다 쓰면 장치가 터진다.
## 기획서 13번이 막은 것은 "**즉시** 게임오버" 다.
## 한 번 틀려서 죽는 게 아니라 계속 틀려서 죽는 것은 다른 이야기다.
func _on_detonated() -> void:
	if _failed:
		return
	router.input_locked = true
	if _fx != null:
		_fx.burst()
		_fx.set_heat(1.0)
	hud.set_strikes(0, stage.overload_limit)
	hud.flash_white(1.0)
	Sfx.play("overload", 2.0)
	Haptics.success()

	# 장치가 한 번 크게 흔들리고 꺼진다. 그다음에 실패 화면.
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
			var k: float = (1.0 - t) * 0.09
			_rig.position = Vector3(randf_range(-k, k), randf_range(-k, k),
				randf_range(-k, k))
			if _core != null and _core.has_surface_material():
				_core.set_emission(Color(1.0, 0.22, 0.06), lerpf(16.0, 0.0, t)),
		0.0, 1.0, 0.9)
	tw.tween_callback(func() -> void:
		_rig.position = Vector3.ZERO
		if _fx != null:
			_fx.stop_steam()
		_fail("DEVICE DETONATED", "너무 많이 틀렸다"))

func _return_recent(count: int) -> void:
	if _clearing:
		return
	router.input_locked = true
	for i in count:
		var id := engine.undo(false)      # 진행만 잃는다. 쓴 수는 남는다
		if id.is_empty():
			break
		_return_to_device(id)
		await get_tree().create_timer(0.16).timeout
	hud.set_progress(engine.total() - engine.remaining(), engine.moves)
	hud.set_tools(_undo_left, _hint_left, not engine.history().is_empty())
	await get_tree().create_timer(0.4).timeout
	if _instability != null:
		_instability.hold(false)
	router.input_locked = _clearing or hud.is_paused()

func _return_to_device(id: String) -> void:
	var part: Part = _rig.get_part(id)
	if part == null:
		return
	if _slot_of.has(id):
		hud.tray.release(part, _rig.parts_root())
		_slot_of.erase(id)
	else:
		part.reset_to_origin()
	part.state = Part.State.IDLE
	part.flash_blocker()
	part.shake(part.def.remove_direction)

# --- 버튼 ---------------------------------------------------------------

func _on_undo() -> void:
	if _clearing:
		return
	if _undo_left <= 0:
		return
	var id := engine.undo()
	if id.is_empty():
		return
	_undo_left -= 1
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
	hud.set_tools(_undo_left, _hint_left, not engine.history().is_empty())

func _on_hint() -> void:
	if _clearing or _failed or _hint_left <= 0:
		return
	var id := engine.hint()
	if id.is_empty():
		return
	var part: Part = _rig.get_part(id)
	if part == null:
		return
	_hint_left -= 1
	hud.set_tools(_undo_left, _hint_left, not engine.history().is_empty())
	Sfx.play("click", -6.0)
	_show_hint(part)

## 힌트는 세 가지를 한다: 어디인지, 어떻게 하는지, 뭐라고 부르는지.
## 반짝이기만 하면 안쪽에 가려진 부품은 아무것도 안 보인다.
func _show_hint(part: Part) -> void:
	_orbit.look_toward(part.global_position)

	# 순서 퍼즐은 위치가 아니라 순서가 답이다. 시범을 다시 보여 준다.
	var group := part.def.sequence_group
	if not group.is_empty():
		hud.flash_part_name("순서를 다시 보여 준다", UiStyle.AMBER)
		_demo_sequence(group)
		return

	# 벽 뒤에 있어도 보이게 (through = true)
	part.pulse(Part.OUTLINE_HINT, 4, true)
	_spawn_hint_guide(part)
	hud.flash_part_name("%s  ·  %s" % [part.def.label, _gesture_text(part)],
		UiStyle.AMBER)

func _spawn_hint_guide(part: Part) -> void:
	if _hint_guide != null and is_instance_valid(_hint_guide):
		_hint_guide.queue_free()
	_hint_guide = HintGuide.new()
	_hint_guide.name = "HintGuide"
	add_child(_hint_guide)
	_hint_guide.build_for(part, _rig, _orbit.camera)

## 무엇을 하라는 것인지 말로도 알려 준다.
func _gesture_text(part: Part) -> String:
	var d := part.params()
	match d.interaction:
		PartDef.Interaction.PULL:
			return "%s 당겨라" % _direction_word(part, d.remove_direction)
		PartDef.Interaction.SLIDE:
			return "%s 밀어라" % _direction_word(part, d.remove_direction)
		PartDef.Interaction.ROTATE:
			return "%s 끝까지 돌려라" % _turn_word(part, d)
		PartDef.Interaction.ALIGN:
			return "빛나는 눈금에 바늘을 맞추고 손을 떼라"
		PartDef.Interaction.PRESS:
			return "꾹 누르고 있어라"
		PartDef.Interaction.ROUTE:
			return "홈을 따라 끝 단자까지 끌어라"
		PartDef.Interaction.SEQUENCE:
			return "순서대로 눌러라"
	return ""

## 방향을 화면 기준으로 말한다. "월드 +X" 라고 해봐야 아무 소용 없다.
func _direction_word(part: Part, dir: Vector3) -> String:
	var cam := _orbit.camera
	var origin := part.global_position
	var world := (_rig.global_transform.basis * dir).normalized()
	var a := cam.unproject_position(origin)
	var b := cam.unproject_position(origin + world * 0.3)
	var v := b - a
	if v.length() < 24.0:
		# 화면에서 거의 안 움직인다 = 카메라 축 방향
		var toward := world.dot(-cam.global_transform.basis.z)
		return "화면 안쪽으로" if toward > 0.0 else "화면 앞으로"
	if absf(v.x) > absf(v.y):
		return "왼쪽으로" if v.x < 0.0 else "오른쪽으로"
	return "위로" if v.y < 0.0 else "아래로"

func _turn_word(part: Part, d: PartDef) -> String:
	var cam := _orbit.camera
	var axis := (_rig.global_transform.basis * d.rotation_axis).normalized()
	var toward := -signf(axis.dot(-cam.global_transform.basis.z))
	if is_zero_approx(toward):
		toward = 1.0
	# 축이 화면 쪽을 향하면 양의 회전이 화면에서 반시계로 보인다
	var clockwise: bool = (signf(d.rotation_target) * toward) < 0.0
	return "시계 방향으로" if clockwise else "반시계 방향으로"

func _pulse_free(color: Color, cycles: int) -> void:
	for id in engine.free_parts():
		var p: Part = _rig.get_part(id)
		if p != null:
			p.pulse(color, cycles, true)

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

## 캡처용: 힌트를 한 번 쓴다.
func debug_hint() -> void:
	_on_hint()

## 캡처용: 불안정도를 원하는 값으로 올려 둔다.
func debug_heat(value: float) -> void:
	if _instability == null:
		return
	_instability.hold(true)
	_instability.force_value(value)
	_instability.hold(false)

## 캡처용: 카메라를 원하는 각도로 돌려놓는다.
func debug_spin(yaw_degrees: float) -> void:
	_orbit._target_yaw = yaw_degrees

## 안드로이드 뒤로 가기 버튼. 앱이 그냥 꺼지면 안 된다.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if hud == null:
		return
	if hud.is_paused():
		hud.close_pause()
	else:
		hud.open_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if not DebugFlags.available:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_ESCAPE:
			if hud.is_paused():
				hud.close_pause()
			else:
				hud.open_pause()
		KEY_F1:
			DebugFlags.toggle_overlay()
		KEY_F2:
			DebugFlags.toggle_collision()
		KEY_F5:
			_restart()
