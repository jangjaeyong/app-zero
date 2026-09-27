class_name HintGuide
extends Node3D
## 힌트가 **무엇을 하라는 것인지**까지 보여 준다.
##
## 부품을 반짝이는 것만으로는 부족하다는 지적을 받았다. 특히 안쪽에 가려진
## 부품은 아예 안 보였다. 그래서
##   1) 테두리를 벽 뚫고 보이게 하고 (Part._set_through)
##   2) 여기서 **손동작을 그려 준다** — 당길 방향의 화살표, 돌릴 방향의 호,
##      누르라는 고리, 따라갈 경로.
##
## 전부 무조명 + 깊이 검사 끄기라 장치 안쪽이어도 보인다.

const LIFETIME := 3.6

var _tint: Color = UiStyle.AMBER
var _phase: float = 0.0
var _movers: Array[Node3D] = []
var _axis: Vector3 = Vector3.UP
var _spin: bool = false

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 4
	m.disable_receive_shadows = true
	return m

static func _mesh_node(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## 부품과 지금 단계에 맞는 안내를 만든다.
var _camera: Camera3D
var _scale: float = 1.0        ## 부품 크기에 맞춘 배율

## 부품이 클 수도 작을 수도 있다. 고정 크기로 그리면 작은 부품에서는
## 장치를 통째로 덮는다. 실제로 그랬다.
static func _radius_of(part: Part) -> float:
	if part.mesh == null or part.mesh.mesh == null:
		return 0.12
	var e: Vector3 = part.mesh.mesh.get_aabb().size
	return clampf(maxf(e.x, maxf(e.y, e.z)) * 0.60, 0.055, 0.34)

func build_for(part: Part, rig: Node3D, cam: Camera3D = null) -> void:
	var d := part.params()
	_camera = cam
	_tint = UiStyle.AMBER
	_scale = _radius_of(part)
	match d.interaction:
		PartDef.Interaction.PULL, PartDef.Interaction.SLIDE:
			_arrow(part, rig, d)
		PartDef.Interaction.ROTATE, PartDef.Interaction.ALIGN:
			_arc(part, rig, d)
		PartDef.Interaction.PRESS:
			_ring(part)
		PartDef.Interaction.ROUTE:
			_path(rig, d)
		_:
			_ring(part)
	_fade_out()

## 당기기·밀기: 방향을 가리키는 화살표가 그 방향으로 흐른다.
##
## 방향이 카메라 축과 거의 나란하면 화살표가 겹쳐 보여 아무 말도 못 한다.
## 그때는 화살표 대신 고리를 쓴다 — 화면 쪽으로 오면 오므라들고
## 안쪽으로 가면 퍼진다.
func _arrow(part: Part, rig: Node3D, d: PartDef) -> void:
	var dir: Vector3 = (rig.global_transform.basis * d.remove_direction).normalized()

	if _camera != null:
		var a := _camera.unproject_position(part.global_position)
		var b := _camera.unproject_position(part.global_position + dir * 0.30)
		if a.distance_to(b) < 46.0:
			_depth_rings(part, dir.dot(-_camera.global_transform.basis.z) < 0.0)
			return

	var origin: Vector3 = part.global_position + dir * (_scale * 0.85)

	var shaft := CylinderMesh.new()
	shaft.top_radius = _scale * 0.085
	shaft.bottom_radius = _scale * 0.085
	shaft.height = _scale * 0.80
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = _scale * 0.24
	head.height = _scale * 0.52

	for i in 3:
		var node := Node3D.new()
		var body := _mesh_node(shaft, Color(_tint, 0.72))
		node.add_child(body)
		var tip := _mesh_node(head, Color(_tint, 0.88))
		tip.position = Vector3(0, _scale * 0.64, 0)
		node.add_child(tip)
		# +Y 를 향해 만든 화살표를 실제 방향으로 눕힌다
		node.global_position = origin + dir * (i * _scale * 0.72)
		add_child(node)
		node.look_at(node.global_position + dir, _fallback_up(dir))
		node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		node.set_meta("base", node.position)
		node.set_meta("dir", dir)
		node.set_meta("offset", float(i) * _scale * 0.72)
		node.set_meta("span", _scale * 2.16)
		_movers.append(node)

## 돌리기·맞추기: 축을 감는 고리와 그 위를 도는 표식.
func _arc(part: Part, rig: Node3D, d: PartDef) -> void:
	var axis: Vector3 = (rig.global_transform.basis * d.rotation_axis).normalized()
	_axis = axis
	_spin = true

	var ring := TorusMesh.new()
	ring.inner_radius = _scale * 1.12
	ring.outer_radius = _scale * 1.20
	var ring_node := _mesh_node(ring, Color(_tint, 0.42))
	ring_node.global_position = part.global_position
	add_child(ring_node)
	_orient_to_axis(ring_node, axis)

	var knob := CylinderMesh.new()
	knob.top_radius = 0.0
	knob.bottom_radius = _scale * 0.30
	knob.height = _scale * 0.62
	var pivot := Node3D.new()
	pivot.global_position = part.global_position
	add_child(pivot)
	_orient_to_axis(pivot, axis)
	var tip := _mesh_node(knob, Color(_tint, 0.95))
	tip.position = Vector3(_scale * 1.16, 0, 0)
	tip.rotation_degrees = Vector3(0, 0, -90.0 * signf(d.rotation_target))
	pivot.add_child(tip)
	pivot.set_meta("spin", signf(d.rotation_target))
	_movers.append(pivot)

## 화면 쪽으로 빼는 부품: 고리가 카메라 쪽으로 오며 작아진다(또는 반대).
func _depth_rings(part: Part, toward_viewer: bool) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = _scale * 0.72
	ring.outer_radius = _scale * 0.80
	for i in 3:
		var node := _mesh_node(ring, Color(_tint, 0.7))
		node.global_position = part.global_position
		add_child(node)
		if _camera != null:
			node.look_at(_camera.global_position, Vector3.UP)
			node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		node.set_meta("depth", float(i) / 3.0)
		node.set_meta("toward", 1.0 if toward_viewer else -1.0)
		node.set_meta("base", node.position)
		_movers.append(node)

## 누르기: 부품 위에서 오므라드는 고리.
func _ring(part: Part) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = _scale * 0.95
	ring.outer_radius = _scale * 1.05
	var node := _mesh_node(ring, Color(_tint, 0.75))
	node.global_position = part.global_position
	add_child(node)
	node.set_meta("shrink", true)
	_movers.append(node)

## 경로: 길을 따라 구슬이 흐른다. 어디로 가야 하는지가 전부다.
func _path(rig: Node3D, d: PartDef) -> void:
	var pts := d.route_points
	if pts.size() < 2:
		return
	var sphere := SphereMesh.new()
	sphere.radius = 0.020
	sphere.height = 0.040
	var steps := 26
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var node := _mesh_node(sphere, Color(_tint, 0.75))
		node.global_position = rig.global_transform * _sample(pts, t)
		add_child(node)
		node.set_meta("wave", t)
		_movers.append(node)

static func _sample(pts: Array[Vector3], t: float) -> Vector3:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var target: float = t * total
	var walked := 0.0
	for i in range(1, pts.size()):
		var seg: float = pts[i].distance_to(pts[i - 1])
		if walked + seg >= target or i == pts.size() - 1:
			var u: float = 0.0 if seg < 0.0001 else (target - walked) / seg
			return pts[i - 1].lerp(pts[i], clampf(u, 0.0, 1.0))
		walked += seg
	return pts[pts.size() - 1]

static func _fallback_up(dir: Vector3) -> Vector3:
	return Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.97 else Vector3.UP

func _orient_to_axis(node: Node3D, axis: Vector3) -> void:
	# TorusMesh 는 XZ 평면에 눕혀 있다. 축이 +Y 가 되도록 돌린다.
	var up := Vector3.UP
	var dot: float = clampf(up.dot(axis), -1.0, 1.0)
	if dot > 0.9999:
		return
	if dot < -0.9999:
		node.rotate(Vector3.RIGHT, PI)
		return
	node.rotate(up.cross(axis).normalized(), acos(dot))

func _process(delta: float) -> void:
	_phase += delta
	for node in _movers:
		if not is_instance_valid(node):
			continue
		if node.has_meta("dir"):
			var base: Vector3 = node.get_meta("base")
			var dir: Vector3 = node.get_meta("dir")
			var off: float = node.get_meta("offset")
			var span: float = node.get_meta("span")
			node.position = base + dir * (fmod(_phase * 0.38 + off, span) - off)
		elif node.has_meta("spin"):
			node.rotate(_axis, delta * 1.8 * float(node.get_meta("spin")))
		elif node.has_meta("shrink"):
			var k: float = 1.0 - 0.35 * fmod(_phase * 0.8, 1.0)
			node.scale = Vector3.ONE * k
		elif node.has_meta("depth"):
			var off: float = node.get_meta("depth")
			var toward: float = node.get_meta("toward")
			var k: float = fmod(_phase * 0.55 + off, 1.0)
			node.scale = Vector3.ONE * lerpf(1.25, 0.45, k if toward > 0.0 else 1.0 - k)
			var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = Color(_tint, 0.85 * (1.0 - absf(k - 0.4)))
		elif node.has_meta("wave"):
			var t: float = node.get_meta("wave")
			var lit: float = 0.35 + 0.65 * maxf(0.0,
				1.0 - absf(fmod(_phase * 0.42, 1.25) - t) * 5.0)
			var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = Color(_tint, lit)

func _fade_out() -> void:
	var tw := create_tween()
	tw.tween_interval(LIFETIME - 0.5)
	tw.tween_method(func(a: float) -> void:
		for node in _movers:
			if not is_instance_valid(node):
				continue
			for child in _all_meshes(node):
				var m := child.material_override as StandardMaterial3D
				if m != null:
					m.albedo_color.a *= a,
		1.0, 0.0, 0.5)
	tw.tween_callback(queue_free)

func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_meshes(c))
	return out
