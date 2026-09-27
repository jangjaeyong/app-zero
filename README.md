# ZERO — Disassemble to Discover

3D 장치 해체 퍼즐. Godot 4.7 / Android 세로(9:16) / 패키지 `com.drake.zero`.

기획 원문은 [`docs/prompts.md`](docs/prompts.md), 디자인 시안은 `docs/*.png`.
구현 구조와 작업 방법은 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## 지금 상태

**챕터 1 — WORKSHOP, 스테이지 3개.** 메인 화면 → 스테이지 선택 → 플레이 →
클리어 → 다음 스테이지까지 한 바퀴가 돈다. 진행과 별은 저장된다.

| 스테이지 | 장치 | 부품 | 조작 |
|---|---|---|---|
| 01 | MK-01 CONTAINMENT UNIT | 8 | Pull ×5 · Rotate ×2 · Press |
| 02 | MK-02 PRESSURE DRUM | 8 | Pull ×3 · **Slide ×2** · Press ×2 · Rotate |
| 03 | MK-03 CALIBRATION CELL | 7 | Pull ×2 · **Align ×2** · Slide ×2 · Press |

조작법이 스테이지마다 하나씩 늘어난다 (기획서 3번).
기획서의 9종 중 **Pull · Rotate · Slide · Press · Align** 5종이 들어갔다.
Hold(두 손가락) · Route · Sequence · Multi-step 은 아직 없다.

### 긴장 구조

틀린 시도는 **불안정도**를 올린다. 올바른 수는 내린다. 78% 에서 열어 둔 잠금
하나가 다시 걸리고, 100% 에서 과부하로 둘이 되돌려지며 별 하나를 잃는다.
노멀에서 게임오버는 없다 (기획서 13번).

시간으로는 올리지 않는다. 퍼즐은 오래 들여다보는 게임이고, 가만히 보는 사람을
벌주면 안 된다. **틀린 행동만** 대가를 치른다.

되돌리기·힌트는 각각 3개다 (시안 기준).

**아직 없음:** 재화 · 상점 · 컬렉션 · 광고 · 데일리 · Danger/Boss 모드 ·
설정 버튼 · Assist · AAB 배포 설정 · 챕터 2~5 의 내용물 ·
**노멀맵 · 텍스처 · 배경 · 파티클**(기획서 8번. 시안과의 가장 큰 격차).

## 실행

```bash
godot --path game                          # 플레이
godot --headless --import --path game      # 에셋 다시 가져오기
godot --headless --path game -- --validate # 스테이지 데이터 검증
```

개발 빌드 단축키: `F1` 디버그 오버레이 · `F2` 픽 범위 · `F5` 리셋.

## 에셋 다시 만들기

```bash
blender -b -P tools/build_device_001.py   # 장치 모델 (002, 003 도 같은 방식)
python3 tools/make_sfx.py                 # 효과음 8종
python3 tools/make_icons.py               # 런처 아이콘 4종
```

전부 결정적이다. 소스는 스크립트고, GLB·WAV·PNG 는 산출물이다.
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
tools/    Blender / 오디오 / 아이콘 생성 스크립트
```
