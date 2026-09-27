extends Node
## 이름으로 부르는 얇은 사운드 레이어.
## 파일이 아직 없어도 게임이 죽지 않게, 없는 건 한 번만 경고하고 조용히 넘어간다.

const DIR := "res://assets/audio/"
const VOICES := 8

var _cache: Dictionary = {}
var _missing: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0

func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(name):
			_missing[name] = true
			push_warning("[Sfx] 사운드 없음: %s" % path)
		return null
	var s: AudioStream = load(path)
	_cache[name] = s
	return s

func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if name.is_empty():
		return
	var s := _stream(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## 같은 소리를 살짝 다른 피치로. 반복해도 귀에 안 거슬리게.
func play_varied(name: String, volume_db: float = 0.0) -> void:
	play(name, volume_db, randf_range(0.94, 1.07))

func stop_all() -> void:
	for p in _players:
		p.stop()
