extends Node
## 설정 (기획서 15번 상단 목록의 settings).
## `user://settings.cfg` 한 파일. 바꾸는 즉시 저장한다.

const PATH := "user://settings.cfg"
const SECTION := "options"

signal changed()

var sound: bool = true:
	set(v):
		sound = v
		_apply_sound()
		_save()
var haptics: bool = true:
	set(v):
		haptics = v
		Haptics.enabled = v
		_save()
## 화면 흔들림. 불안정할 때 장치가 떨리는 연출이 불편한 사람이 있다.
var screen_shake: bool = true:
	set(v):
		screen_shake = v
		_save()

var _cfg := ConfigFile.new()
var _ready_done: bool = false

func _ready() -> void:
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[Settings] 설정을 못 읽었다 (%d). 기본값으로 간다." % err)
	sound = bool(_cfg.get_value(SECTION, "sound", true))
	haptics = bool(_cfg.get_value(SECTION, "haptics", true))
	screen_shake = bool(_cfg.get_value(SECTION, "screen_shake", true))
	_ready_done = true
	_apply_sound()
	Haptics.enabled = haptics

func _apply_sound() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not sound)

func _save() -> void:
	if not _ready_done:
		return
	_cfg.set_value(SECTION, "sound", sound)
	_cfg.set_value(SECTION, "haptics", haptics)
	_cfg.set_value(SECTION, "screen_shake", screen_shake)
	var err := _cfg.save(PATH)
	if err != OK:
		push_error("[Settings] 설정 저장 실패 (%d)" % err)
	changed.emit()
