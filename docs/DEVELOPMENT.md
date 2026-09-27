# ZERO 개발 문서

챕터 1 (스테이지 3개) 시점 기준.

---

## 1. 무엇을 만들었나

버티컬 슬라이스(DEVICE_001)로 손맛을 검증한 뒤, 챕터 1 을 스테이지 3개까지
넓혔다. 메인 화면 → 스테이지 선택 → 플레이 → 클리어 → 다음 스테이지가
한 바퀴 돌고, 진행과 별이 저장된다.

재화·상점·컬렉션·광고·데일리·Danger/Boss 는 여전히 만들지 않았다
(기획서 15·17번). 게임 자체부터 완성한다.

### 조작법이 느는 방식 (기획서 3번)

| 스테이지 | 장치 | 부품 | 조작 |
|---|---|---|---|
| 01 | MK-01 CONTAINMENT UNIT | 8 | Pull ×5 · Rotate ×2 · Hold |
| 02 | MK-02 PRESSURE DRUM | 8 | Pull ×3 · **Slide ×2** · **Press** · Rotate · Hold |
| 03 | MK-03 CALIBRATION CELL | 7 | Pull ×2 · **Align ×2** · Slide ×2 · Hold |

새 조작은 익숙한 조작 몇 번 뒤에 나온다. 한 스테이지에 새 조작을 둘 이상
넣지 않는다.

### 해결 방식 두 가지

`PartDef.Resolve` 가 조작이 끝난 뒤 부품이 어떻게 되는지를 정한다.

- **REMOVE** — 장치에서 빠져 트레이로 간다 (패널, 셀, 커버)
- **SETTLE** — 제자리에 남는다. 밀린 걸쇠, 눌린 버튼, 맞춰진 다이얼

둘 다 "해결됨" 이고 둘 다 남의 `blocked_by` 를 푼다. 이걸 나누기 전에는
"빼는 것" 만 퍼즐이 될 수 있었다.

### Rotate 와 Align 의 차이

- **Rotate** — *얼마나* 돌렸는가. 목표 각만큼 돌면 자동으로 풀린다
- **Align** — *어디에* 세웠는가. 목표 눈금 오차 안에서 **손을 떼야** 걸린다.
  빗나가면 되돌아가지 않고 그 자리에 남아 조금씩 고쳐 잡을 수 있다

Align 은 목표를 눈으로 볼 수 있어야 성립한다. DEVICE_003 은 섀시 상판에
눈금을 새기고 목표 눈금 하나만 시안으로 발광시킨다.

---

## 2. 퍼즐 설계 — DEVICE_001

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
  core/        debug_flags · haptics · debug_overlay · dev_harness
               progress_store(저장) · session(화면 전환)
  camera/      orbit_camera
  interaction/ touch_router · part_interaction(기반)
               pull · slide · rotate · align · press · hold
  puzzle/      part_def · stage_def · stage_catalog · puzzle_engine
  device/      device_rig · part
  ui/          hud · main_menu · stage_select · part_tray
               progress_ring · ui_style
  audio/       sfx
  game.gd      위의 것들을 잇는 조립 지점
```

오토로드: `Sfx` `Haptics` `DebugFlags` `Progress` `Session` `DevTools`.

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

코드를 고치지 않는다 (기획서 10번). **DEVICE_002 를 이 방식으로만 추가했고
GDScript 는 한 줄도 안 고쳤다.** 주장이 아니라 확인된 사실이다.

1. `tools/build_device_XXX.py` 작성 — `zero_blender` 헬퍼를 import 하고
   **부품마다 독립 Object** 로 이름을 붙인다
2. `blender -b -P tools/build_device_XXX.py` 로 GLB 생성
3. `game/resources/stages/stage_XXX.json` 작성
4. `game/resources/stages/chapters.json` 의 챕터 `stages` 에 경로 추가
5. `godot --headless --path game -- --validate` 로 확인

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
| `resolve` | `remove`(빠짐) / `settle`(제자리에 남음). 안 적으면 조작 종류가 정한다 |
| `slide_direction` / `slide_distance` | 밀기. `remove_*` 의 읽기 좋은 별칭 |
| `align_tolerance` / `align_range` | 맞추기의 허용 오차와 돌릴 수 있는 범위 |
| `press_depth` | 누르기에서 버튼이 들어가는 깊이 |

스테이지 최상위에 `camera` 를 넣으면 구도를 지정한다
(`distance` `pitch` `yaw` `height` `min` `max`). 장치 크기가 제각각이라
한 구도로는 어떤 건 잘리고 어떤 건 작다.

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

### 스테이지 검증기

```bash
godot --headless --path game -- --validate
```

모든 스테이지에 대해 확인한다.

- GLB 에 부품·정적 노드 메시가 실제로 있는가
- 의존 관계를 따라가면 **정말 끝까지 풀리는가**
- 기준 수가 부품 수보다 적지 않은가 (별 3개가 가능한가)
- 코어가 정확히 하나인가

`StageDef.load_from()` 이 읽을 때 `blocked_by` 오타와 **순환**도 따로 잡는다.
스테이지가 늘어나면 손으로 확인할 수 없다. 데이터가 게임을 정의하니
데이터가 틀리면 조용히 못 푸는 판이 나온다.

### 화면 캡처 하네스

실기기 없이 화면별 그림을 뽑는다.

```bash
godot --path game --resolution 530x942 -- --shot a.png
godot --path game --resolution 530x942 -- --shot b.png --goto select
godot --path game --resolution 530x942 -- --shot c.png \
    --goto game --stage res://resources/stages/stage_002.json --remove 3
godot --path game --resolution 530x942 -- --shot d.png --goto game --clear
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

1. **새 조작 셋을 실기기에서 확인.** Slide·Press·Align 은 논리는 맞는데
   손맛은 아직 아무도 안 만져 봤다. 특히 Align 은 "목표가 눈으로 읽히는가" 가
   전부다 — 안 읽히면 눈금 디자인을 다시 해야 한다.
2. 챕터 1 을 12스테이지까지 (시안 기준). 장치 9개가 더 필요하다
3. 효과음을 진짜 폴리로 교체 (지금은 합성한 임시음, 파일 이름만 맞추면 됨)
4. 장치 모델 품질 — 노멀맵, 텍스처. **시안 수준과의 거리가 여전히 가장 큰 리스크**
5. 챕터 선택을 시안 2 의 3D 맵으로. 스테이지가 쌓인 뒤에 한다
