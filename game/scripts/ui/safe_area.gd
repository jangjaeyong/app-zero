class_name SafeArea
extends RefCounted
## 노치·펀치홀·제스처 바를 피한다.
##
## 안드로이드는 전체 화면이라 상단 카메라 구멍 아래로 UI 가 들어간다.
## DisplayServer 는 **기기 픽셀** 로 안전 영역을 주는데 우리 UI 는
## 1080x1920 기준 늘림 좌표를 쓴다. 그래서 비율로 환산해야 한다.
##
## ⚠️ 몰입 모드(immersive)에서는 안드로이드가 **디스플레이 컷아웃만** 돌려준다.
## 제스처 바는 안 알려 준다. 그래서 아래쪽에는 최소 여백을 강제로 둔다 —
## 안 그러면 하단 버튼의 아랫부분이 홈 제스처에 먹힌다.
const MIN_BOTTOM := 56.0

## 화면 네 변의 여백을 늘림 좌표(뷰포트 단위)로 돌려준다.
static func insets(node: Node) -> Dictionary:
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": MIN_BOTTOM}
	if node == null or not node.is_inside_tree():
		return zero

	var win := node.get_window()
	if win == null:
		return zero
	var win_size := Vector2(win.size)
	if win_size.x <= 0.0 or win_size.y <= 0.0:
		return zero

	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return zero

	var view := node.get_viewport().get_visible_rect().size
	var scale := Vector2(view.x / win_size.x, view.y / win_size.y)

	# 데스크톱에서는 이 사각형이 화면 기준이라 창 위치와 섞이면 엉뚱한 값이 나온다.
	# 기기가 아닌 곳에서는 최소 여백만 쓴다.
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

	return {
		"left": maxf(0.0, float(safe.position.x)) * scale.x,
		"top": maxf(0.0, float(safe.position.y)) * scale.y,
		"right": maxf(0.0, win_size.x - float(safe.position.x + safe.size.x)) * scale.x,
		"bottom": maxf(MIN_BOTTOM,
			maxf(0.0, win_size.y - float(safe.position.y + safe.size.y)) * scale.y),
	}

## 루트 Control 을 안전 영역 안으로 밀어 넣는다.
static func apply(root: Control, extra_top: float = 0.0) -> void:
	if root == null or not is_instance_valid(root):
		return
	var i := insets(root)
	root.offset_left = i["left"]
	root.offset_top = i["top"] + extra_top
	root.offset_right = -i["right"]
	root.offset_bottom = -i["bottom"]

## 화면이 돌거나 창 크기가 바뀌면 다시 잡는다.
##
## ⚠️ 예전에는 `win.size_changed.connect(apply.bind(root))` 에
## `is_connected(apply.bind(root))` 로 중복을 걸렀는데, Callable.bind 의
## 동등 비교는 **묶인 값을 무시한다.** 그래서 맨 처음 한 번만 연결되고
## 그 뒤의 모든 화면은 조용히 연결되지 않았다. 게다가 그 하나는 대상이
## 스크립트라 화면이 사라져도 안 끊겨 매번 오류를 뿜었다.
## 이제는 Control 에 붙는 작은 노드가 연결을 소유한다 — 노드가 사라지면
## 연결도 같이 사라진다.
static func bind(root: Control, extra_top: float = 0.0) -> void:
	if root == null:
		return
	for c in root.get_children():
		if c is _Binder:
			return
	var binder := _Binder.new()
	binder.name = "SafeAreaBinder"
	binder.target = root
	binder.extra_top = extra_top
	root.add_child(binder)

class _Binder extends Node:
	var target: Control
	var extra_top: float = 0.0

	func _ready() -> void:
		var win := get_window()
		if win != null:
			win.size_changed.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		SafeArea.apply(target, extra_top)
