# ZERO 개발 문서

DEVICE_001 버티컬 슬라이스 시점 기준.

---

## 1. 무엇을 만들었나

기획서 21번의 "1개의 완성도 높은 Vertical Slice". 장치 하나(DEVICE_001)를
8수에 걸쳐 해체해 코어를 안정화시키면 STAGE CLEAR 까지 간다.

콘텐츠를 늘리기 전에 **손맛**을 검증하는 것이 목적이라, 챕터·재화·상점·광고는
의도적으로 만들지 않았다 (기획서 15·17번).

---

## 2. 퍼즐 설계

```
LeftPanel  (pull) ─┐
                   ├─→ PowerCell (pull) ─┐
RightPanel (pull) ─┼─────────────────────┴─→ CoolingTube (pull)
                   │                              │
                   └──────────────────────────────┘
                                                  ↓
                            LockRing (rotate 150°)
                                                  ↓
                            TopCover (pull)
                                                  ↓
                            GearLock (rotate -120°)
                                                  ↓
                            EnergyCore (hold 1.8s) → CLEAR
```

의도한 것:

- **시작점이 둘이다.** 좌/우 패널 아무거나 먼저 열 수 있다. 외길 암기가 아니다.
- **갈래가 다시 합쳐진다.** 냉각 튜브는 파워 셀과 우측 패널이 **둘 다** 빠져야
  열린다. "왜 아직도 안 빠지지?" 가 나오는 지점이고, 이게 의존 그래프를
  체감하게 만든다.
- **조작법이 하나씩 는다.** 당기기 4번으로 손에 익은 뒤 5번째에 처음 돌리기가
  나오고, 마지막 한 수만 길게 누르기다 (기획서 3번).
- **파워 셀은 앞에서 보이는데 왼쪽으로만 빠진다.** 보이지만 못 꺼내는 상태가
  관찰을 유도한다. 그래서 장치 앞면(-Y)을 열어 두었다.

### 막혔을 때

팝업을 띄우지 않는다 (기획서 4번). 대신:

- 부품이 `resist_distance` 만큼만 끌려오다 고무줄처럼 버틴다
- 손을 떼면 덜컥거리며 제자리로 (`Part.shake`)
- **막고 있는 부품이 붉게 점등**한다 (`Part.flash_blocker`)
- `clack` 효과음 + 햅틱

무엇이 막고 있는지 말로 알려주지 않고 그 부품을 가리킨다.

---

## 3. 구조

```
game/scripts/
  core/        debug_flags · haptics · debug_overlay · capture_runner
  camera/      orbit_camera
  interaction/ touch_router · part_interaction(기반) · pull · rotate · hold
  puzzle/      part_def · stage_def · puzzle_engine
  device/      device_rig · part
  ui/          hud · part_tray · progress_ring · ui_style
  audio/       sfx
  game.gd      위의 것들을 잇는 조립 지점
```

책임 분리:

- **`PuzzleEngine`** 이 판정의 단일 진실이다. 노드를 모른다. Physics 를 안 쓴다
  (기획서 5번). 제거 가능 여부는 `blocked_by` 가 전부 빠졌는지로만 결정된다.
- **`Part`** 는 "어떻게 보이고 어떻게 반응하는가"만 안다. 퍼즐 규칙이 없다.
- **`TouchRouter`** 가 입력 해석을 독점한다. 부품 위면 조작, 빈 곳이면 카메라,
  두 손가락이면 핀치.
- **`DeviceRig`** 가 GLB 를 읽어 데이터에 적힌 부품만 `Part` 로 감싼다.
  GLB 는 아무것도 모르는 모델로 남는다 (기획서 9번).

---

## 4. 새 스테이지 추가하기

코드를 고치지 않는다 (기획서 10번).

1. Blender 로 장치를 만들고 **부품마다 독립 Object** 로 이름을 붙인다
2. `game/assets/models/device_XXX.glb` 로 export
3. `game/resources/stages/stage_XXX.json` 작성
4. `game.gd` 의 `STAGE_PATH` 만 바꾸면 그 스테이지가 돈다

`StageDef.load_from()` 이 읽을 때 검증한다:

- `blocked_by` 가 없는 부품을 가리키면 → 에러
- 의존 관계에 **순환**이 있으면 → 에러 (안 그러면 절대 안 풀리는 스테이지가
  조용히 만들어진다)
- GLB 에 해당 이름의 메시가 없으면 → 에러

### 부품 정의 필드

| 필드 | 설명 |
|---|---|
| `id` | GLB 의 Object 이름과 **정확히** 같아야 한다 |
| `interaction` | `pull` / `rotate` / `hold` |
| `blocked_by` | 이것들이 다 빠져야 열린다 |
| `remove_direction` | 빠지는 방향 (Godot 좌표, Y-up) |
| `remove_distance` | 이만큼 당기면 빠진다 |
| `resist_distance` | 막혔을 때 끌려오는 거리 |
| `rotation_axis` / `rotation_target` | 회전축과 목표 각(부호가 방향) |
| `resist_angle` | 막혔을 때 덜컹거리는 각 |
| `hold_seconds` | 누르고 있어야 하는 시간 |
| `is_core` | true 면 트레이로 안 가고 안정화 연출로 간다 |

---

## 5. 작업하다 걸린 것들

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

## 6. 개발 도구

| | |
|---|---|
| `F1` | 디버그 오버레이 (FPS, 드로우콜, 부품별 상태와 `blocked_by`) |
| `F2` | 픽 범위 표시 |
| `F5` | 리셋 |
| 오버레이 버튼 | 강제 제거 · 코어 개방 · 리셋 · 픽 범위 |

릴리스 빌드에서는 `DebugFlags.available` 이 false 라 오버레이가 트리에 붙지도 않는다.

### 화면 캡처 하네스

실기기 없이 단계별 그림을 뽑는다.

```bash
godot --path game --resolution 530x942 -- --shot out.png            # 시작 화면
godot --path game --resolution 530x942 -- --shot out.png --remove 3 # 3개 뺀 상태
godot --path game --resolution 530x942 -- --shot out.png --clear    # 클리어까지
```

---

## 7. 개발 환경 (2026-09-27 확인)

| | |
|---|---|
| Godot | 4.7.1 stable + Android export template 설치됨 |
| Blender | 5.2.1 LTS |
| JDK | 17 (Homebrew) |
| Android SDK | `~/Library/Android/sdk` (`ANDROID_HOME` 미설정) |
| ADB | 1.0.41 |
| m.flux | `~/mflux-lab/.venv/bin/mflux-generate` |
| Blender MCP | 없음 — 헤드리스 파이썬 스크립트로 대체 |

---

## 8. 다음

1. **실기기에서 만져 보기.** 당기는 거리, 돌리는 저항, 햅틱 세기는 화면으로
   판단할 수 없다. 이게 재미없으면 콘텐츠를 늘리지 않는다 (기획서 18번).
2. 효과음을 진짜 폴리로 교체 (지금은 합성한 임시음, 파일 이름만 맞추면 됨)
3. 장치 모델 품질 올리기 — 노멀맵, 텍스처. 시안 수준과의 거리가 가장 큰 리스크
4. DEVICE_002 로 데이터 기반 구조가 정말 코드 수정 없이 되는지 검증
