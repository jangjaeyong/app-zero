class_name SafeArea
extends RefCounted
## 노치·펀치홀·제스처 바를 피한다.
##
## 안드로이드는 전체 화면이라 상단 카메라 구멍 아래로 UI 가 들어간다.
## DisplayServer 는 **기기 픽셀** 로 안전 영역을 주는데 우리 UI 는
## 1080x1920 기준 늘림 좌표를 쓴다. 그래서 비율로 환산해야 한다.

## 화면 네 변의 여백을 늘림 좌표(뷰포트 단위)로 돌려준다.
static func insets(node: Node) -> Dictionary:
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
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

	# 안전 영역은 화면 전체 기준이고 창은 그 안에 있다. 창 밖으로 나간 값은 버린다.
	var view := node.get_viewport().get_visible_rect().size
	var scale := Vector2(view.x / win_size.x, view.y / win_size.y)

	return {
		"left": maxf(0.0, float(safe.position.x)) * scale.x,
		"top": maxf(0.0, float(safe.position.y)) * scale.y,
		"right": maxf(0.0, win_size.x - float(safe.position.x + safe.size.x)) * scale.x,
		"bottom": maxf(0.0, win_size.y - float(safe.position.y + safe.size.y)) * scale.y,
	}

## 루트 Control 을 안전 영역 안으로 밀어 넣는다.
## 자식들은 앵커로 붙어 있으니 루트만 줄이면 전부 따라온다.
static func apply(root: Control, extra_top: float = 0.0) -> void:
	if root == null:
		return
	var i := insets(root)
	root.offset_left = i["left"]
	root.offset_top = i["top"] + extra_top
	root.offset_right = -i["right"]
	root.offset_bottom = -i["bottom"]

## 화면이 돌거나 창 크기가 바뀌면 다시 잡아야 한다.
static func bind(root: Control, extra_top: float = 0.0) -> void:
	if root == null:
		return
	apply(root, extra_top)
	var win := root.get_window()
	if win != null and not win.size_changed.is_connected(apply.bind(root, extra_top)):
		win.size_changed.connect(apply.bind(root, extra_top))
