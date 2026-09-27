class_name CaptureRunner
extends Node
## 개발용 화면 캡처 하네스. 실기기 없이 진행 단계별 그림을 뽑아 확인한다.
## 릴리스 빌드에서는 DebugFlags.available 이 false 라 붙지 않는다.
##
##   godot --path game --resolution 1080x1920 -- --shot /tmp/a.png --remove 3
##   godot --path game -- --shot /tmp/clear.png --clear

signal finished()

var game: Node

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := _arg(args, "--shot")
	if path.is_empty():
		return

	var remove := int(_arg(args, "--remove", "0"))
	var do_clear := args.has("--clear")
	var spin := float(_arg(args, "--spin", "0"))

	# 장면이 자리를 잡을 시간. 첫 프레임은 조명도 트윈도 아직이다.
	await _wait(3.4)

	if spin != 0.0 and game != null and game.has_method("debug_spin"):
		game.debug_spin(spin)
		await _wait(0.6)

	for i in remove:
		if game != null and game.has_method("_debug_force_remove"):
			game._debug_force_remove()
		await _wait(0.5)

	if do_clear and game != null and game.has_method("_debug_open_core"):
		game._debug_open_core()
		await _wait(6.0)
	else:
		await _wait(0.8)

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	if err != OK:
		push_error("[Capture] 저장 실패 %s (%d)" % [path, err])
	else:
		print("ZERO_SHOT %s %dx%d" % [path, img.get_width(), img.get_height()])
	finished.emit()
	await _wait(0.2)
	get_tree().quit()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

static func _arg(args: PackedStringArray, key: String, fallback: String = "") -> String:
	for i in args.size():
		if args[i] == key and i + 1 < args.size():
			return args[i + 1]
	return fallback
