extends Node
## 햅틱. 사운드/애니메이션과 한 세트로 취급한다 (기획서 16번).

var enabled: bool = true

func _handheld() -> bool:
	return enabled and OS.get_name() == "Android"

## 부품을 집었다, 눈금 하나 돌았다 — 아주 짧게.
func tick() -> void:
	if _handheld():
		Input.vibrate_handheld(10, 0.35)

## 걸렸다 — 툭.
func bump() -> void:
	if _handheld():
		Input.vibrate_handheld(28, 0.75)

## 빠졌다 — 딱.
func release() -> void:
	if _handheld():
		Input.vibrate_handheld(18, 0.6)

## 클리어.
func success() -> void:
	if _handheld():
		Input.vibrate_handheld(60, 1.0)
