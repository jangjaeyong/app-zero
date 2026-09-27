# fonts

`ZeroSansKR.ttf`

Noto Sans KR (variable) 를 wght=500 으로 고정하고
라틴 + 한글 완성형 전체(U+AC00–D7A3) + 자모 + 기호만 남겨 서브셋한 것.
9.9MB → 2.3MB.

원본: https://github.com/google/fonts/tree/main/ofl/notosanskr
라이선스: SIL Open Font License 1.1 (OFL.txt)

재생성:
```
fonttools varLib.instancer NotoSansKR[wght].ttf wght=500 -o NotoKR-500.ttf
pyftsubset NotoKR-500.ttf --output-file=ZeroSansKR.ttf \
  --unicodes="U+0020-007E,U+00A0-00FF,U+2000-206F,U+20A9,U+20AC,U+2190-21BB,U+25A0-25FF,U+3000-303F,U+3131-318E,U+AC00-D7A3,U+FF01-FF5E" \
  --layout-features="kern,liga,ccmp,locl" --no-hinting --desubroutinize
```
