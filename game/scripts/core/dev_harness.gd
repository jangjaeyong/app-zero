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
	# 스크립트 컴파일 확인은 **이 안에서 할 수 없다.**
	# 그냥 load() 하면 캐시된 것이 와서 깨진 것도 통과하고,
	# 캐시를 무시하면 지금 돌고 있는 자기 자신까지 다시 불러와 프로세스가 망가진다.
	# → tools/check_scripts.sh 로 뺐다 (godot --check-only 를 파일마다 돌린다).
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
	# 통과 경로 검사는 상자 근사라 보수적이다. 실패로 막지 않고 눈으로 볼 목록으로만 낸다.
	var warns: Array[String] = []
	var stage := StageDef.load_from(path)
	if stage == null:
		print("  ✗ %s — 읽을 수 없다" % path)
		return 1

	# 1) 모델에 부품 메시가 다 있는가
	var table := _mesh_table(stage.device_model)
	var names := PackedStringArray()
	for k in table:
		names.append(k)
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

	# 4) 경로 조작: 점이 2개 미만이면 끌 데가 없다
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		for si in pd.step_count():
			var sd := pd.step_at(si)
			if sd.interaction == PartDef.Interaction.ROUTE \
					and sd.route_points.size() < 2:
				fails.append("%s 의 route_points 가 %d개다 (2개 이상)"
					% [id, sd.route_points.size()])

	# 5) 순서 그룹: 번호가 0부터 빠짐없이 이어져야 한다.
	#    하나라도 비면 그 그룹은 영원히 안 끝난다.
	var groups: Dictionary = {}
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		if pd.sequence_group.is_empty():
			continue
		var g: Array = groups.get(pd.sequence_group, [])
		g.append(pd.sequence_index)
		groups[pd.sequence_group] = g
	for g_name in groups:
		var idx: Array = groups[g_name]
		idx.sort()
		var want := range(idx.size())
		if idx != want:
			fails.append("순서 그룹 '%s' 의 번호가 %s 다 (0부터 %d 까지여야 한다)"
				% [g_name, str(idx), idx.size() - 1])

	# 6) 빠져나가는 길에 아직 붙어 있는 것을 뚫고 지나가는가.
	#    이건 데이터만 봐서는 절대 안 보이고, 실제로 세 군데에서 일어나고 있었다.
	warns.append_array(_sweep_check(stage, table))
	if OS.get_cmdline_user_args().has("--boxes"):
		for k in table:
			var bb: AABB = table[k]["aabb"]
			print("      [BOX] %-16s y %.3f..%.3f  x %.3f..%.3f  z %.3f..%.3f"
				% [k, bb.position.y, bb.position.y + bb.size.y,
				   bb.position.x, bb.position.x + bb.size.x,
				   bb.position.z, bb.position.z + bb.size.z])

	# 7) 경로 시작점이 부품 자리와 맞는가 (몇 cm 어긋나면 첫 터치에 부품이 튄다)
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		for si in pd.step_count():
			var sd := pd.step_at(si)
			if sd.interaction != PartDef.Interaction.ROUTE or sd.route_points.is_empty():
				continue
			if not table.has(id):
				continue
			var origin: Vector3 = table[id]["origin"]
			var gap: float = origin.distance_to(sd.route_points[0])
			if gap > 0.05:
				fails.append("%s 의 경로 시작점이 부품 자리에서 %.3f 떨어져 있다" % [id, gap])

	# 8) 여러 단계 부품은 최상위 값으로 트레이에 날아간다.
	#    마지막 단계와 어긋나면 엉뚱한 방향으로 날아간다.
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		if not pd.has_steps():
			continue
		var last := pd.step_at(pd.step_count() - 1)
		if last.resolve != pd.resolve:
			fails.append("%s: 마지막 단계의 resolve 가 최상위와 다르다" % id)
		if pd.leaves_device() \
				and pd.remove_direction.distance_to(last.remove_direction) > 0.01:
			fails.append("%s: 최상위 remove_direction 이 마지막 단계와 다르다 %v / %v"
				% [id, pd.remove_direction, last.remove_direction])

	# 9) GLB 의 모든 메시가 부품이거나 정적 노드여야 한다
	for mesh_name in table:
		if stage.parts.has(mesh_name):
			continue
		if Array(stage.static_nodes).has(mesh_name):
			continue
		fails.append("GLB 의 '%s' 가 부품도 정적 노드도 아니다" % mesh_name)

	# 10) 맞추기는 목표가 돌릴 수 있는 범위 안에 있어야 한다
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		for si in pd.step_count():
			var sd := pd.step_at(si)
			if sd.interaction != PartDef.Interaction.ALIGN:
				continue
			if absf(sd.rotation_target) + sd.align_tolerance > sd.align_range:
				fails.append("%s 의 맞추기 목표 %.0f 가 범위 ±%.0f 를 벗어난다"
					% [id, sd.rotation_target, sd.align_range])

	# 11) 코어는 정확히 하나
	var cores := 0
	for id in stage.part_order:
		if (stage.parts[id] as PartDef).is_core:
			cores += 1
	if cores != 1:
		fails.append("코어가 %d개다 (1개여야 한다)" % cores)

	var kinds: Dictionary = {}
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		# 여러 단계 부품은 단계마다 조작이 다르다. 전부 센다.
		for si in pd.step_count():
			var k := pd.step_at(si).interaction_name()
			kinds[k] = int(kinds.get(k, 0)) + 1
	var kind_text := ""
	for k in kinds:
		kind_text += "%s×%d " % [k, kinds[k]]

	if fails.is_empty():
		print("  ✓ %-9s %-26s 부품 %d · 기준 %d수 · %s"
			% [chapter.id, stage.id, stage.part_order.size(), stage.par_moves,
			   kind_text.strip_edges()])
	else:
		print("  ✗ %-9s %s" % [chapter.id, stage.id])
		for f in fails:
			print("      · %s" % f)
	for w in warns:
		print("      ⚠ %s" % w)
	return fails.size()

## 이름 → { origin: Vector3, aabb: AABB } (장치 좌표계).
## 이름만 확인하던 것으로는 "빠지는 길에 뭘 뚫고 가는가" 를 볼 수 없다.
## 제거되는 부품이 지나가는 길에, 그때까지 남아 있는 것과 부딪히는가.
func _sweep_check(stage: StageDef, table: Dictionary) -> Array[String]:
	const START := 0.04      ## 맞닿아 있는 것은 넘긴다
	const EPS := 0.018       ## 이보다 얕게 스치는 것은 넘긴다
	var out: Array[String] = []
	for id in stage.part_order:
		var pd: PartDef = stage.parts[id]
		if not pd.leaves_device() or not table.has(id):
			continue
		var dir: Vector3 = pd.remove_direction.normalized()
		var dist: float = pd.remove_distance + 0.28     # game.gd 의 날아가는 거리
		# 상자는 부품보다 크다 — 토러스나 ㄱ자 부품은 모서리가 텅 비어 있다.
		# 그대로 쓰면 프레임 가장자리를 스치는 것마다 오탐이 난다.
		# 진행 방향과 **직각인 두 축만** 줄여 "부품의 몸통" 에 가깝게 만든다.
		var box: AABB = table[id]["aabb"]
		var shrink := Vector3.ONE
		for axis in 3:
			if absf(dir[axis]) < 0.5:
				shrink[axis] = 0.62
		var center: Vector3 = box.position + box.size * 0.5
		var size: Vector3 = box.size * shrink
		box = AABB(center - size * 0.5, size)
		var a: AABB = AABB(box.position + dir * START, box.size)
		var swept: AABB = a.merge(AABB(box.position + dir * dist, box.size))

		var gone := _blockers_closure(stage, id)
		for other in table:
			if other == id or gone.has(other):
				continue    # 이것보다 먼저 빠지는 것들. 그때 이미 없다
			# ⚠️ 정적 구조물(Body)은 뺀다. 통짜로 합쳐진 프레임이라
			# 속이 비어 있어도 상자가 겹치고, 안쪽 레일·브래킷 옆을 지나가는
			# 것만으로 걸린다. 전부 켜 놓으면 매번 울려서 아무도 안 본다.
			# (천장을 뚫고 나가는 것 같은 진짜 경우는 눈으로 확인한다)
			if not stage.parts.has(other):
				continue
			if not _overlaps(swept, table[other]["aabb"], EPS):
				continue
			if not _hits_faces(swept, table[other]["faces"]):
				continue
			var ov := _overlap_box(swept, table[other]["aabb"])
			out.append("%s 가 빠지는 길에 '%s' 를 뚫고 지나간다 (겹침 %.2f×%.2f×%.2f)"
				% [id, other, ov.x, ov.y, ov.z])
	return out

func _mesh_table(model_path: String) -> Dictionary:
	var out: Dictionary = {}
	if not ResourceLoader.exists(model_path):
		return out
	var packed: PackedScene = load(model_path)
	if packed == null:
		return out
	var root := packed.instantiate()
	_collect(root, root, out)
	root.free()
	return out

func _collect(node: Node, base: Node3D, out: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var xf := DeviceRig._relative_transform(mi, base)
		var local := mi.mesh.get_aabb()
		# 삼각형까지 들고 있어야 한다. 상자만 비교하면 속 빈 프레임(Body)은
		# 언제나 겹친다고 나와 전부 오탐이 된다.
		var faces := PackedVector3Array()
		for v in mi.mesh.get_faces():
			faces.append(xf * v)
		out[mi.name] = {"origin": xf.origin, "aabb": xf * local, "faces": faces}
	for c in node.get_children():
		_collect(c, base, out)

## 두 상자가 세 축 모두에서 eps 이상 겹치는가. (싼 1차 거르개)
static func _overlaps(a: AABB, b: AABB, eps: float) -> bool:
	for i in 3:
		var lo: float = maxf(a.position[i], b.position[i])
		var hi: float = minf(a.position[i] + a.size[i], b.position[i] + b.size[i])
		if hi - lo < eps:
			return false
	return true

## 쓸고 지나간 상자가 상대의 **면** 을 실제로 건드리는가.
## 꼭짓점이 안에 들어오거나 변이 상자를 가로지르면 부딪힌 것으로 본다.
static func _hits_faces(box: AABB, faces: PackedVector3Array) -> bool:
	var n := faces.size()
	var i := 0
	while i + 2 < n:
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		if box.has_point(a) or box.has_point(b) or box.has_point(c):
			return true
		if box.intersects_segment(a, b) or box.intersects_segment(b, c) \
				or box.intersects_segment(c, a):
			return true
		i += 3
	return false

static func _overlap_box(a: AABB, b: AABB) -> Vector3:
	var out := Vector3.ZERO
	for i in 3:
		out[i] = maxf(0.0, minf(a.position[i] + a.size[i], b.position[i] + b.size[i])
			- maxf(a.position[i], b.position[i]))
	return out

## 이 부품보다 **먼저** 해결되어야 하는 것들 (그때 이미 사라진 것들).
static func _blockers_closure(stage: StageDef, id: String) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array[String] = [id]
	while not queue.is_empty():
		var cur: String = queue.pop_back()
		var pd: PartDef = stage.parts.get(cur)
		if pd == null:
			continue
		for b in pd.blocked_by:
			if seen.has(b):
				continue
			seen[b] = true
			queue.append(b)
	return seen

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
	if args.has("--open-settings"):
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("debug_open_settings"):
			scene.debug_open_settings()
			await _wait(0.6)

	# 부품을 뺄 때마다 게이지가 내려간다. 캡처용 heat 는 다 뺀 뒤에 올려야 보인다.
	var heat := float(_arg(args, "--heat", "0"))
	if heat > 0.0 and game != null and game.has_method("debug_heat"):
		game.debug_heat(heat)
		await _wait(0.7)

	if args.has("--hint") and game != null and game.has_method("debug_hint"):
		game.debug_hint()
		await _wait(1.4)

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
