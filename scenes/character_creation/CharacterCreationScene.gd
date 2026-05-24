extends Node2D

# Класи = ті самі що в GameState.COMPANIONS (індекс збігається з building ID)
# Статистика героя трохи вища ніж у компаньйона того ж класу (+5 HP)
const CLASSES: Array = [
	{
		"name":       "Клірик",
		"desc":       "Захисник віри. Носить важку броню, лікує союзників молитвами.",
		"move_range": 2, "hp": 40, "dmg":  6, "atk_range": 1,
		"color":      Color(0.85, 0.85, 0.95),
	},
	{
		"name":       "Паладін",
		"desc":       "Залізна воля і священне полум'я. Б'ється впритул, стійкий проти темряви.",
		"move_range": 2, "hp": 43, "dmg":  7, "atk_range": 1,
		"color":      Color(0.95, 0.85, 0.30),
	},
	{
		"name":       "Воїн",
		"desc":       "Загартований мечем. Надійний щит між ворогом і загоном.",
		"move_range": 3, "hp": 35, "dmg":  8, "atk_range": 1,
		"color":      Color(0.60, 0.75, 0.95),
	},
	{
		"name":       "Злодій",
		"desc":       "Тінь і клинок. Неперевершена рухливість, смертельний удар зблизька.",
		"move_range": 4, "hp": 25, "dmg": 10, "atk_range": 1,
		"color":      Color(0.55, 0.85, 0.55),
	},
	{
		"name":       "Маг",
		"desc":       "Майстер руйнівних заклинань. Вражає здалеку, крихкий у ближньому бою.",
		"move_range": 2, "hp": 27, "dmg": 12, "atk_range": 3,
		"color":      Color(0.75, 0.50, 0.95),
	},
	{
		"name":       "Мисливець",
		"desc":       "Слідопит пустощів. Точний лучник, вправно читає місцевість.",
		"move_range": 3, "hp": 30, "dmg":  9, "atk_range": 2,
		"color":      Color(0.70, 0.88, 0.50),
	},
	{
		"name":       "Оккультист",
		"desc":       "Той, хто торгує з темрявою. Дивні сили, непередбачуваний у бою.",
		"move_range": 2, "hp": 33, "dmg":  8, "atk_range": 2,
		"color":      Color(0.75, 0.40, 0.75),
	},
	{
		"name":       "Бард",
		"desc":       "Слово сильніше за меч. Надихає загін, збиває ворогів з пантелику.",
		"move_range": 3, "hp": 31, "dmg":  7, "atk_range": 1,
		"color":      Color(0.95, 0.75, 0.40),
	},
]

# ── Кольори інтерфейсу ────────────────────────────────────────────────────
const C_BG       := Color(0.07, 0.06, 0.05)
const C_PANEL    := Color(0.11, 0.09, 0.07, 0.92)
const C_BORDER   := Color(0.45, 0.38, 0.28, 1.0)
const C_BORDER_S := Color(0.85, 0.65, 0.15, 1.0)
const C_TITLE    := Color(0.95, 0.80, 0.20)
const C_SEL      := Color(0.28, 0.20, 0.05, 0.95)
const C_HOV      := Color(0.18, 0.15, 0.09, 0.88)
const C_BTN_OK   := Color(0.18, 0.36, 0.12, 0.95)
const C_BTN_DIS  := Color(0.14, 0.14, 0.14, 0.70)

# ── Стан ─────────────────────────────────────────────────────────────────
var _name_buf:   String = ""
var _gender:     int    = 0   # 0 = чоловік  1 = жінка
var _sel_class:  int    = 0
var _hov_class:  int    = -1
var _hov_gender: int    = -1
var _cursor_t:   float  = 0.0
var _cursor_vis: bool   = true

func _ready() -> void:
	RenderingServer.set_default_clear_color(C_BG)

func _process(delta: float) -> void:
	_cursor_t += delta
	if _cursor_t >= 0.5:
		_cursor_t   = 0.0
		_cursor_vis = not _cursor_vis
		queue_redraw()

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_BACKSPACE:
			if _name_buf.length() > 0:
				_name_buf = _name_buf.left(_name_buf.length() - 1)
				queue_redraw()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			if _name_buf.strip_edges() != "":
				_confirm()
		elif key.unicode >= 32 and _name_buf.length() < 18:
			_name_buf += char(key.unicode)
			queue_redraw()

	elif event is InputEventMouseMotion:
		var pos    := (event as InputEventMouseMotion).position
		var prev_c := _hov_class; var prev_g := _hov_gender
		_hov_class = -1; _hov_gender = -1
		for i in CLASSES.size():
			if _class_row_rect(i).has_point(pos): _hov_class = i; break
		for i in 2:
			if _gender_rect(i).has_point(pos): _hov_gender = i; break
		if _hov_class != prev_c or _hov_gender != prev_g:
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		for i in 2:
			if _gender_rect(i).has_point(pos):
				_gender = i; queue_redraw(); return
		for i in CLASSES.size():
			if _class_row_rect(i).has_point(pos):
				_sel_class = i; queue_redraw(); return
		if _start_btn_rect().has_point(pos) and _name_buf.strip_edges() != "":
			_confirm()

func _confirm() -> void:
	var cls: Dictionary = CLASSES[_sel_class]
	var col: Color      = cls["color"]
	GameState.start_new_game({
		"name":       _name_buf.strip_edges(),
		"gender":     "m" if _gender == 0 else "f",
		"class_idx":  _sel_class,
		"spec_name":  cls["name"] as String,
		"move_range": cls["move_range"] as int,
		"hp":         cls["hp"]         as int,
		"dmg":        cls["dmg"]        as int,
		"atk_range":  cls["atk_range"]  as int,
		"color_r":    col.r,
		"color_g":    col.g,
		"color_b":    col.b,
	})
	get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")

# ── Позиції ───────────────────────────────────────────────────────────────
func _vp() -> Vector2:
	return get_viewport_rect().size

func _left_w() -> float:
	return _vp().x * 0.40

# Поле імені
func _name_rect() -> Rect2:
	return Rect2(24, 148, _left_w() - 36, 38)

# Кнопки статі
func _gender_rect(i: int) -> Rect2:
	var w := (_left_w() - 36) * 0.5 - 4
	return Rect2(24 + i * (w + 8), 212, w, 34)

# Рядок класу у правій панелі
func _class_row_rect(i: int) -> Rect2:
	var rx := _left_w() + 12
	var rw := _vp().x - rx - 16
	return Rect2(rx, 60 + i * 64.0, rw, 60.0)

func _start_btn_rect() -> Rect2:
	var vp := _vp()
	return Rect2(vp.x * 0.5 - 120, vp.y - 56, 240, 42)

# ── Рендер ────────────────────────────────────────────────────────────────
func _draw() -> void:
	var vp   := _vp()
	var font := ThemeDB.fallback_font
	var lw   := _left_w()

	# ── Ліва панель ───────────────────────────────────────────────────────
	draw_rect(Rect2(0, 0, lw, vp.y - 64), Color(0, 0, 0, 0.25))

	# Заголовок
	draw_string(font, Vector2(24, 44), "ГЕРОЙ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, C_TITLE)
	draw_string(font, Vector2(24, 68), "Людина",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.55))

	# Іконка класу (великий кружок)
	var cls: Dictionary = CLASSES[_sel_class]
	var ico_pos := Vector2(lw * 0.5, 310)
	var ico_col: Color = cls["color"]
	draw_circle(ico_pos, 46, ico_col * 0.55)
	draw_arc(ico_pos, 46, 0, TAU, 64, ico_col, 3.0)
	var hero_initial := _name_buf.strip_edges().left(1).to_upper()
	if hero_initial == "":
		hero_initial = "?"
	draw_string(font, ico_pos + Vector2(-5, 6), hero_initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	# Назва обраного класу під іконкою
	var cname: String = cls["name"]
	draw_string(font, Vector2(lw * 0.5 - 40, 372), cname,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_TITLE)

	# Стати обраного класу
	var atk: int = cls["atk_range"]; var rng_str := "дальній р.%d" % atk if atk > 1 else "ближній"
	var stat_lines: Array[String] = [
		"HP      %d" % (cls["hp"] as int),
		"АТК     %d" % (cls["dmg"] as int),
		"РУХ     %d" % (cls["move_range"] as int),
		rng_str,
	]
	var sy := 396.0
	for line in stat_lines:
		draw_string(font, Vector2(lw * 0.5 - 48, sy), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.68, 0.85, 0.55))
		sy += 18.0

	# Опис класу
	var desc: String = cls["desc"]
	var words := desc.split(" ")
	var line_buf := ""; var dy := 472.0
	for word in words:
		var test := (line_buf + " " + word).strip_edges()
		if test.length() > 28 and line_buf != "":
			draw_string(font, Vector2(16, dy), line_buf,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.55, 0.55))
			dy += 15.0; line_buf = word
		else:
			line_buf = test
	if line_buf != "":
		draw_string(font, Vector2(16, dy), line_buf,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.55, 0.55))

	# Роздільник лівої/правої панелей
	draw_line(Vector2(lw, 0), Vector2(lw, vp.y - 64), C_BORDER, 1.0)

	# ── Ім'я ──────────────────────────────────────────────────────────────
	draw_string(font, Vector2(24, 140), "Ім'я:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.65, 0.65))
	var nr := _name_rect()
	draw_rect(nr, Color(0.09, 0.08, 0.06))
	draw_rect(nr, C_BORDER_S, false, 1.5)
	draw_string(font, nr.position + Vector2(10, 25),
			_name_buf + ("|" if _cursor_vis else " "),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# ── Стать ─────────────────────────────────────────────────────────────
	draw_string(font, Vector2(24, 204), "Стать:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.65, 0.65))
	for i in 2:
		var gr   := _gender_rect(i)
		var is_s := i == _gender
		var is_h := i == _hov_gender
		draw_rect(gr, C_SEL if is_s else (C_HOV if is_h else C_PANEL))
		draw_rect(gr, C_BORDER_S if is_s else C_BORDER, false, 1.5 if is_s else 1.0)
		draw_string(font, gr.position + Vector2(10, 22),
				("♂ Чоловік" if i == 0 else "♀ Жінка"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color.WHITE if is_s else Color(0.70, 0.70, 0.70))

	# ── Права панель — список класів ─────────────────────────────────────
	draw_string(font, Vector2(lw + 14, 44), "Оберіть клас:",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.65, 0.65, 0.65))

	for i in CLASSES.size():
		var c: Dictionary = CLASSES[i]
		var rr   := _class_row_rect(i)
		var is_s := i == _sel_class
		var is_h := i == _hov_class
		var col: Color = c["color"]

		draw_rect(rr, C_SEL if is_s else (C_HOV if is_h else C_PANEL))
		draw_rect(rr, col if is_s else (C_BORDER if is_h else Color(C_BORDER, 0.4)),
				false, 1.5 if is_s else 1.0)

		# Маленький кружок класу
		var cc := Vector2(rr.position.x + 22, rr.position.y + 30)
		draw_circle(cc, 14, col * (0.7 if is_s else 0.4))
		draw_arc(cc, 14, 0, TAU, 32, col if is_s else Color(col, 0.5), 2.0)
		draw_string(font, cc + Vector2(-4, 5),
				(c["name"] as String).left(1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

		# Назва класу
		var name_col := C_TITLE if is_s else Color(0.80, 0.75, 0.65)
		draw_string(font, rr.position + Vector2(44, 24),
				c["name"] as String,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, name_col)

		# Короткі стати
		var ar: int = c["atk_range"]
		var stats := "HP:%d  АТК:%d  РУХ:%d  %s" % [
			c["hp"] as int, c["dmg"] as int, c["move_range"] as int,
			("дальній р.%d" % ar) if ar > 1 else "ближній"
		]
		draw_string(font, rr.position + Vector2(44, 44), stats,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(0.68, 0.88, 0.55) if is_s else Color(0.48, 0.48, 0.48))

	# ── Нижня панель ─────────────────────────────────────────────────────
	draw_rect(Rect2(0, vp.y - 64, vp.x, 64), Color(0, 0, 0, 0.55))

	var br    := _start_btn_rect()
	var can_start := _name_buf.strip_edges() != ""
	draw_rect(br, C_BTN_OK if can_start else C_BTN_DIS)
	draw_rect(br, C_BORDER_S if can_start else C_BORDER, false, 1.5)
	draw_string(font, br.position + Vector2(32, 27),
			"Почати пригоду!" if can_start else "Введіть ім'я...",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color.WHITE if can_start else Color(0.38, 0.38, 0.38))

	draw_string(font, Vector2(vp.x * 0.5 - 140, vp.y - 12),
			"Enter — підтвердити  ·  Backspace — стерти",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.35, 0.35, 0.35))
