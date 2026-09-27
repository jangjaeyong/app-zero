class_name DeviceRig
extends Node3D
## GLB 를 읽어 퍼즐 데이터에 적힌 부품만 조작 가능한 Part 로 감싼다.
## GLB 는 아무것도 모르는 "그냥 모델"로 남는다 (기획서 9번).

const PICK_LAYER := 2

signal built(missing: PackedStringArray)

var stage: StageDef
var parts: Dictionary = {}          ## id -> Part
var _parts_root: Node3D
var _model_root: Node3D

func build(stage_def: StageDef) -> PackedStringArray:
	stage = stage_def
	_clear()

	var missing := PackedStringArray()
	if not ResourceLoader.exists(stage.device_model):
		push_error("[DeviceRig] 모델 없음: %s" % stage.device_model)
		built.emit(PackedStringArray(["<model>"]))
		return PackedStringArray(["<model>"])

	var packed: PackedScene = load(stage.device_model)
	_model_root = packed.instantiate()
	_model_root.name = "Model"
	add_child(_model_root)

	_parts_root = Node3D.new()
	_parts_root.name = "Parts"
	add_child(_parts_root)

	for id in stage.part_order:
		var node := _model_root.find_child(id, true, false)
		if node == null or not (node is MeshInstance3D):
			push_error("[DeviceRig] GLB 에 '%s' 메시가 없다. 퍼즐 데이터와 모델 이름이 어긋났다." % id)
			missing.append(id)
			continue
		_wrap(stage.parts[id], node as MeshInstance3D)

	built.emit(missing)
	return missing

func _wrap(def: PartDef, mesh: MeshInstance3D) -> void:
	var xform := _relative_transform(mesh, _model_root)

	var part := Part.new()
	part.collision_layer = PICK_LAYER
	part.collision_mask = 0
	part.input_ray_pickable = true
	_parts_root.add_child(part)
	part.transform = xform

	mesh.get_parent().remove_child(mesh)
	part.add_child(mesh)
	mesh.transform = Transform3D.IDENTITY

	part.setup(def, mesh)
	parts[def.id] = part

## 노드의 변환을 기준 노드 기준으로 누적한다.
## 트리에 들어가기 전이라 global_transform 을 못 믿는 시점에도 쓸 수 있다.
static func _relative_transform(node: Node3D, base: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != base:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func get_part(id: String) -> Part:
	return parts.get(id)

func all_parts() -> Array:
	var out: Array = []
	for id in stage.part_order:
		if parts.has(id):
			out.append(parts[id])
	return out

func reset_all() -> void:
	for id in parts:
		var p: Part = parts[id]
		p.state = Part.State.IDLE
		p.visible = true
		p.snap_home()
		p.scale = Vector3.ONE
		p.set_outline(Part.OUTLINE_FREE, 0.0)
		if p.get_parent() != _parts_root:
			p.reparent(_parts_root, false)
			p.transform = p.home_transform

func parts_root() -> Node3D:
	return _parts_root

func _clear() -> void:
	parts.clear()
	for c in get_children():
		c.queue_free()
	_model_root = null
	_parts_root = null
