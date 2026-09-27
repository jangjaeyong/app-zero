# Godot 4 — 실제로 부딪힌 것들

ZERO(3D 해체 퍼즐, Godot 4.7 / Android 세로)를 만들며 **직접 겪은 것만** 적었다.
일반론이나 문서에서 옮겨 온 것은 없다. 다음에 Godot 으로 뭘 만들 때 먼저 읽으면
같은 데서 시간을 안 태운다.

프로젝트 자체는 2026-09-28 에 접었다 ([`POSTMORTEM.md`](POSTMORTEM.md)).
이 문서와 `tools/` 의 스크립트들이 남길 만한 것이다.

---

기록해 둔다. 같은 데서 또 시간 쓰지 않으려고.

### `.tscn` 의 Transform3D 는 행 우선이다

`Transform3D(a,b,c, d,e,f, g,h,i, ox,oy,oz)` 의 9개 값은 basis 를 **행** 순서로
적은 것이다. 열(기저 벡터) 순서로 적으면 전치돼서 들어간다.

조명 3등을 전부 열 순서로 써 넣었더니 전혀 다른 방향을 비췄고, 흰 패널이
앰비언트만 받아 회청색으로 나왔다. **재질 문제로 한참 헤맸다.**
확인 방법은 실행 중에 `-light.global_transform.basis.z` 를 찍어 보는 것.

### Color 는 인자 4개로

`.tscn` 파서는 `Color(r,g,b)` 를 거부한다. 알파까지 적어야 한다.

### 흰 패널을 metallic 으로 두면 안 된다

도장면인데 `metallic = 0.28` 로 잡아 뒀더니 파란 하늘을 반사해서 파랗게 떴다.
흰 판은 유전체다 (`metallic ≈ 0.04`).

### 크기 0 은 금지

트레이 팝인을 `scale = Vector3.ZERO` 로 시작했더니 행렬식이 0 이라
`Condition "det == 0" is true` 가 쏟아졌다. `0.001` 로 시작한다.

### `class_name` 은 다시 import 해야 잡힌다

새 스크립트를 만든 뒤에는 `godot --headless --import` 를 한 번 돌려야
전역 클래스 캐시에 등록된다. 안 그러면
`Identifier "X" not declared in the current scope`.

### 충돌 형상은 trimesh

휜 냉각 튜브를 볼록 껍질로 만들면 앞면을 통째로 덮어 뒤 부품의 터치를
가로챈다. 물리 시뮬레이션을 안 돌리니 (중력 0) `create_trimesh_shape()` 로
정확하게 딴다.

### 섀시 상부는 통판이면 안 된다

상단 커버를 떼도 그 아래가 또 막혀 있어 기어 락이 안 드러났다.
사각 프레임으로 바꿔 가운데를 뚫었다. **모델 형태가 퍼즐을 막을 수 있다.**

---

---

## 함께 볼 것 — 그대로 옮겨 쓸 수 있는 것들

- `tools/check_scripts.sh` — 스크립트 컴파일 검사. **왜 게임 안에서 못 하는지** 주석에 적어 뒀다
- `game/scripts/core/dev_harness.gd` — 헤드리스 화면 캡처 + 데이터 검증 하네스.
  실기기 없이 단계별 그림을 뽑고, 콘텐츠 데이터의 모순을 자동으로 잡는다
- `game/scripts/ui/safe_area.gd` — 안드로이드 안전 영역을 늘림 좌표로 환산
- `game/scripts/device/material_dresser.gd` — **UV 를 펴지 않고** 표면 디테일 입히기
- `tools/zero_blender.py` — Blender 헤드리스로 부품별 독립 Object 조립 → GLB
- `tools/make_textures.py` · `make_sfx.py` · `make_icons.py` —
  의존성 없이 순수 파이썬으로 PNG/WAV 생성 (타일링 노이즈, 효과음 합성, 아이콘)
