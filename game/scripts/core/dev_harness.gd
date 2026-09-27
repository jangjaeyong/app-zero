extends Node
## 개발용 하네스. 실기기 없이 화면을 뽑고, 스테이지 데이터를 검증한다.
## 오토로드라 어느 화면에서든 쓸 수 있고,
## 릴리스 빌드에서는 DebugFlags.available 이 false 라 아무것도 하지 않는다.
##
##   godot --path game --resolution 530x942 -- --shot a.png
##   godot --path game -- --shot b.png --goto select
##   godot --path game -- --shot c.png --goto game --stage res://.../stage_002.json --remove 3
##   godot --path game -- --shot d.png --goto game --clear
##   godot --headless --path game -- --validate

func _ready() -> void:
	if not DebugFlags.available:
		return
	var args := OS.get_cmdline_user_args()
	if args.has("--validate"):
		_validate_all()
		return
	if not args.has("--shot"):
		return
	_run(args)

# ── 스테이지 검증 ────────────────────────────────────────────────────
#
# 스테이지가 늘어날수록 손으로 확인할 수 없다. 데이터가 게임을 정의하니,
# 데이터가 틀리면 조용히 못 푸는 판이 나온다. 그걸 여기서 잡는다.

func _validate_all() -> void:
	await get_tree().process_frame
	var problems := 0
	var stages := 0
	for chapter in Session.catalog.chapters:
		for path in chapter.stages:
			stages += 1
			problems += _validate_stage(chapter, path)
	print("")
	if problems == 0:
		print("ZERO_VALIDATE_OK  스테이지 %d개 · 문제 없음" % stages)
	else:
		print("ZERO_VALIDATE_FAIL  스테이지 %d개 · 문제 %d건" % [stages, problems])
	get_tree().quit(0 if problems == 0 else 1)

func _validate_stage(chapter: StageCatalog.Chapter, path: String) -> int:
	var fails: Array[String] = []
	var stage := StageDef.load_from(path)
	if stage == null:
		print("  ✗ %s — 읽을 수 없다" % path)
		return 1

	# 1) 모델에 부품 메시가 다 있는가
	var names := _mesh_names(stage.device_model)
	if names.is_empty():
		fails.append("모델을 못 읽었다: %s" % stage.device_model)
	else:
		for id in stage.part_order:
			if not names.has(id):
				fails.append("GLB 에 '%s' 메시가 없다" % id)
		for n in stage.static_nodes:
			if not names.has(n):
				fails.append("GLB 에 정적 노드 '%s' 가 없다" % n)

	# 2) 정말 끝까지 풀리는가 — 자유로운 부품을 계속 집어 본다
	var engine := PuzzleEngine.new(stage)
	var guard := stage.part_order.size() + 2
	while not engine.is_cleared() and guard > 0:
		var free := engine.free_parts()
		if free.is_empty():
			break
		for id in free:
			engine.mark_resolved(id)
		guard -= 1
	if not engine.is_cleared():
		var stuck := PackedStringArray()
		for id in stage.part_order:
			if not engine.is_resolved(id):
				stuck.append("%s(←%s)" % [id, ",".join(engine.blockers_of(id))])
		fails.append("끝까지 안 풀린다. 막힌 것: %s" % ", ".join(stuck))

	# 3) 기준 수가 부품 수보다 적으면 별 3개가 영원히 안 나온다
	if stage.par_moves > 0 and stage.par_moves < stage.part_order.size():
		fails.append("기준 %d수 < 부품 %d개 — 별 3개가 불가능하다"
			% [stage.par_moves, stage.part_order.size()])

	# 4) 코어는 정확히 하나
	var cores := 0
	for id in stage.part_order:
		if (stage.parts[id] as PartDef).is_core:
			cores += 1
	if cores != 1:
		fails.append("코어가 %d개다 (1개여야 한다)" % cores)

	var kinds: Dictionary = {}
	for id in stage.part_order:
		var k := (stage.parts[id] as PartDef).interaction_name()
		kinds[k] = int(kinds.get(k, 0)) + 1
	var kind_text := ""
	for k in kinds:
		kind_text += "%s×%d " % [k, kinds[k]]

	if fails.is_empty():
		print("  ✓ %-9s %-26s 부품 %d · 기준 %d수 · %s"
			% [chapter.id, stage.id, stage.part_order.size(), stage.par_moves,
			   kind_text.strip_edges()])
		return 0
	print("  ✗ %-9s %s" % [chapter.id, stage.id])
	for f in fails:
		print("      · %s" % f)
	return fails.size()

func _mesh_names(model_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not ResourceLoader.exists(model_path):
		return out
	var packed: PackedScene = load(model_path)
	if packed == null:
		return out
	var root := packed.instantiate()
	_collect(root, out)
	root.free()
	return out

func _collect(node: Node, out: PackedStringArray) -> void:
	if node is MeshInstance3D:
		out.append(node.name)
	for c in node.get_children():
		_collect(c, out)

func _run(args: PackedStringArray) -> void:
	var path := _arg(args, "--shot")
	var goto := _arg(args, "--goto")
	var stage := _arg(args, "--stage")
	var remove := int(_arg(args, "--remove", "0"))
	var settle := float(_arg(args, "--wait", "3.4"))
	var do_clear := args.has("--clear")

	# 오토로드는 첫 씬보다 먼저 돈다. 씬이 붙을 때까지 기다린다.
	await get_tree().process_frame
	await get_tree().process_frame

	if not stage.is_empty():
		Session.current_stage_path = stage
	match goto:
		"menu":
			Session.goto_menu()
		"select":
			Session.goto_select()
		"game":
			Session.play(stage if not stage.is_empty()
				else Session.catalog.first_playable())
		_:
			pass

	await _wait(settle)

	var game := _game_node()
	for i in remove:
		if game != null:
			game._debug_force_remove()
		await _wait(0.45)
	# 부품을 뺄 때마다 게이지가 내려간다. 캡처용 heat 는 다 뺀 뒤에 올려야 보인다.
	var heat := float(_arg(args, "--heat", "0"))
	if heat > 0.0 and game != null and game.has_method("debug_heat"):
		game.debug_heat(heat)
		await _wait(0.7)

	if do_clear and game != null:
		game._debug_open_core()
		await _wait(6.5)
	else:
		await _wait(0.6)

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error("[Capture] 저장 실패 %s (%d)" % [path, err])
	else:
		print("ZERO_SHOT %s %dx%d" % [path, img.get_width(), img.get_height()])
	await _wait(0.2)
	get_tree().quit()

func _game_node() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_debug_force_remove"):
		return scene
	return null

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

static func _arg(args: PackedStringArray, key: String, fallback: String = "") -> String:
	for i in args.size():
		if args[i] == key and i + 1 < args.size():
			return args[i + 1]
	return fallback
