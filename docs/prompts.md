ZERO — 3D Disassembly Puzzle Game

새로운 Android 모바일 퍼즐 게임을 개발해줘.

게임명은 우선 ZERO로 사용한다.

이 프로젝트는 기존의 나사풀기(Screw Puzzle) 게임이 가진 핵심 재미인

- 복잡한 구조를 관찰한다.
- 어떤 부품부터 제거해야 하는지 판단한다.
- 하나씩 제거하면서 내부 구조가 드러난다.
- 화면이 점점 정리된다.
- 마지막 핵심 장치를 해제했을 때 큰 만족감을 준다.

라는 경험을 가져오되, 나사풀기 게임을 복제해서는 안 된다.

ZERO만의 새로운 게임 메커니즘을 가진 3D 장치 해체 퍼즐로 개발한다.

---

1. 기술 스택

게임 엔진:

- Godot 4.x 최신 안정 버전
- GDScript 중심

플랫폼:

- Android 우선
- 세로 화면 Portrait
- 기본 목표 비율 9:16
- 추후 다양한 Android 해상도 대응
- Google Play AAB 배포 가능 구조

Android 패키지명:

"com.drake.zero"

3D 에셋:

- Blender
- ".glb / glTF" 기반

그래픽 레퍼런스 제작:

- 로컬 m.flux 활용 가능
- 필요하다면 디자인 컨셉 이미지나 텍스처 제작용 프롬프트를 별도 작성

Blender 작업 자동화가 필요한 경우 현재 환경에서 사용할 수 있는 Blender MCP가 있는지 먼저 확인하고 활용한다.

---

2. 게임의 핵심

이 게임은 실제 폭탄 해체 시뮬레이터가 아니다.

실제 폭발물 구조나 현실의 해체 방법을 구현하지 않는다.

모든 장치는 완전히 가상의 SF 장치다.

게임의 핵심은

Disassemble to Discover

즉,

«복잡한 장치를 관찰하고, 구조를 이해하고, 올바른 방법으로 하나씩 분해하여 내부의 Core를 해제하는 것»

이다.

---

3. 가장 중요한 차별점

단순히

"부품 터치 → 제거"

게임으로 만들지 마라.

각 부품마다 서로 다른 조작 방식을 적용한다.

예:

Pull

손가락으로 특정 방향으로 당겨 제거.

Rotate

링이나 레버를 회전시켜 잠금 해제.

Slide

부품을 레일 방향으로 밀어 이동.

Press

버튼이나 잠금 장치를 길게 누름.

Hold

한 부품을 고정하면서 다른 부품 조작.

Align

여러 마크 또는 기어를 올바른 위치로 정렬.

Route

케이블이나 파이프를 정해진 경로를 따라 이동.

Sequence

특정 순서로 장치를 작동.

Multi-step

하나의 부품도 여러 단계 조작 후 제거.

단, 처음부터 모든 조작을 넣지는 않는다.

초기 스테이지에서는 한두 가지 조작만 사용하고,
진행하면서 새로운 조작법이 자연스럽게 추가되도록 설계한다.

---

4. 퍼즐의 핵심 구조

부품마다 의존 관계가 존재해야 한다.

예:

TopCover
 ├ blocked_by: LockRing
 └ blocked_by: SideLatch

LockRing
 └ blocked_by: CoolingTube

CoolingTube
 └ blocked_by: PowerCell

따라서 플레이어가 TopCover를 먼저 당기면

조금 움직이다가

덜컥

하고 걸려야 한다.

단순히

"제거할 수 없습니다"

팝업을 띄우는 방식은 피한다.

게임 세계 안에서 자연스럽게 실패를 표현한다.

예:

- 걸림
- 흔들림
- 작은 진동
- 잠금장치 점등
- 마찰음
- 연결된 다른 부품이 같이 움직임

플레이어가 스스로

«아, 다른 게 막고 있구나.»

라고 깨닫게 만드는 것이 중요하다.

---

5. 실제 Physics 의존 금지

게임이 물리적으로 보여야 하지만 퍼즐 판정을 실제 Physics에 전부 맡기지 않는다.

핵심 퍼즐은

State Machine + Rule System

으로 구현한다.

Physics는 연출 보조로만 사용한다.

예:

사용자가 패널을 잡음
↓
제거 조건 검사
↓
조건 불충족
→ 조금 움직임
→ 걸리는 애니메이션
→ 원위치

조건 충족
→ 잠금음
→ 패널 분리
→ 손가락을 따라 이동
→ 놓으면 수납 위치로 이동
→ 다음 상태 활성화

퍼즐이 Physics 버그 때문에 깨지지 않도록 설계해야 한다.

---

6. 핵심 게임 화면

세로 화면 중앙 대부분을 하나의 3D 장치가 차지한다.

플레이어는 손가락으로 장치를 조작한다.

기본 조작:

- 한 손가락 드래그 → 장치 회전
- 핀치 → 확대/축소
- 부품 탭 → 선택
- 부품 드래그 → 당기기/밀기
- 원형 드래그 → 회전
- 필요하면 Long Press 사용

카메라는 지나치게 자유롭게 만들지 않는다.

퍼즐하기 좋은 범위로 제한한다.

---

7. 비주얼 스타일

게임의 비주얼은 매우 중요하다.

단순 모바일 퍼즐 UI처럼 만들지 않는다.

목표:

Premium Casual Puzzle + Beautiful Mechanical Toy

느낌.

주요 색상:

- Dark Navy / Black
- Metallic White
- Gunmetal
- Cyan / Electric Blue
- Warm Amber

위험 스테이지:

- Red accent 추가

장치는 장난감처럼 만지고 싶고,
수집하고 싶고,
내부를 보고 싶게 만들어야 한다.

참고 분위기:

- 정밀 기계
- 프리미엄 전자제품
- SF 연구 장치
- 작은 원자로
- 기계식 퍼즐 박스

하지만 지나치게 어둡거나 공포스럽게 만들지 않는다.

---

8. 그래픽 구현 전략

모바일이므로 모든 것을 고사양 실시간 효과로 만들지 않는다.

실제 3D:

- Device Body
- Panels
- Ring
- Power Cell
- Cable
- Gear
- Core
- 주요 퍼즐 부품

비용 절감:

- 작은 표면 디테일 → Normal Map
- 긁힘/금속감 → Texture
- 배경 → 단순화된 3D 또는 이미지
- 반사 → 제한적
- 그림자 → 최적화
- Particle → 필요한 순간만
- Bloom → 과도하게 사용 금지

Godot Mobile Renderer 기준으로 개발한다.

저사양 Android도 고려한다.

---

9. 장치 구조

Blender에서 부품을 각각 독립적인 Object로 만든다.

예:

DEVICE_001
 ├ Body
 ├ TopCover
 ├ LeftPanel
 ├ RightPanel
 ├ LockRing
 ├ PowerCell
 ├ CoolingTube
 ├ GearLock
 └ EnergyCore

GLB로 export 후 Godot에서도 동일한 구조를 유지한다.

Godot에서는 3D 모델 자체에 퍼즐 로직을 하드코딩하지 말고,

데이터와 로직을 분리한다.

---

10. 데이터 기반 스테이지

스테이지 추가 시 코드를 수정해야 하는 구조를 피한다.

가능하면 Resource 또는 JSON 등의 데이터 기반으로 설계한다.

예:

Part:
id
type
interaction_type
blocked_by
requires
initial_state
success_state
remove_direction
rotation_limit
animation
sound
next_actions

스테이지:

Stage
 ├ Device
 ├ Parts
 ├ DependencyRules
 ├ WinCondition
 ├ FailCondition
 └ Rewards

장기적으로

새 GLB + 퍼즐 데이터

만 추가하면 새로운 스테이지를 만들 수 있게 한다.

---

11. 초기 플레이 흐름

첫 번째 프로토타입에서는 거대한 콘텐츠를 만들지 마라.

먼저 Vertical Slice 1개를 완성한다.

DEVICE_001 하나.

구성 예:

Top Cover
Side Cover
Power Cell
Blue Cooling Tube
Lock Ring
Gear Lock
Energy Core

퍼즐 흐름의 예시는 참고만 하고,
더 재미있는 구조가 있으면 변경해도 된다.

예:

Power Cell 제거
↓
Cooling Tube 이동 가능
↓
Cooling Tube 제거
↓
Lock Ring 회전 가능
↓
Lock Ring 해제
↓
Top Cover 제거
↓
Gear Lock 노출
↓
Gear 정렬
↓
Energy Core 접근
↓
Core 안정화
↓
CLEAR


중요한 것은 단순 순서 암기가 아니라

**관찰 → 시도 → 피드백 → 이해 → 해결**

경험을 만드는 것이다.

---

# 12. 성공 연출

마지막 Core를 해제하면 즉시 결과창부터 띄우지 않는다.

게임의 가장 중요한 보상 순간으로 연출한다.

예:

Core의 불안정한 주황색 빛

↓

플레이어가 마지막 장치 해제

↓

기계음 감소

↓

Core 회전 속도 감소

↓

주황색 → Cyan/Green

↓

장치 전체 조명 안정

↓

약 1초 정적

↓

`SYSTEM STABLE`

↓

`STAGE CLEAR`

가능하면 햅틱 피드백과 효과음도 사용한다.

---

# 13. 잘못된 조작

초반 Normal Stage에서는 잘못된 행동 때문에 즉시 게임오버시키지 않는다.

대신:

- 부품이 걸림
- 시간 페널티
- 장치 온도 상승
- 새로운 잠금 활성화
- 이동 횟수 증가

등을 사용한다.

후반의 Danger / Boss Stage에서만 강한 실패 조건을 사용한다.

---

# 14. 게임 모드

처음에는 Normal만 구현한다.

구조적으로 다음 확장이 가능하게 한다.

### Normal
시간 제한 거의 없음.

### Danger
시간 제한 및 페널티 존재.

### Boss Device
복잡한 장치 하나를 여러 단계로 해체.

### Daily Device
매일 하나의 퍼즐.

지금 당장 전부 구현할 필요는 없다.

---

# 15. UI

UI는 게임 장치를 가리지 않는 것이 가장 중요하다.

기본:

상단:

```text
ZERO
STAGE
progress
currency
settings

게임 영역:

3D DEVICE

하단:

Undo
Assist
Hint

게임 화면에 버튼을 지나치게 많이 넣지 않는다.

초기 버전에서는 특히 광고/상점/이벤트 UI를 만들지 않는다.

게임 자체부터 완성한다.

---

16. 사운드

이 게임에서는 소리가 매우 중요하다.

각 행동에 촉각적으로 느껴지는 사운드를 사용한다.

예:

click
clack
metal slide
magnetic snap
servo
gear rotation
electric hum
core pulse
lock release

게임의 만족감에서

Sound + Animation + Haptic

을 하나의 세트로 생각한다.

---

17. 광고 및 수익화

현재 단계에서는 게임플레이를 우선한다.

추후 광고 기반 수익화를 고려한다.

향후 후보:

- Hint Reward Ad
- Retry Assist Reward Ad
- Optional Reward

퍼즐 흐름을 광고 때문에 끊지 않는다.

강제 전면 광고 설계는 현재 프로토타입에 넣지 않는다.

---

18. 개발 원칙

중요:

완성되지 않은 기능을 한꺼번에 많이 만들지 않는다.

우선 순서:

1. 프로젝트 기본 구조
2. 카메라
3. 터치 Picking
4. 장치 회전
5. 부품 선택
6. Pull / Rotate 조작
7. Dependency Rule
8. 성공/실패 피드백
9. DEVICE_001 완성
10. 사운드 / 햅틱
11. UI
12. Android 실제 기기 테스트

DEVICE_001이 재미없다면 콘텐츠를 늘리지 않는다.

먼저 게임의 손맛을 완성한다.

---

19. 코드 품질

다음 원칙을 지킨다.

- Scene / Logic / Data 분리
- 거대한 단일 Script 금지
- 재사용 가능한 Interaction Component
- 퍼즐 규칙과 렌더링 분리
- Stage 데이터화
- 디버그 모드 제공
- 부품 상태 확인 가능
- Dependency Graph 확인 가능

예:

scripts/
 core/
 interaction/
 puzzle/
 device/
 ui/
 audio/

scenes/
 game/
 devices/
 ui/

resources/
 stages/
 parts/

assets/
 models/
 textures/
 audio/

더 적합한 구조가 있다면 스스로 개선해도 된다.

---

20. 디버그 기능

개발 편의를 위해 개발 빌드에서는 다음을 제공한다.

- 선택된 Part 이름 표시
- Collision Shape 표시
- Part State 표시
- blocked_by 표시
- 강제 제거
- Stage Reset
- Core 즉시 Open
- FPS
- Draw Call 확인

릴리즈 빌드에서는 제거 가능하게 한다.

---

21. 현재 가장 중요한 목표

지금 목표는

게임 전체 제작이 아니다.

먼저 사용자가

«“이거 만지는 느낌 좋다.”

“왜 안 빠지지?”

“아! 이걸 먼저 해야 하는구나.”

“오, 안쪽에 또 뭐가 있네.”

“마지막에 다 풀었을 때 기분 좋다.”»

라는 경험을 하는

1개의 완성도 높은 Vertical Slice

를 만들어라.

그래픽보다 먼저 Interaction Feel을 검증하되,
최종적으로는 그래픽 역시 이 게임의 핵심 경쟁력이므로
임시 UI 수준에서 프로젝트를 끝내지는 않는다.

---

22. 작업 시작 방식

먼저 현재 개발 환경을 확인해라.

- Godot 설치 상태
- Godot 버전
- Android SDK/JDK
- ADB
- Blender
- Blender MCP
- m.flux 환경
- Git

사용 가능한 환경을 파악한 후,
필요 없는 재설치를 하지 않는다.

그 다음 프로젝트를 생성하고 진행한다.

진행 도중 작은 선택사항을 일일이 나에게 질문하지 마라.

합리적인 것은 스스로 결정하고 진행한다.

게임의 핵심 방향을 변경해야 할 정도의 큰 결정만 알려준다.

---

최종 목표

ZERO는

“나사를 푸는 게임”이 아니라

“신비로운 장치를 만지고, 구조를 이해하고, 하나씩 해체하면서 내부를 발견하는 게임”

이어야 한다.

플레이어가 다음 스테이지에서

«“이번 장치 안에는 뭐가 들어 있을까?”»

라는 궁금증을 가지는 것이 이 게임의 핵심 장기 동기다.

이를 기준으로 설계·개발을 시작해줘.
