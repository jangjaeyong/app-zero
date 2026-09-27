#!/usr/bin/env bash
# 모든 GDScript 가 컴파일되는지 확인한다.
#
#   tools/check_scripts.sh
#
# 왜 별도 도구인가: 게임 안에서 검사하려고 했더니
#  - 그냥 load() 하면 캐시된 것이 와서 깨진 스크립트도 통과하고
#  - 캐시를 무시하면 지금 돌고 있는 자기 자신까지 다시 불러와 프로세스가 망가졌다.
# godot --check-only 는 파싱만 하고 종료 코드로 알려 준다. 이게 맞는 도구다.
#
# 이게 필요한 이유: 스크립트는 그 화면을 열 때 처음 컴파일된다.
# RouteInteraction 이 깨진 채로 스테이지 검증을 멀쩡히 통과한 적이 있다.

set -u
cd "$(dirname "$0")/.." || exit 1

GAME=game
fail=0
total=0

# --check-only 는 스크립트 하나만 파싱하므로 오토로드 이름을 모른다.
# 그 오류는 진짜가 아니므로 걸러 낸다.
AUTOLOADS='Identifier not found: (Sfx|Haptics|DebugFlags|Progress|Settings|Session|DevTools)'
# 위 오탐이 의존 스크립트로 번지며 남기는 꼬리말. 파일마다 따로 검사하므로
# 진짜 원인은 그 파일 자신의 검사에서 잡힌다.
CASCADE='Failed to compile depended scripts'

for file in $(find "$GAME/scripts" -name '*.gd' | sort); do
    total=$((total + 1))
    rel="res://${file#$GAME/}"
    # ⚠️ --check-only 는 오류를 찍고도 **종료 코드 0** 을 준다.
    # 출력을 봐야 한다.
    out=$(godot --headless --path "$GAME" --check-only --script "$rel" 2>&1 \
          | grep -E "Parse Error|Compile Error" \
          | grep -vE "$AUTOLOADS" | grep -vE "$CASCADE")
    if [ -n "$out" ]; then
        echo "  x $rel"
        echo "$out" | head -3 | sed 's/^/      /'
        fail=$((fail + 1))
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "ZERO_SCRIPTS_OK  ${total}개 전부 컴파일"
    exit 0
fi
echo "ZERO_SCRIPTS_FAIL  ${total}개 중 ${fail}개 실패"
exit 1
