# ZERO 개발 문서

챕터 2개 · 스테이지 6판 시점 (2026-09-27).

---

## 1. 무엇을 만들었나

버티컬 슬라이스로 손맛을 검증하고, 조작을 7종까지 늘리고, 긴장 구조를 넣고,
그래픽을 한 번 올렸다. 지금은 챕터 2개 · 6판이 돈다.

재화·상점·컬렉션·광고·Daily 는 여전히 만들지 않았다 (기획서 15·17번).

### 조작법이 느는 방식 (기획서 3번)

| 스테이지 | 장치 | 부품 | 조작 |
|---|---|---|---|
| 01 | MK-01 CONTAINMENT UNIT | 8 | Pull ×5 · Rotate ×2 · Press |
| 02 | MK-02 PRESSURE DRUM | 8 | Pull ×3 · **Slide ×2** · Press ×2 · Rotate |
| 03 | MK-03 CALIBRATION CELL | 7 | Pull ×2 · **Align ×2** · Slide ×2 · Press |
| 04 | MK-04 ROUTING JUNCTION | 7 | **Sequence ×3** · **Route** · **Multi-step** · Pull ×2 |
| 챕터2-01 | MK-02R OVERHEATED DRUM | 8 | DANGER · 140초 |
| 챕터2-02 | MK-04X PRIME JUNCTION | 7 | BOSS · 260초 · 여러 단계 |

챕터 2 는 **모델을 새로 만들지 않았다.** 같은 GLB 에 데이터만 다르게 준 판이다.
스테이지 60판을 채울 때 이 방식이 크게 작용한다.

새 조작은 익숙한 조작 몇 번 뒤에 나온다. 한 스테이지에 새 조작을 둘 이상
넣지 않는다.

### 해결 방식 두 가지

`PartDef.Resolve` 가 조작이 끝난 뒤 부품이 어떻게 되는지를 정한다.

- **REMOVE** — 장치에서 빠져 트레이로 간다 (패널, 셀, 커버)
- **SETTLE** — 제자리에 남는다. 밀린 걸쇠, 눌린 버튼, 맞춰진 다이얼

둘 다 "해결됨" 이고 둘 다 남의 `blocked_by` 를 푼다. 이걸 나누기 전에는
"빼는 것" 만 퍼즐이 될 수 있었다.

### 긴장은 실패의 대가에서 나온다

처음 버전은 틀린 시도가 공짜였다. 그러니 "다 눌러보기" 가 최적 전략이 되고,
부품 여덟 개를 전부 당겨 보는 데 5초면 되니 생각할 이유가 사라졌다.
기획서가 원한 "관찰 → 시도 → 피드백 → 이해 → 해결" 이 "시도 → 시도 → 시도" 로
무너졌다. **기획서 13번의 "즉시 게임오버시키지 않는다" 를 "아무 일도 일어나지
않는다" 로 읽은 것이 원인이었다.**

`Instability` 가 그 대가를 맡는다.

- 틀린 시도마다 오른다. 같은 부품을 또 억지로 당기면 더 오른다
- 올바른 수를 두면 내려간다. 잘 풀면 장치가 진정된다
- **시간으로는 올리지 않는다.** 퍼즐은 오래 들여다보는 게임이다.
  가만히 보는 사람을 벌주면 관찰이 손해가 된다
- 50% 경고 · 78% 잠금 하나 재걸림 · 100% 과부하(둘 되돌림 + 별 하나)
- 노멀에서 게임오버는 없다

되돌리기·힌트도 각각 3개다. 무제한이면 고민할 이유가 없다.

### Press 는 "길게 누름" 이다 — 내가 잘못 읽었던 것

기획서 3번은 이렇게 적혀 있다.

- **Press** — 버튼이나 잠금 장치를 **길게** 누름
- **Hold** — 한 부품을 **고정하면서** 다른 부품 조작 (두 손가락)

나는 Press 를 톡 누르기로, Hold 를 길게 누르기로 만들어 둘 다 어겼다.
Press 를 길게 누르기로 고쳤고(진행 링 + 실제로 들어가는 버튼),
두 손가락 Hold 는 아직 없다. `hold` 라는 이름은 예전 데이터 호환을 위해
press 로 매핑만 남겼다.

### 조작 7종의 차이

| 조작 | 무엇을 보는가 | 끝나면 |
|---|---|---|
| Pull | 얼마나 당겼는가 | 빠져서 트레이로 |
| Slide | 끝까지 밀었는가 | **제자리에 걸림** |
| Rotate | 얼마나 돌렸는가 | 빠짐 |
| Align | **어디에 세웠는가** | 제자리에 맞춰짐 |
| Press | 얼마나 오래 눌렀는가 | 제자리에 눌림 |
| Route | **경로를 따라갔는가** | 단자에 꽂힘 |
| Sequence | **순서가 맞는가** | 눌림 (틀리면 그룹 전체 초기화) |

Multi-step 은 조작이 아니라 **묶음**이다. `PartDef.steps` 에 단계마다 제 조작과
값을 둔다. 단계는 부모 값을 물려받고 적힌 것만 덮어쓰므로 매번 다 안 적어도 된다.
조작 클래스들은 `part.def` 가 아니라 **`part.params()`** 를 읽는다 —
단계마다 방향·거리·조작이 다르기 때문이다.

### Route 의 판정은 화면에서 한다

경로 점들을 화면에 투영해 꺾은선을 만들고, 손가락이 그 위 어디쯤인지를 잰다.
카메라가 어느 각도에 있든 똑같이 동작하고 3D 평면 투영을 안 해도 된다.
경로에서 `DEVIATE_PX` 넘게 벗어나면 부품이 따라오지 않는다.

**Route 는 목표가 눈에 보여야 성립한다.** MK-04 는 뒷벽에 홈을 파 넣고
끝에 단자를 시안으로 밝혔다.

### Sequence 는 한 번 보여 준다

외우라고만 하면 불친절하다. 그룹이 열리는 순간 순서대로 한 번 점등한다
(사이먼 게임과 같은 약속). 틀리면 그룹이 통째로 처음으로 돌아가고
**쓴 수는 돌려주지 않는다.**

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

## 3. 모드 (기획서 14번)

스테이지 JSON 의 `mode` 와 `time_limit` 이 정한다.

- **normal** — 시간 제한 없음. 게임오버 없음
- **danger** — 제한 시간 + **틀린 시도마다 시간이 깎인다** (기획서 13번 "시간 페널티")
- **boss** — 거기에 배너와 여러 단계 부품이 더 붙는다

제한 시간이 있으면 HUD 가 MOVES 를 접고 그 자리에 시계를 띄운다.
위험 모드에서 플레이어가 봐야 할 숫자는 남은 시간이다.
시간이 다 되면 `CONTAINMENT FAILED`.

## 4. 그래픽

### 표면 디테일 — UV 를 펴지 않는다

장치를 60개 깎아야 하는데 Blender 에서 UV 를 일일이 펴면 장치당 반나절이
날아간다. Godot 의 **삼중평면(triplanar) 매핑**은 좌표만으로 텍스처를 감는다.
대신 타일링이 완벽해야 해서 격자 인덱스를 모듈러로 감은 노이즈를 쓴다
(`tools/make_textures.py`).

`MaterialDresser` 가 재질 이름(M_Panel, M_Gun, M_Steel, …)별로 다른 세기를
입히고, `DeviceRig` 가 부품과 정적 구조물 전부에 자동으로 부른다.
**새 장치를 만들 때 할 일이 없다.**

### 배경

멀리 있는 장비 실루엣 + 초점 나간 불빛 (`scripts/world/backdrop.gd`).
실루엣은 무조명이고 불빛은 빌보드 쿼드 한 장씩이다. 안개가 멀수록 지워 준다.

### 파티클

코어 증기는 늘 있고 불안정도에 따라 양·속도·색이 바뀐다.
과부하 때만 불꽃이 터진다. **늘 있는 효과는 아무 의미도 전달하지 못한다.**

## 5. 구조

```
game/scripts/
  core/        debug_flags · haptics · debug_overlay · dev_harness
               progress_store · settings_store · session
  camera/      orbit_camera
  interaction/ touch_router · part_interaction(기반)
               pull · slide · rotate · align · press · route · sequence
  puzzle/      part_def · stage_def · stage_catalog · puzzle_engine · instability
  device/      device_rig · part · material_dresser · device_fx
  world/       backdrop
  ui/          hud · main_menu · stage_select · settings_panel
               part_tray · progress_ring · instability_bar · safe_area · ui_style
  audio/       sfx
  game.gd      위의 것들을 잇는 조립 지점
```

오토로드: `Sfx` `Haptics` `DebugFlags` `Progress` `Settings` `Session` `DevTools`.

책임 분리:

- **`PuzzleEngine`** 이 판정의 단일 진실이다. 노드를 모른다. Physics 를 안 쓴다
  (기획서 5번). 제거 가능 여부는 `blocked_by` 가 전부 빠졌는지로만 결정된다.
- **`Part`** 는 "어떻게 보이고 어떻게 반응하는가"만 안다. 퍼즐 규칙이 없다.
- **`TouchRouter`** 가 입력 해석을 독점한다. 부품 위면 조작, 빈 곳이면 카메라,
  두 손가락이면 핀치.
- **`DeviceRig`** 가 GLB 를 읽어 데이터에 적힌 부품만 `Part` 로 감싼다.
  GLB 는 아무것도 모르는 모델로 남는다 (기획서 9번).

---

## 5-1. 새 스테이지 추가하기

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

## 7. 개발 도구

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

- **조작 클래스 7종이 컴파일되는가** (게임 씬을 열기 전에 잡는다)
- GLB 에 부품·정적 노드 메시가 실제로 있는가
- 의존 관계를 따라가면 **정말 끝까지 풀리는가**
- 기준 수가 부품 수보다 적지 않은가 (별 3개가 가능한가)
- 코어가 정확히 하나인가
- 경로 점이 2개 이상인가
- **순서 그룹 번호가 0부터 빠짐없이 이어지는가** (하나라도 비면 영원히 안 끝난다)

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

## 8. 기획서 대조 — 아직 안 된 것 (2026-09-27 갱신)

- **Hold** — 한 부품을 고정하면서 다른 부품 조작 (두 손가락).
  핀치 줌과 손가락이 겹쳐서 구분 규칙을 먼저 정해야 한다
- **AAB 배포 구조** — 형님 지시로 보류. 스토어 올리기 직전에 한다
- **Daily Device** (기획서 14번)
- **Assist 버튼** (기획서 15번 하단 3개 중 하나). 무엇을 하는 건지 정해야 한다
- **"연결된 다른 부품이 같이 움직임"** 피드백 (기획서 4번)
- **이동 횟수 증가** 페널티 (기획서 13번)
- 챕터 3~5 의 내용물
- m.flux 미사용 — 텍스처·컨셉 생성에 쓸 수 있다
- Collision Shape 표시는 와이어프레임이 아니라 부품 외곽선으로 대신함

## 9. 다음

1. **새 조작 셋을 실기기에서 확인.** Slide·Press·Align 은 논리는 맞는데
   손맛은 아직 아무도 안 만져 봤다. 특히 Align 은 "목표가 눈으로 읽히는가" 가
   전부다 — 안 읽히면 눈금 디자인을 다시 해야 한다.
2. 챕터 1 을 12스테이지까지 (시안 기준). 장치 9개가 더 필요하다
3. 효과음을 진짜 폴리로 교체 (지금은 합성한 임시음, 파일 이름만 맞추면 됨)
4. 장치 모델 품질 — 노멀맵, 텍스처. **시안 수준과의 거리가 여전히 가장 큰 리스크**
5. 챕터 선택을 시안 2 의 3D 맵으로. 스테이지가 쌓인 뒤에 한다
