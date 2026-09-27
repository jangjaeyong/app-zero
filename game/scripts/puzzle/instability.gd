class_name Instability
extends RefCounted
## 장치가 얼마나 화가 났는가. 이 게임의 긴장은 전부 여기서 나온다.
##
## 왜 필요한가: 틀린 시도가 공짜면 "다 눌러보기" 가 최적 전략이 된다.
## 부품 여덟 개를 전부 당겨 보는 데 5초면 되니 생각할 이유가 사라진다.
## 기획서 13번이 잘못된 조작의 결과로 적어 둔 것들(온도 상승, 새 잠금 활성화)이
## 바로 이것이다.
##
## 시간으로는 올리지 않는다. 퍼즐은 오래 들여다보는 게임이고,
## 가만히 보는 사람을 벌주면 안 된다. **틀린 행동만** 대가를 치른다.

signal changed(value: float, level: int)
signal warned()
signal relocked()
signal overloaded(strike: int, limit: int)
signal detonated()

enum Level { CALM, WARN, CRITICAL }

## 처음 값은 너무 순했다. 과부하 한 번 보려면 틀린 시도가 아홉 번쯤 필요했고,
## 그래서 "긴장감이 여전히 부족하다" 는 말을 들었다.
## 사실상 일어나지 않는 일을 만들어 놓고 긴장이라고 부른 셈이다.
const RISE_PER_FAIL := 0.225
const RISE_REPEAT := 0.105      ## 같은 부품을 또 억지로 당기면 더 오른다
const FALL_PER_RESOLVE := 0.16  ## 올바른 수는 진정시키지만, 되돌리진 못한다
const PASSIVE_DECAY := 0.005    ## 초당. 거의 안 식는다
const WARN_AT := 0.45
const RELOCK_AT := 0.72
const OVERLOAD_AT := 1.0
const AFTER_RELOCK := 0.56
const AFTER_OVERLOAD := 0.52

var value: float = 0.0
var overloads: int = 0          ## 과부하 횟수 = 잃은 별
## 이 횟수를 채우면 장치가 터진다. 스테이지가 정한다 (기본 3).
## 기획서 13번이 막은 것은 "**즉시** 게임오버" 다. 한 번 틀려서 죽는 게 아니라
## 계속 틀려서 죽는 것은 다른 이야기다.
var overload_limit: int = 3
var enabled: bool = true

var _last_failed: String = ""
var _warned: bool = false
var _locked_out: bool = false   ## 벌칙 연출 중에는 연쇄로 터지지 않게

func reset() -> void:
	value = 0.0
	overloads = 0
	_last_failed = ""
	_warned = false
	_locked_out = false
	changed.emit(value, level())

func level() -> int:
	if value >= RELOCK_AT:
		return Level.CRITICAL
	if value >= WARN_AT:
		return Level.WARN
	return Level.CALM

## 막힌 부품을 억지로 건드렸다.
func fail(part_id: String) -> void:
	if not enabled or _locked_out:
		return
	var amount := RISE_PER_FAIL
	if part_id == _last_failed:
		amount += RISE_REPEAT
	_last_failed = part_id
	_apply(value + amount)
	_check_thresholds()

## 올바른 수를 뒀다.
func resolve() -> void:
	if not enabled:
		return
	_last_failed = ""
	_apply(value - FALL_PER_RESOLVE)
	if value < WARN_AT:
		_warned = false

func tick(delta: float) -> void:
	if not enabled or value <= 0.0:
		return
	_apply(value - PASSIVE_DECAY * delta)
	if value < WARN_AT:
		_warned = false

## 개발/캡처용으로 값을 직접 넣는다.
func force_value(v: float) -> void:
	_apply(v)

## 벌칙 연출이 끝날 때까지 더 오르지 않게 잠근다.
func hold(on: bool) -> void:
	_locked_out = on

func _apply(v: float) -> void:
	var clamped := clampf(v, 0.0, 1.0)
	if is_equal_approx(clamped, value):
		return
	value = clamped
	changed.emit(value, level())

func _check_thresholds() -> void:
	if value >= OVERLOAD_AT:
		overloads += 1
		_locked_out = true
		if overloads >= overload_limit:
			_apply(1.0)
			detonated.emit()
			return
		_apply(AFTER_OVERLOAD)
		overloaded.emit(overloads, overload_limit)
		return
	if value >= RELOCK_AT:
		_locked_out = true
		_apply(AFTER_RELOCK)
		relocked.emit()
		return
	if not _warned and value >= WARN_AT:
		_warned = true
		warned.emit()

## 과부하로 잃은 별을 뺀 최종 별.
func apply_star_penalty(stars: int) -> int:
	return int(clampi(stars - overloads, 1, 3))

## 남은 경고 횟수. 화면에 띄워서 죽는 것이 예고되게 한다 —
## 모르고 죽으면 억울하다.
func strikes_left() -> int:
	return maxi(0, overload_limit - overloads)
