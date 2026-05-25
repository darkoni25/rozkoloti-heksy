extends CanvasLayer
## Глобальний попап вибору слота збереження.
## Відкривається з PauseMenu і MainMenuScene.
## Layer 101 — поверх PauseMenu (100).

enum Mode { SAVE, LOAD, NEW_GAME }

const SLOT_COUNT := 3
const MODE_TITLES: Array[String] = [
	"Зберегти гру",
	"Завантажити гру",
	"Нова гра — оберіть слот",
]

# ── Стан ──────────────────────────────────────────────────────────────────────
var _open:   bool = false
var _mode:   int  = Mode.LOAD   # int, не Mode — щоб уникнути проблем парсера
var _hov:    int  = -1          # 0-2 = слот, SLOT_COUNT = Скасувати, -1 = нічого
var _font:   Font = null
var _drawer: Node2D = null

# ── Внутрішній дравер ─────────────────────────────────────────────────────────
class _SlotDrawer extends Node2D:
	var draw_cb: Callable = Callable()
	func _draw() -> void:
		if draw_cb.is_valid():
			draw_cb.call(self)

# ── Ініціалізація ─────────────────────────────────────────────────────────────
func _ready() -> void:
	layer        = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font        = ThemeDB.fallback_font
	var d        := _SlotDrawer.new()
	d.draw_cb    = _do_draw
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(d)
	_drawer = d

# ── Scale helper ──────────────────────────────────────────────────────────────
func _s() -> float:
	return get_viewport().get_visible_rect().size.y / 1080.0

# ── Публічний API ─────────────────────────────────────────────────────────────
func show_save() -> void:
	_mode = Mode.SAVE;     _open_menu()

func show_load() -> void:
	_mode = Mode.LOAD;     _open_menu()

func show_new_game() -> void:
	_mode = Mode.NEW_GAME; _open_menu()

func _open_menu() -> void:
	_open = true
	_hov  = -1
	_drawer.queue_redraw()

func close() -> void:
	_open = false
	_hov  = -1
	_drawer.queue_redraw()

# ── Ввід ──────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		var prev := _hov
		_hov = _target_at((event as InputEventMouseMotion).position)
		if _hov != prev:
			_drawer.queue_redraw()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var t := _target_at(mb.position)
			if t == SLOT_COUNT:
				close()
			elif t >= 0:
				_activate(t)

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			close()

# ── Логіка активації ─────────────────────────────────────────────────────────
func _activate(slot: int) -> void:
	match _mode:
		Mode.SAVE:
			GameState.current_slot = slot
			GameState.save_game()
			close()

		Mode.LOAD:
			if not GameState.has_save(slot):
				return
			GameState.load_game(slot)
			_navigate_after_load()

		Mode.NEW_GAME:
			GameState.current_slot = slot
			var path := GameState.slot_path(slot)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			GameState._init_state()
			close()
			_close_pause_if_open()
			get_tree().change_scene_to_file(
				"res://scenes/character_creation/CharacterCreationScene.tscn")

func _navigate_after_load() -> void:
	close()
	_close_pause_if_open()
	if GameState.in_regional_map:
		get_tree().change_scene_to_file("res://scenes/world_map/RegionalMapScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")

func _close_pause_if_open() -> void:
	if PauseMenu._open:
		PauseMenu.close()

# ── Геометрія ─────────────────────────────────────────────────────────────────
func _panel_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var s  := vp.y / 1080.0
	return Rect2(vp.x * 0.5 - 450.0 * s, vp.y * 0.5 - 285.0 * s, 900.0 * s, 570.0 * s)

func _slot_rect(i: int) -> Rect2:
	var pr  := _panel_rect()
	var s   := _s()
	var gap := 20.0 * s
	var sw  := (pr.size.x - 40.0 * s - gap * float(SLOT_COUNT - 1)) / float(SLOT_COUNT)
	return Rect2(pr.position.x + 20.0 * s + float(i) * (sw + gap),
			pr.position.y + 76.0 * s, sw, 430.0 * s)

func _cancel_rect() -> Rect2:
	var pr := _panel_rect()
	var s  := _s()
	return Rect2(pr.position.x + pr.size.x * 0.5 - 100.0 * s,
			pr.position.y + pr.size.y - 56.0 * s, 200.0 * s, 40.0 * s)

func _target_at(pos: Vector2) -> int:
	for i in SLOT_COUNT:
		if _slot_rect(i).has_point(pos):
			return i
	if _cancel_rect().has_point(pos):
		return SLOT_COUNT
	return -1

# ── Рендер ────────────────────────────────────────────────────────────────────
func _do_draw(d: Node2D) -> void:
	if not _open:
		return
	var vp := get_viewport().get_visible_rect().size
	var pr := _panel_rect()
	var s  := vp.y / 1080.0

	# Затемнення
	d.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.75))

	# Панель
	d.draw_rect(pr, Color(0.06, 0.04, 0.03, 0.98))
	d.draw_rect(pr, Color(0.65, 0.50, 0.18, 1.0), false, 2.0)

	# Заголовок
	d.draw_string(_font, pr.position + Vector2(0.0, 44.0 * s),
			MODE_TITLES[_mode], HORIZONTAL_ALIGNMENT_CENTER, int(pr.size.x), int(22.0 * s),
			Color(0.95, 0.82, 0.35))

	# Роздільник
	d.draw_line(pr.position + Vector2(20.0 * s, 58.0 * s),
			pr.position + Vector2(pr.size.x - 20.0 * s, 58.0 * s),
			Color(0.55, 0.42, 0.15, 0.6), 1.0)

	# Картки слотів
	for i in SLOT_COUNT:
		_draw_slot_card(d, i)

	# Кнопка Скасувати
	var cr := _cancel_rect()
	var ch := _hov == SLOT_COUNT
	d.draw_rect(cr, Color(0.22, 0.10, 0.08, 0.9) if ch else Color(0.12, 0.08, 0.06, 0.9))
	d.draw_rect(cr, Color(0.55, 0.35, 0.15) if ch else Color(0.35, 0.25, 0.10), false, 1.0)
	d.draw_string(_font, cr.position + Vector2(0.0, cr.size.y * 0.5 + 6.0 * s),
			"Скасувати", HORIZONTAL_ALIGNMENT_CENTER, int(cr.size.x), int(15.0 * s),
			Color.WHITE if ch else Color(0.70, 0.65, 0.55))

func _draw_slot_card(d: Node2D, i: int) -> void:
	var r        := _slot_rect(i)
	var info     := GameState.get_slot_info(i)
	var empty    := info.is_empty()
	var is_hov   := i == _hov
	var disabled := _mode == Mode.LOAD and empty
	var s        := _s()

	# Фон картки
	var bg: Color
	if disabled: bg = Color(0.07, 0.06, 0.05, 0.85)
	elif is_hov: bg = Color(0.22, 0.16, 0.06, 0.95)
	else:        bg = Color(0.10, 0.08, 0.05, 0.90)
	d.draw_rect(r, bg)

	# Рамка
	var bc: Color
	if disabled: bc = Color(0.25, 0.20, 0.12)
	elif is_hov: bc = Color(0.80, 0.60, 0.22)
	else:        bc = Color(0.45, 0.35, 0.15)
	d.draw_rect(r, bc, false, 2.0 if is_hov else 1.0)

	# Заголовок слота
	var slot_col := Color(0.35, 0.30, 0.20) if disabled else \
			(Color(0.90, 0.74, 0.30) if is_hov else Color(0.65, 0.52, 0.22))
	d.draw_string(_font, r.position + Vector2(0.0, 24.0 * s),
			"СЛОТ %d" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(14.0 * s), slot_col)

	d.draw_line(r.position + Vector2(12.0 * s, 32.0 * s),
			r.position + Vector2(r.size.x - 12.0 * s, 32.0 * s),
			Color(0.45, 0.35, 0.15, 0.45), 1.0)

	if empty:
		d.draw_string(_font, r.position + Vector2(0.0, r.size.y * 0.5 + 7.0 * s),
				"[ Порожньо ]", HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(14.0 * s),
				Color(0.35, 0.32, 0.25) if disabled else Color(0.52, 0.46, 0.32))
		if is_hov and not disabled:
			d.draw_string(_font, r.position + Vector2(0.0, r.size.y * 0.5 + 30.0 * s),
					"→ Нова гра", HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(12.0 * s),
					Color(0.65, 0.90, 0.50))
	else:
		var name_str  : String = str(info.get("name",     "???"))
		var class_str : String = str(info.get("class",    ""))
		var loc_str   : String = str(info.get("location", ""))
		var date_str  : String = str(info.get("date",     ""))
		var level     : int    = int(info.get("level",    1))

		var tc := Color(0.40, 0.38, 0.48) if disabled else Color(0.70, 0.65, 0.88)
		var nc := Color(0.55, 0.50, 0.35) if disabled else Color(0.95, 0.86, 0.55)
		var lc := Color(0.32, 0.42, 0.32) if disabled else Color(0.52, 0.78, 0.52)
		var dc := Color(0.35, 0.32, 0.25)

		var y := r.position.y + 56.0 * s

		d.draw_string(_font, Vector2(r.position.x, y),
				name_str, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(19.0 * s), nc)
		y += 28.0 * s
		d.draw_string(_font, Vector2(r.position.x, y),
				"%s  Рів.%d" % [class_str, level],
				HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(13.0 * s), tc)
		y += 22.0 * s
		d.draw_string(_font, Vector2(r.position.x, y),
				loc_str, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(13.0 * s), lc)
		y += 28.0 * s
		d.draw_line(Vector2(r.position.x + 12.0 * s, y),
				Vector2(r.position.x + r.size.x - 12.0 * s, y),
				Color(0.40, 0.32, 0.12, 0.35), 1.0)

		# Дата — знизу картки
		d.draw_string(_font,
				Vector2(r.position.x, r.position.y + r.size.y - 20.0 * s),
				date_str, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(11.0 * s), dc)

		# Дія при hover
		if is_hov:
			var act: String
			match _mode:
				Mode.SAVE:     act = "→ Перезаписати"
				Mode.LOAD:     act = "→ Завантажити"
				Mode.NEW_GAME: act = "→ Стерти й почати знову"
			var act_col := Color(0.90, 0.40, 0.30) if _mode == Mode.NEW_GAME \
					else Color(0.90, 0.78, 0.30)
			d.draw_string(_font,
					r.position + Vector2(0.0, r.size.y - 46.0 * s),
					act, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(13.0 * s), act_col)
