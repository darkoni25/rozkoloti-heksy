extends Node2D

# ══════════════════════════════════════════════════════════════════════════════
#  MainMenuScene.gd — Головне меню «Розколоті Гекси»
#  Рендер через _draw() + queue_redraw(), без Control-вузлів.
#  Дизайн-простір: 1920×1080 → масштабується до viewport через s/ox/oy.
# ══════════════════════════════════════════════════════════════════════════════

# ── Дизайн-розміри ───────────────────────────────────────────────────────────
const DW := 1920.0
const DH := 1080.0

# ── Кольори (design tokens) ──────────────────────────────────────────────────
const C_INK       := Color(0.039, 0.031, 0.020, 1.0)   # #0a0805
const C_BR_SHADOW := Color(0.290, 0.220, 0.094, 1.0)   # #4a3818
const C_BR_MID    := Color(0.541, 0.416, 0.180, 1.0)   # #8a6a2e
const C_BR_BRIGHT := Color(0.831, 0.643, 0.290, 1.0)   # #d4a44a
const C_BR_FLARE  := Color(0.941, 0.812, 0.471, 1.0)   # #f0cf78
const C_BONE      := Color(0.910, 0.851, 0.702, 1.0)   # #e8d9b3
const C_PARCH     := Color(0.784, 0.706, 0.529, 1.0)   # #c8b487
const C_DIM       := Color(0.541, 0.471, 0.345, 1.0)   # #8a7858
const C_FADED     := Color(0.353, 0.302, 0.212, 1.0)   # #5a4d36

const BTN_YS: Array[float] = [720.0, 782.0, 844.0]   # Y-координати кнопок

# ── Шрифти ───────────────────────────────────────────────────────────────────
var _f_title : Font   # Cinzel Decorative 900  (title 96px)
var _f_menu  : Font   # Cinzel SemiBold 600    (menu 26px)
var _f_ital  : Font   # IM Fell English Italic (quote, subtitle)
var _f_reg   : Font   # IM Fell English Regular (attribution, corner)

# ── UI стан ──────────────────────────────────────────────────────────────────
var _has_save : bool = false
var _hov      : int  = -1   # hover: 0=НоваГра 1=Продовжити 2=Вийти
var _kb_sel   : int  = 0    # клавіатурний фокус

# ── Анімація ─────────────────────────────────────────────────────────────────
var _alpha_prelude  : float = 0.0
var _alpha_title    : float = 0.0
var _alpha_ornament : float = 0.0
var _alpha_menu     : float = 0.0
var _t              : float = 0.0   # глобальний час

# ── Фонова геометрія (design coords, генерується в _ready) ───────────────────
var _ridge_far  : PackedVector2Array = PackedVector2Array()
var _ridge_mid  : PackedVector2Array = PackedVector2Array()
var _ridge_near : PackedVector2Array = PackedVector2Array()
var _pines_mid  : Array[Dictionary] = []   # [{x,y,w,h}] в design coords
var _pines_near : Array[Dictionary] = []

# ── Іскри ────────────────────────────────────────────────────────────────────
const EMBER_COUNT := 28
var _embers : Array[Dictionary] = []   # [{x,y,speed,wobble,phase,size}]

# ══════════════════════════════════════════════════════════════════════════════
#  _ready
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	RenderingServer.set_default_clear_color(C_INK)
	_has_save = GameState.any_save_exists()
	_load_fonts()
	_gen_ridges()
	_init_embers()
	_start_entry()

func _load_fonts() -> void:
	var fb := ThemeDB.fallback_font
	_f_title = _try_font("res://assets/fonts/Cinzel_Decorative/CinzelDecorative-Black.ttf", fb)
	_f_menu  = _try_font("res://assets/fonts/Cinzel/static/Cinzel-SemiBold.ttf",            fb)
	_f_ital  = _try_font("res://assets/fonts/IM_Fell_English/IMFellEnglish-Italic.ttf",     fb)
	_f_reg   = _try_font("res://assets/fonts/IM_Fell_English/IMFellEnglish-Regular.ttf",    fb)

func _try_font(path: String, fallback: Font) -> Font:
	if ResourceLoader.exists(path):
		var r := ResourceLoader.load(path)
		if r is Font:
			return r as Font
	return fallback

# ── Генерація силуетів ───────────────────────────────────────────────────────
func _gen_ridges() -> void:
	var pts: Array[Vector2] = []

	# Far ridge — плавна хвиля, ~17% знизу
	pts.clear()
	for xi in 60:
		var x := float(xi) / 59.0 * DW
		var y := DH * 0.836 + sin(x * 0.00280) * 28.0 \
						   + sin(x * 0.00712 + 1.2) * 14.0 \
						   + sin(x * 0.00152 + 0.4) * 36.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(DW + 10.0, DH + 10.0))
	pts.append(Vector2(-10.0,     DH + 10.0))
	_ridge_far = PackedVector2Array(pts)

	# Mid ridge — ~25% знизу, рідкі сосни
	pts.clear()
	_pines_mid.clear()
	for xi in 80:
		var x := float(xi) / 79.0 * DW
		var y := DH * 0.752 + sin(x * 0.00382 + 0.8) * 34.0 \
						   + sin(x * 0.00914 + 2.1) * 16.0 \
						   + sin(x * 0.00185 + 1.0) * 26.0
		pts.append(Vector2(x, y))
		if xi % 5 == 1:
			_pines_mid.append({
				"x": x, "y": y,
				"w": 15.0 + sin(x * 0.007) * 4.0,
				"h": 38.0 + sin(x * 0.011) * 12.0
			})
	pts.append(Vector2(DW + 10.0, DH + 10.0))
	pts.append(Vector2(-10.0,     DH + 10.0))
	_ridge_mid = PackedVector2Array(pts)

	# Near ridge — ~36% знизу, густі сосни
	pts.clear()
	_pines_near.clear()
	for xi in 100:
		var x := float(xi) / 99.0 * DW
		var y := DH * 0.648 + sin(x * 0.00480 + 1.0) * 46.0 \
						   + sin(x * 0.01082 + 0.3) * 24.0 \
						   + sin(x * 0.00210)        * 58.0
		pts.append(Vector2(x, y))
		if xi % 2 == 0:
			_pines_near.append({
				"x": x, "y": y,
				"w": 20.0 + sin(x * 0.0083) * 6.0,
				"h": 58.0 + sin(x * 0.0124) * 20.0
			})
	pts.append(Vector2(DW + 10.0, DH + 10.0))
	pts.append(Vector2(-10.0,     DH + 10.0))
	_ridge_near = PackedVector2Array(pts)

func _init_embers() -> void:
	for _i in EMBER_COUNT:
		_embers.append({
			"x":      randf_range(100.0, DW - 100.0),
			"y":      randf_range(0.0, DH),
			"speed":  randf_range(38.0, 88.0),
			"wobble": randf_range(0.4, 1.6),
			"phase":  randf_range(0.0, TAU),
			"size":   randf_range(2.0, 4.5),
		})

func _start_entry() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_alpha_prelude",  1.0, 1.4).set_delay(0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_alpha_title",    1.0, 1.4).set_delay(0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_alpha_ornament", 1.0, 1.4).set_delay(0.65) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_alpha_menu",     1.0, 1.4).set_delay(0.85) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ══════════════════════════════════════════════════════════════════════════════
#  Process
# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	_t += delta
	for e: Dictionary in _embers:
		e["y"] = float(e["y"]) - float(e["speed"]) * delta
		e["x"] = float(e["x"]) + sin(_t * float(e["wobble"]) + float(e["phase"])) * 0.28
		if float(e["y"]) < -20.0:
			e["y"] = DH + 10.0
			e["x"] = randf_range(100.0, DW - 100.0)
	queue_redraw()

# ══════════════════════════════════════════════════════════════════════════════
#  Input
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mp   := _to_design((event as InputEventMouseMotion).position)
		var prev := _hov
		_hov = _btn_at(mp)
		if _hov >= 0:
			_kb_sel = _hov
		if _hov != prev:
			queue_redraw()

	elif event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			_activate(_btn_at(_to_design(mbe.position)))

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed:
			return
		match ke.keycode:
			KEY_UP:
				_kb_sel = maxi(0, _kb_sel - 1)
				_hov    = _kb_sel
				queue_redraw()
			KEY_DOWN:
				_kb_sel = mini(2, _kb_sel + 1)
				_hov    = _kb_sel
				queue_redraw()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate(_kb_sel)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _to_design(screen_pos: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var s  := minf(vp.x / DW, vp.y / DH)
	var ox := (vp.x - DW * s) * 0.5
	var oy := (vp.y - DH * s) * 0.5
	return (screen_pos - Vector2(ox, oy)) / s

func _btn_rect(i: int) -> Rect2:
	# design coords — кнопки центровані по X
	return Rect2(960.0 - 230.0, BTN_YS[i], 460.0, 48.0)

func _btn_at(dp: Vector2) -> int:
	for i in 3:
		if _btn_rect(i).has_point(dp):
			return i
	return -1

func _activate(idx: int) -> void:
	match idx:
		0: _new_game()
		1: _continue_game()
		2: get_tree().quit()

func _new_game() -> void:
	var ssm := get_node_or_null("/root/SaveSlotMenu")
	if ssm:
		ssm.call("show_new_game")

func _continue_game() -> void:
	if not _has_save:
		return
	var ssm := get_node_or_null("/root/SaveSlotMenu")
	if ssm:
		ssm.call("show_load")

# ── Кольори з alpha ───────────────────────────────────────────────────────────
func _ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))

# ── Перетворення design→screen ────────────────────────────────────────────────
func _ds(dx: float, dy: float, s: float, ox: float, oy: float) -> Vector2:
	return Vector2(ox + dx * s, oy + dy * s)

# ══════════════════════════════════════════════════════════════════════════════
#  _draw  (головний рендер)
# ══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	var vp := get_viewport_rect().size
	var s  := minf(vp.x / DW, vp.y / DH)
	var ox := (vp.x - DW * s) * 0.5
	var oy := (vp.y - DH * s) * 0.5

	_draw_bg(s, ox, oy, vp)
	_draw_frame(s, ox, oy)
	_draw_prelude(s, ox, oy, _alpha_prelude)
	_draw_title_block(s, ox, oy, _alpha_title)
	_draw_ornament_div(s, ox, oy, _alpha_ornament)
	_draw_menu(s, ox, oy, _alpha_menu)
	_draw_corner_meta(s, ox, oy)
	_draw_embers(s, ox, oy)

# ══════════════════════════════════════════════════════════════════════════════
#  Background
# ══════════════════════════════════════════════════════════════════════════════
func _draw_bg(s: float, ox: float, oy: float, vp: Vector2) -> void:
	# Базовий фон
	draw_rect(Rect2(Vector2.ZERO, vp), C_INK)

	# Тепле центральне світло (кілька прозорих кіл)
	var cx := ox + 960.0 * s
	var cy := oy + 562.0 * s
	for i in 8:
		var t := 1.0 - float(i) / 8.0
		draw_circle(Vector2(cx, cy),
			(0.18 + float(i) * 0.10) * vp.y,
			Color(0.110, 0.066, 0.020, 0.055 * t * t))

	# Far ridge
	var far_s := _scale_ridge(_ridge_far, s, ox, oy)
	var fc    := PackedColorArray(); fc.resize(far_s.size()); fc.fill(Color(0.102, 0.078, 0.051, 0.85))
	draw_polygon(far_s, fc)

	# Mid ridge
	var mid_s := _scale_ridge(_ridge_mid, s, ox, oy)
	var mc    := PackedColorArray(); mc.resize(mid_s.size()); mc.fill(Color(0.063, 0.047, 0.027, 0.92))
	draw_polygon(mid_s, mc)

	# Mid pines
	var cp_m := Color(0.052, 0.038, 0.022, 0.92)
	for p: Dictionary in _pines_mid:
		_draw_pine(_ds(float(p["x"]), float(p["y"]), s, ox, oy),
				float(p["w"]) * s, float(p["h"]) * s, cp_m)

	# Near ridge
	var near_s := _scale_ridge(_ridge_near, s, ox, oy)
	var nc     := PackedColorArray(); nc.resize(near_s.size()); nc.fill(Color(0.039, 0.027, 0.016, 1.0))
	draw_polygon(near_s, nc)

	# Near pines (трохи темніші за небо, але однакові з хребтом — силует)
	var cp_n := Color(0.039, 0.027, 0.016, 1.0)
	for p: Dictionary in _pines_near:
		_draw_pine(_ds(float(p["x"]), float(p["y"]), s, ox, oy),
				float(p["w"]) * s, float(p["h"]) * s, cp_n)

	# Два замки-силуети
	_draw_castle(s, ox, oy, 188.0, DH * 0.618, 0.9)
	_draw_castle(s, ox, oy, DW - 195.0, DH * 0.656, 0.78)

	# Підсвічування хребтів — тоненька лінія на горизонті far ridge
	var far_top := _find_ridge_top(_ridge_far, 960.0)
	draw_line(
		_ds(200.0, far_top, s, ox, oy),
		_ds(DW - 200.0, far_top, s, ox, oy),
		Color(C_BR_SHADOW, 0.18), 1.0 * s)

	# Віньєтка — затемнення по краях через прозорі кола в кутах
	var vw := vp.x; var vh := vp.y
	var vc := Color(0.018, 0.012, 0.006, 0.38)
	draw_circle(Vector2(-vw * 0.08, -vh * 0.08), vw * 0.90, vc)
	draw_circle(Vector2(vw * 1.08,  -vh * 0.08), vw * 0.90, vc)
	draw_circle(Vector2(-vw * 0.08,  vh * 1.08), vw * 0.90, vc)
	draw_circle(Vector2(vw * 1.08,   vh * 1.08), vw * 0.90, vc)
	# Верхнє і нижнє затемнення
	for i in 5:
		var t  := float(i) / 4.0
		var ht := (0.04 + t * 0.09) * vh
		draw_rect(Rect2(0.0, 0.0, vw, ht),
			Color(0.010, 0.007, 0.003, 0.07 * (1.0 - t)))
		draw_rect(Rect2(0.0, vh - ht, vw, ht),
			Color(0.010, 0.007, 0.003, 0.05 * (1.0 - t)))

func _scale_ridge(ridge: PackedVector2Array, s: float, ox: float, oy: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pt: Vector2 in ridge:
		out.append(Vector2(ox + pt.x * s, oy + pt.y * s))
	return out

func _find_ridge_top(ridge: PackedVector2Array, near_x: float) -> float:
	var best_y := DH
	for pt: Vector2 in ridge:
		if absf(pt.x - near_x) < 100.0 and pt.y < best_y:
			best_y = pt.y
	return best_y

func _draw_pine(base: Vector2, hw: float, h: float, c: Color) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(base.x - hw * 0.5, base.y),
							Vector2(base.x + hw * 0.5, base.y),
							Vector2(base.x, base.y - h)]),
		PackedColorArray([c, c, c]))

func _draw_castle(s: float, ox: float, oy: float, dx: float, dy: float, sz: float) -> void:
	var c  := Color(0.039, 0.027, 0.016, 1.0)   # match near ridge (silhouette)
	var bx := ox + dx * s
	var by := oy + dy * s
	var sc := sz * s
	# Основна стіна
	draw_rect(Rect2(bx - 38*sc, by - 28*sc, 76*sc, 28*sc), c)
	# Центральна вежа
	draw_rect(Rect2(bx - 11*sc, by - 70*sc, 22*sc, 70*sc), c)
	# Ліва вежа
	draw_rect(Rect2(bx - 46*sc, by - 54*sc, 15*sc, 54*sc), c)
	# Права вежа
	draw_rect(Rect2(bx + 31*sc, by - 54*sc, 15*sc, 54*sc), c)
	# Зубці (merlons) центральної вежі
	for mi in 3:
		draw_rect(Rect2(bx - 9*sc + float(mi) * 9*sc, by - 76*sc, 5*sc, 7*sc), c)
	# Зубці бічних стін
	for mi in 2:
		draw_rect(Rect2(bx - 44*sc + float(mi) * 8*sc, by - 60*sc, 4*sc, 6*sc), c)
		draw_rect(Rect2(bx + 31*sc + float(mi) * 8*sc, by - 60*sc, 4*sc, 6*sc), c)

# ══════════════════════════════════════════════════════════════════════════════
#  Кутова рамка
# ══════════════════════════════════════════════════════════════════════════════
func _draw_frame(s: float, ox: float, oy: float) -> void:
	var c   := Color(C_BR_MID, 0.80)
	var cdm := Color(C_BR_MID, 0.45)
	var lw  := 1.2 * s
	var ll  := 110.0 * s   # довжина ліній
	var gap := 5.0 * s     # зазор між подвійними лініями

	# Кути в screen coords: [TL, TR, BL, BR]
	var corners: Array[Vector2] = [
		Vector2(ox + 36.0*s, oy + 36.0*s),
		Vector2(ox + (DW-36.0)*s, oy + 36.0*s),
		Vector2(ox + 36.0*s, oy + (DH-36.0)*s),
		Vector2(ox + (DW-36.0)*s, oy + (DH-36.0)*s),
	]
	var dirs: Array[Vector2] = [
		Vector2( 1,  1),  # TL → right+down
		Vector2(-1,  1),  # TR → left+down
		Vector2( 1, -1),  # BL → right+up
		Vector2(-1, -1),  # BR → left+up
	]

	for i in 4:
		var p: Vector2 = corners[i]
		var d: Vector2 = dirs[i]
		# Зовнішній L
		draw_line(p, p + Vector2(d.x * ll, 0),  c, lw)
		draw_line(p, p + Vector2(0, d.y * ll),  c, lw)
		# Внутрішній L (зсунутий всередину)
		var pi := p + Vector2(d.x * gap, d.y * gap)
		draw_line(pi, pi + Vector2(d.x * (ll - gap * 2.0), 0), c, lw)
		draw_line(pi, pi + Vector2(0, d.y * (ll - gap * 2.0)), c, lw)
		# Кутові крапки
		draw_circle(p, 3.0 * s, c)
		draw_circle(p + Vector2(d.x * ll, 0),  2.0 * s, cdm)
		draw_circle(p + Vector2(0, d.y * ll),  2.0 * s, cdm)
		draw_circle(pi, 1.5 * s, c)

# ══════════════════════════════════════════════════════════════════════════════
#  Хроніка (цитата)
# ══════════════════════════════════════════════════════════════════════════════
func _draw_prelude(s: float, ox: float, oy: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var cx  := ox + 960.0 * s
	var fs  := maxi(10, int(17.0 * s))
	var fa  := maxi(8,  int(13.0 * s))
	var cq  := _ca(C_DIM,   alpha * 0.92)
	var ca  := _ca(C_FADED, alpha)
	var cdo := _ca(C_BR_MID, alpha * 0.7)  # латунна крапка

	var quote := "Світ був колись єдиний. Та сім народів пролили кров одне одного,\n" \
				+ "щоб посісти землю — і виснажили самих себе.\n" \
				+ "Лишилися тільки руїни й безчесні присяги."
	var max_w := int(560.0 * s)
	var y_q   := oy + 128.0 * s   # baseline першого рядка

	draw_multiline_string(_f_ital, Vector2(cx - max_w * 0.5, y_q),
		quote, HORIZONTAL_ALIGNMENT_CENTER, max_w, fs, 3, cq)

	# Атрибуція
	var attr  := "З ХРОНІКИ ЗАТЕМНЕННЯ  ·  РІК 472"
	var y_a   := oy + 224.0 * s
	var attr_w := int(400.0 * s)
	draw_string(_f_reg, Vector2(cx - attr_w * 0.5, y_a),
		attr, HORIZONTAL_ALIGNMENT_CENTER, attr_w, fa, ca)

	# Декоративні лінії по боках атрибуції
	var hw := 180.0 * s
	draw_line(Vector2(cx - hw, y_a - fa * 0.35), Vector2(cx - hw * 0.55, y_a - fa * 0.35), cdo, 1.0 * s)
	draw_line(Vector2(cx + hw * 0.55, y_a - fa * 0.35), Vector2(cx + hw, y_a - fa * 0.35), cdo, 1.0 * s)

# ══════════════════════════════════════════════════════════════════════════════
#  Title block (емблема + заголовок + підзаголовок)
# ══════════════════════════════════════════════════════════════════════════════
func _draw_title_block(s: float, ox: float, oy: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	# Y-drift 8s
	var drift := sin(TAU * _t / 8.0) * 4.0 * s

	var ec := Vector2(ox + 960.0 * s, oy + 386.0 * s + drift)  # центр емблеми

	_draw_emblem(ec, s, alpha)

	# Заголовок "РОЗКОЛОТІ ГЕКСИ"
	var fs_t := maxi(24, int(96.0 * s))
	var y_ti := oy + 520.0 * s + drift   # baseline
	var cx   := ox + 960.0 * s

	# Весь заголовок одним кольором (fallback) — якщо є кастомний шрифт,
	# частина "т" у "РОЗКОЛОТІ" виводиться яскравішою латунню
	if _f_title != ThemeDB.fallback_font:
		_draw_title_split(cx, y_ti, fs_t, s, alpha)
	else:
		# Простий варіант без виділення
		draw_string(_f_title, Vector2(cx - int(640.0 * s * 0.5), y_ti),
			"РОЗКОЛОТІ ГЕКСИ",
			HORIZONTAL_ALIGNMENT_CENTER, int(640.0 * s), fs_t,
			_ca(C_BONE, alpha))

	# Підзаголовок "СВІТ СЕМИ НАРОДІВ"
	var fs_s := maxi(12, int(22.0 * s))
	var y_sub := oy + 610.0 * s + drift
	draw_string(_f_ital, Vector2(cx - int(560.0 * s * 0.5), y_sub),
		"СВІТ СЕМИ НАРОДІВ",
		HORIZONTAL_ALIGNMENT_CENTER, int(560.0 * s), fs_s,
		_ca(C_PARCH, alpha))

func _draw_title_split(cx: float, y: float, fs: int, _s: float, alpha: float) -> void:
	# Малює "РОЗКОЛОТ" + "І" (яскрава) + " ГЕКСИ" в Cinzel Decorative
	var part1 := "РОЗКОЛОТ"
	var part2 := "І"
	var part3 := " ГЕКСИ"
	var w1 := _f_title.get_string_size(part1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := _f_title.get_string_size(part2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w3 := _f_title.get_string_size(part3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total_w := w1 + w2 + w3
	var x_start := cx - total_w * 0.5

	draw_string(_f_title, Vector2(x_start, y),       part1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _ca(C_BONE,      alpha))
	draw_string(_f_title, Vector2(x_start + w1, y),  part2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _ca(C_BR_BRIGHT, alpha))
	draw_string(_f_title, Vector2(x_start + w1 + w2, y), part3, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _ca(C_BONE, alpha))

# ── Емблема ───────────────────────────────────────────────────────────────────
func _draw_emblem(ec: Vector2, s: float, alpha: float) -> void:
	# Мерехтіння: 4.2s цикл
	var flicker := 0.22 + 0.16 * (0.5 + 0.5 * sin(TAU * _t / 4.2))

	# Зовнішнє сяйво
	draw_circle(ec, 72.0 * s, Color(C_BR_BRIGHT, flicker * 0.30 * alpha))
	draw_circle(ec, 62.0 * s, Color(C_BR_BRIGHT, flicker * 0.18 * alpha))

	# Зовнішнє кільце r=56
	draw_arc(ec, 56.0 * s, 0.0, TAU, 80, _ca(Color(C_BR_MID,    0.70), alpha), 1.2 * s)
	# Внутрішнє кільце r=51
	draw_arc(ec, 51.0 * s, 0.0, TAU, 80, _ca(Color(C_BR_SHADOW, 1.00), alpha), 0.8 * s)

	# Семипроменева зірка (7-pointed star, 14 вершин)
	var star_v := _star_poly(ec, 45.0 * s, 18.0 * s, 7)
	var star_c := PackedColorArray()
	for i in star_v.size():
		# Зовнішні вершини (i%2==0) → темніші; внутрішні (i%2==1) → яскравіші
		var base_c: Color = C_BR_SHADOW if i % 2 == 0 else Color(0.659, 0.502, 0.165)
		star_c.append(_ca(base_c, alpha))
	draw_polygon(star_v, star_c)

	# Контур зірки
	draw_polyline(_close(star_v), _ca(Color(C_BR_BRIGHT, 0.50), alpha), 0.8 * s)

	# Внутрішній п'ятикутник r=28
	var penta_v := _regular_poly(ec, 28.0 * s, 5, -PI * 0.5)
	draw_polyline(_close(penta_v), _ca(Color(C_BR_BRIGHT, 0.80), alpha), 0.8 * s)

	# Ядро: r=6 чорне + обведення
	draw_circle(ec, 6.0 * s, _ca(C_INK, alpha))
	draw_arc(ec, 6.0 * s, 0.0, TAU, 24, _ca(C_BR_BRIGHT, alpha), 1.0 * s)
	# Центральна крапка r=2
	draw_circle(ec, 2.0 * s, _ca(C_BR_FLARE, alpha))

	# 7 «пипок» по зовнішньому кільцю
	for i in 7:
		var a   := -PI * 0.5 + float(i) * TAU / 7.0
		var pip := ec + Vector2(cos(a), sin(a)) * 56.0 * s
		draw_circle(pip, 2.5 * s, _ca(C_BR_MID, alpha * 0.85))

# ── Допоміжні функції для полігонів ──────────────────────────────────────────
func _star_poly(center: Vector2, outer_r: float, inner_r: float, n: int) -> PackedVector2Array:
	var v := PackedVector2Array()
	for i in n * 2:
		var a := -PI * 0.5 + float(i) * PI / float(n)
		var r := outer_r if i % 2 == 0 else inner_r
		v.append(center + Vector2(cos(a), sin(a)) * r)
	return v

func _regular_poly(center: Vector2, r: float, n: int, offset: float) -> PackedVector2Array:
	var v := PackedVector2Array()
	for i in n:
		var a := offset + float(i) * TAU / float(n)
		v.append(center + Vector2(cos(a), sin(a)) * r)
	return v

func _close(v: PackedVector2Array) -> PackedVector2Array:
	var c := PackedVector2Array(v)
	if c.size() > 0:
		c.append(c[0])
	return c

# ══════════════════════════════════════════════════════════════════════════════
#  Орнамент-роздільник
# ══════════════════════════════════════════════════════════════════════════════
func _draw_ornament_div(s: float, ox: float, oy: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var cx   := ox + 960.0 * s
	var cy   := oy + 660.0 * s
	var c_l  := _ca(Color(C_BR_MID, 0.70), alpha)
	var c_d  := _ca(C_BR_MID, alpha)
	var c_f  := _ca(C_BR_FLARE, alpha)
	var hw   := 240.0 * s   # half-width ліній
	var dh   := 10.0 * s    # half-розмір ромба

	# Ліва та права лінія
	draw_line(Vector2(cx - hw, cy), Vector2(cx - dh * 2.2, cy), c_l, 1.2 * s)
	draw_line(Vector2(cx + dh * 2.2, cy), Vector2(cx + hw, cy), c_l, 1.2 * s)

	# Ромб у центрі
	draw_polygon(
		PackedVector2Array([
			Vector2(cx,      cy - dh),
			Vector2(cx + dh, cy),
			Vector2(cx,      cy + dh),
			Vector2(cx - dh, cy),
		]),
		PackedColorArray([c_d, c_d, c_d, c_d]))

	# Крапка всередині ромба
	draw_circle(Vector2(cx, cy), 2.8 * s, c_f)

	# Маленькі крапки вздовж ліній
	for i in 3:
		var t   := float(i + 1) * 0.22
		var dot := Color(C_BR_MID, alpha * (0.5 - float(i) * 0.12))
		draw_circle(Vector2(cx - hw * t, cy), 1.5 * s, dot)
		draw_circle(Vector2(cx + hw * t, cy), 1.5 * s, dot)

# ══════════════════════════════════════════════════════════════════════════════
#  Меню
# ══════════════════════════════════════════════════════════════════════════════
func _draw_menu(s: float, ox: float, oy: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var _cx := ox + 960.0 * s
	var fs  := maxi(14, int(26.0 * s))
	var bw  := int(460.0 * s)
	const LABELS: Array[String] = ["НОВА ГРА", "ПРОДОВЖИТИ", "ВИЙТИ"]

	for i in 3:
		var br   := _btn_rect(i)
		# Перерахунок у screen coords
		var _bx  := ox + br.position.x * s
		var by   := oy + br.position.y * s
		var bcx  := ox + (br.position.x + br.size.x * 0.5) * s
		var bcy  := oy + (br.position.y + br.size.y * 0.5) * s
		var bh   := br.size.y * s

		var is_hover    := (i == _hov)
		var is_disabled := (i == 1 and not _has_save)

		# Колір тексту
		var tc: Color
		if is_disabled:
			tc = _ca(C_FADED, alpha * 0.60)
		elif is_hover:
			tc = _ca(C_BONE if i != 2 else Color(0.965, 0.824, 0.737), alpha)
		else:
			tc = _ca(C_PARCH, alpha)

		# Hover-декорація: лінії зверху і знизу
		if is_hover and not is_disabled:
			var lw_b := 280.0 * s * 0.5
			var line_c := _ca(Color(C_BR_MID, 0.80), alpha)
			var _bright_c := _ca(Color(C_BR_BRIGHT, 0.90), alpha)
			# Верхня лінія (градієнт через кілька відрізків)
			for j in 6:
				var t  := float(j) / 5.0
				var at := sin(t * PI)
				var lc := Color(C_BR_MID.lerp(C_BR_BRIGHT, at), line_c.a * at * 0.9 + 0.05)
				lc.a *= alpha
				draw_line(
					Vector2(bcx - lw_b + float(j) * lw_b * 0.334,  by + 3.0 * s),
					Vector2(bcx - lw_b + float(j + 1) * lw_b * 0.334, by + 3.0 * s),
					lc, 1.0 * s)
				draw_line(
					Vector2(bcx - lw_b + float(j) * lw_b * 0.334,  by + bh - 3.0 * s),
					Vector2(bcx - lw_b + float(j + 1) * lw_b * 0.334, by + bh - 3.0 * s),
					lc, 1.0 * s)
			# Стрілки ← →
			var arrow_c := _ca(C_BR_BRIGHT, alpha * 0.90)
			var ax_l    := bcx - lw_b - 12.0 * s
			var ax_r    := bcx + lw_b + 12.0 * s
			draw_line(Vector2(ax_l, bcy),             Vector2(ax_l - 10.0*s, bcy - 7.0*s), arrow_c, 1.4 * s)
			draw_line(Vector2(ax_l, bcy),             Vector2(ax_l - 10.0*s, bcy + 7.0*s), arrow_c, 1.4 * s)
			draw_line(Vector2(ax_r, bcy),             Vector2(ax_r + 10.0*s, bcy - 7.0*s), arrow_c, 1.4 * s)
			draw_line(Vector2(ax_r, bcy),             Vector2(ax_r + 10.0*s, bcy + 7.0*s), arrow_c, 1.4 * s)

		# Текст кнопки
		draw_string(_f_menu,
			Vector2(bcx - bw * 0.5, bcy + fs * 0.36),
			LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, bw, fs, tc)

		# Disabled: додаткова крапка-індикатор
		if is_disabled:
			draw_circle(Vector2(bcx, bcy + bh * 0.5 + 8.0 * s), 2.0 * s, _ca(C_FADED, alpha * 0.4))

# ══════════════════════════════════════════════════════════════════════════════
#  Кутові метадані
# ══════════════════════════════════════════════════════════════════════════════
func _draw_corner_meta(s: float, ox: float, oy: float) -> void:
	var fs := maxi(8, int(14.0 * s))
	var fa := maxi(7, int(13.0 * s))

	# Top-left: «З ХРОНІКИ ЗАТЕМНЕННЯ»
	draw_string(_f_ital, _ds(56.0, 54.0, s, ox, oy),
		"З ХРОНІКИ ЗАТЕМНЕННЯ", HORIZONTAL_ALIGNMENT_LEFT, int(280.0 * s), fs,
		Color(C_FADED, 0.80))

	# Top-right: SIGILLUM VII GENTIUM (спрощена печатка)
	_draw_sigillum(s, ox, oy)

	# Bottom-left: info про слоти збереження
	if _has_save:
		var slot_count := 0
		for si in 3:
			if GameState.has_save(si):
				slot_count += 1
		draw_string(_f_ital, _ds(56.0, DH - 64.0, s, ox, oy),
			"Збережені ігри:", HORIZONTAL_ALIGNMENT_LEFT, int(280.0 * s), fa,
			Color(C_FADED, 0.70))
		draw_string(_f_reg, _ds(56.0, DH - 46.0, s, ox, oy),
			"%d / 3 слотів використано" % slot_count,
			HORIZONTAL_ALIGNMENT_LEFT, int(280.0 * s), fa,
			Color(C_PARCH, 0.85))

	# Bottom-right: версія + студія
	draw_string(_f_reg, _ds(DW - 56.0, DH - 56.0, s, ox, oy),
		"v 0.4.2  ·  ТВЕРДА ЗЕМЛЯ", HORIZONTAL_ALIGNMENT_RIGHT, int(300.0 * s), fa,
		Color(C_PARCH, 0.80))
	draw_string(_f_ital, _ds(DW - 56.0, DH - 40.0, s, ox, oy),
		"© Darkoni25 Studios", HORIZONTAL_ALIGNMENT_RIGHT, int(300.0 * s), fa,
		Color(C_FADED, 0.70))

func _draw_sigillum(s: float, ox: float, oy: float) -> void:
	# Проста кругла печатка у top-right
	var cx := ox + (DW - 64.0 - 44.0) * s
	var cy := oy + (52.0 + 44.0) * s
	var c  := Color(C_BR_MID, 0.60)
	var cf := Color(C_BR_SHADOW, 0.50)
	draw_arc(Vector2(cx, cy), 40.0 * s, 0.0, TAU, 64, c, 1.0 * s)
	draw_arc(Vector2(cx, cy), 34.0 * s, 0.0, TAU, 64, cf, 0.7 * s)
	# Сонячна розетка — 7 ліній від центру
	for i in 7:
		var a := float(i) * TAU / 7.0
		draw_line(
			Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 6.0 * s,
			Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 28.0 * s,
			Color(C_BR_MID, 0.40), 0.8 * s)
	# Текст по колу: «SIGILLUM VII»
	var fs_sm := maxi(6, int(8.0 * s))
	draw_string(_f_ital, Vector2(cx - 20.0 * s, cy - 8.0 * s),
		"SIGILLUM VII", HORIZONTAL_ALIGNMENT_CENTER, int(40.0 * s), fs_sm,
		Color(C_FADED, 0.65))

# ══════════════════════════════════════════════════════════════════════════════
#  Іскри (embers)
# ══════════════════════════════════════════════════════════════════════════════
func _draw_embers(s: float, ox: float, oy: float) -> void:
	for e: Dictionary in _embers:
		var ex  := ox + float(e["x"]) * s
		var ey  := oy + float(e["y"]) * s
		var sz  := float(e["size"]) * s
		# Прозорість залежить від висоти (fade near top and bottom)
		var ny  := float(e["y"]) / DH   # 0=top, 1=bottom
		var a   := sin(clampf(ny * PI, 0.0, PI)) * 0.85 + 0.05
		# Ядро: brass-flare
		draw_circle(Vector2(ex, ey), sz,         Color(C_BR_FLARE, a))
		# Зовнішнє сяйво: більший, прозоріший
		draw_circle(Vector2(ex, ey), sz * 2.4,   Color(C_BR_BRIGHT, a * 0.30))
		draw_circle(Vector2(ex, ey), sz * 4.0,   Color(C_BR_BRIGHT, a * 0.10))
