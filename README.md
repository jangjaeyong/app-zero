# ZERO — Disassemble to Discover

3D 장치 해체 퍼즐. Godot 4.7 / Android 세로(9:16) / 패키지 `com.drake.zero`.

기획 원문은 [`docs/prompts.md`](docs/prompts.md), 디자인 시안은 `docs/*.png`.
구현 구조와 작업 방법은 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## 지금 상태

**DEVICE_001 버티컬 슬라이스 1개.** 8수짜리 퍼즐 하나가 처음부터 STAGE CLEAR 까지 돈다.

| | |
|---|---|
| 조작 | Pull(4) · Rotate(2) · Hold(1) |
| 부품 | 8개 + 정적 구조물 4개 |
| 구현됨 | 의존 규칙, 걸림 연출, 트레이 수납, 되돌리기, 힌트, 성공 연출, 효과음, 디버그 오버레이 |
| 아직 없음 | 챕터/맵, 재화, 상점, 광고, 컬렉션, 데일리, Danger/Boss 모드 |

## 실행

```bash
godot --path game                       # 플레이
godot --headless --import --path game   # 에셋 다시 가져오기
```

개발 빌드 단축키: `F1` 디버그 오버레이 · `F2` 픽 범위 표시 · `F5` 리셋.

## 에셋 다시 만들기

```bash
blender -b -P tools/build_device_001.py   # 장치 모델 → game/assets/models/device_001.glb
python3 tools/make_sfx.py                 # 효과음 8종 → game/assets/audio/
```

둘 다 결정적이다. 소스는 스크립트고, GLB 와 WAV 는 산출물이다.

## 폴더

```
docs/     기획서, 시안, 개발 문서
game/     Godot 프로젝트 루트 (project.godot)
tools/    Blender / 오디오 생성 스크립트
```
