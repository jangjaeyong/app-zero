# ZERO — Disassemble to Discover

3D 장치 해체 퍼즐. Godot 4.7 / Android 세로(9:16) / 패키지 `com.drake.zero`.

기획 원문은 [`docs/prompts.md`](docs/prompts.md), 디자인 시안은 `docs/*.png`.
구현 구조와 함정은 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## 지금 상태

**챕터 2개 · 스테이지 6판.** 메인 → 스테이지 선택 → 플레이 → 클리어 →
다음 스테이지가 한 바퀴 돌고, 진행·별·설정이 저장된다.

### 챕터 1 — WORKSHOP (노멀)

| | 장치 | 부품 | 조작 |
|---|---|---|---|
| 01 | MK-01 CONTAINMENT UNIT | 8 | Pull ×5 · Rotate ×2 · Press |
| 02 | MK-02 PRESSURE DRUM | 8 | Pull ×3 · Slide ×2 · Press ×2 · Rotate |
| 03 | MK-03 CALIBRATION CELL | 7 | Pull ×2 · Align ×2 · Slide ×2 · Press |
| 04 | MK-04 ROUTING JUNCTION | 7 | Sequence ×3 · Route · Multi-step · Pull ×2 · Press |

### 챕터 2 — REACTOR ROOM (위험 · 보스)

| | 장치 | 모드 | 제한 |
|---|---|---|---|
| 01 | MK-02R OVERHEATED DRUM | DANGER | 140초 · 틀리면 −6초 |
| 02 | MK-04X PRIME JUNCTION | BOSS | 260초 · 여러 단계 부품 |

챕터 2 는 **모델을 새로 만들지 않았다.** 같은 GLB 에 데이터만 다르게 준 판이다.

### 조작 — 기획서 9종 중 7종

Pull · Slide · Rotate · Align · Press · Route · Sequence, 그리고 Multi-step
(한 부품을 여러 단계로).
**아직 없는 것:** Hold(두 손가락으로 하나를 고정하고 다른 것을 조작).

### 긴장 구조

틀린 시도는 **불안정도**를 올리고 올바른 수는 내린다.
78% 에서 열어 둔 잠금 하나가 다시 걸리고, 100% 에서 과부하로 둘이 되돌려지며
별 하나를 잃는다. 노멀에서 게임오버는 없다 (기획서 13번).

**시간으로는 올리지 않는다.** 퍼즐은 오래 들여다보는 게임이다. 가만히 보는
사람을 벌주면 관찰이 손해가 된다. 시간 압박은 위험·보스 모드에만 있다.

되돌리기·힌트는 각각 3개 (시안 기준).

### 아직 없음

재화 · 상점 · 컬렉션 · 광고 · Daily 모드 · AAB 배포 설정 ·
챕터 3~5 의 내용물 · 두 손가락 Hold.

## 실행

```bash
godot --path game                          # 플레이
godot --headless --import --path game      # 에셋 다시 가져오기
godot --headless --path game -- --validate # 스테이지·스크립트 검증
```

개발 빌드 단축키: `F1` 디버그 오버레이 · `F2` 픽 범위 · `F5` 리셋 · `ESC` 일시정지.

## 에셋 다시 만들기

```bash
blender -b -P tools/build_device_001.py   # 장치 모델 (002~004 도 같은 방식)
python3 tools/make_textures.py            # 표면 디테일 (노멀·거칠기·때)
python3 tools/make_fx_textures.py         # 보케 · 연기 · 불꽃
python3 tools/make_sfx.py                 # 효과음 11종
python3 tools/make_icons.py               # 런처 아이콘 4종
```

전부 결정적이다. 소스는 스크립트고, GLB·PNG·WAV 는 산출물이다.
공통 조립 헬퍼는 `tools/zero_blender.py`.

## 새 스테이지 추가

코드를 고치지 않는다.

1. `tools/build_device_XXX.py` 로 GLB 를 만든다 (부품마다 독립 Object)
2. `game/resources/stages/stage_XXX.json` 을 쓴다
3. `game/resources/stages/chapters.json` 의 챕터에 경로를 넣는다
4. `godot --headless --path game -- --validate` 로 확인한다

## 폴더

```
docs/     기획서, 시안, 개발 문서
game/     Godot 프로젝트 루트 (project.godot)
tools/    Blender / 텍스처 / 오디오 / 아이콘 생성 스크립트
```
