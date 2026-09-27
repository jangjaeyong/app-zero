class_name UiStyle
extends RefCounted
## 기획서 7번의 색을 한 곳에 모아둔다. 값은 여기서만 고친다.

const NAVY      := Color(0.043, 0.055, 0.094)
const PANEL     := Color(0.063, 0.094, 0.153)
const GUNMETAL  := Color(0.149, 0.169, 0.196)
const WHITE     := Color(0.878, 0.894, 0.918)
const DIM       := Color(0.420, 0.478, 0.565)
const CYAN      := Color(0.180, 0.780, 0.980)
const AMBER     := Color(1.000, 0.616, 0.180)
const DANGER    := Color(1.000, 0.318, 0.282)
const GREEN     := Color(0.298, 0.898, 0.639)

const FONT_PATH := "res://assets/fonts/ZeroSansKR.ttf"

static var _font: Font = null

static func font() -> Font:
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	return _font

## 자간을 준 폰트. 워드마크처럼 넓게 벌려야 하는 곳에 쓴다.
static func tracked_font(spacing: int) -> Font:
	var base := font()
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	return fv

## 앵커 배치. stretch aspect 가 "expand" 라 뷰포트가 한쪽으로 늘어나므로
## 절대 좌표로 오른쪽·아래 끝을 계산하면 기기마다 어긋난다.
static func anchor(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob

static func label(text: String, size: int, color: Color, spacing: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f: Font = tracked_font(spacing) if spacing != 0 else font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func panel(bg: Color, border: Color, radius: int = 14, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func chip(text: String, size: int, color: Color, border: Color,
		bg: Color = Color(0.063, 0.094, 0.153, 0.82)) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", panel(bg, border))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(label(text, size, color, 2))
	return pc

static func button(text: String, size: int, color: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_pressed_color", WHITE)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.4))
	var f := font()
	if f != null:
		b.add_theme_font_override("font", f)
	var normal := panel(Color(PANEL, 0.78), Color(border, 0.75), 16, 2)
	var hover := panel(Color(PANEL, 0.95), border, 16, 2)
	var pressed := panel(Color(border, 0.28), border, 16, 2)
	var disabled := panel(Color(PANEL, 0.4), Color(DIM, 0.25), 16, 2)
	for n in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(n, normal if n != "hover" else hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	return b
