extends CanvasLayer

# ── Пункти меню ───────────────────────────────────────────────────────────────
const MENU_ITEMS: Array[String] = [
	"Зберегти гру",
	"Завантажити гру",
	"Налаштування",
	"Вийти в головне меню",
]

# ── Стан ──────────────────────────────────────────────────────────────────────
var _open:          bool   = false
var _settings_open: bool   = false
var _hov_item:      int    = -1
var _status_msg:    String = ""
var _font:          Font   = null
var _drawer:        Node2D = null

# ── Внутрішній вузол для _draw() ──────────────────────────────────────────────
class _PauseDrawer extends Node2D:
	var draw_callback: Callable = Callable()
	func _draw() -> void:
		if draw_callback.is_valid():
			draw_callback.call(self)

# ── Ініціалізація ─────────────────────────────────────────────────────────────
func _ready() -> void:
	layer        = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font        = ThemeDB.fallback_font
	var d        := _PauseDrawer.new()
	d.draw_callback = _do_draw
	d.process_mode  = Node.PROCESS_MODE_ALWAYS
	add_child(d)
	_drawer = d

# ── Scale helper ──────────────────────────────────────────────────────────────
func _s() -> float:
	return get_viewport().get_visible_rect().size.y / 1080.0

# ── Відкрити / закрити ────────────────────────────────────────────────────────
func open() -> void:
	_open          = true
	_settings_open = false
	_hov_item      = -1
	get_tree().paused = true
	_drawer.queue_redraw()

func close() -> void:
	_open          = false
	_settings_open = false
	_hov_item      = -1
	get_tree().paused = false
	_drawer.queue_redraw()

# ── Fullscreen toggle ─────────────────────────────────────────────────────────
func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ── Глобальний перехват вводу ─────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event is InputEventKey:
			var ke := event as InputEventKey
			if ke.pressed and not ke.echo:
				match ke.keycode:
					KEY_ESCAPE:
						open()
						get_viewport().set_input_as_handled()
					KEY_F11:
						_toggle_fullscreen()
						get_viewport().set_input_as_handled()
		return

	# Меню відкрите — поглинаємо весь ввід
	get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		var prev := _hov_item
		_hov_item = -1
		for i in MENU_ITEMS.size():
			if _item_rect(i).has_point((event as InputEventMouseMotion).position):
				_hov_item = i; break
		if _hov_item != prev:
			_drawer.queue_redraw()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var pos := mb.position
			for i in MENU_ITEMS.size():
				if _item_rect(i).has_point(pos):
					_activate(i); return
			if not _popup_rect().has_point(pos):
				close()

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			match ke.keycode:
				KEY_ESCAPE:
					close()
				KEY_F11:
					_toggle_fullscreen()
				KEY_UP:
					_hov_item = posmod(_hov_item - 1, MENU_ITEMS.size())
					_drawer.queue_redraw()
				KEY_DOWN:
					_hov_item = posmod(_hov_item + 1, MENU_ITEMS.size())
					_drawer.queue_redraw()
				KEY_ENTER, KEY_KP_ENTER:
					if _hov_item >= 0:
						_activate(_hov_item)

# ── Активація пунктів ─────────────────────────────────────────────────────────
func _activate(i: int) -> void:
	match i:
		0:  # Зберегти гру
			var ssm := get_node_or_null("/root/SaveSlotMenu")
			if ssm: ssm.call("show_save")

		1:  # Завантажити гру
			var ssm := get_node_or_null("/root/SaveSlotMenu")
			if ssm: ssm.call("show_load")

		2:  # Налаштування
			_settings_open = not _settings_open
			_drawer.queue_redraw()

		3:  # Вийти в головне меню
			close()
			get_tree().change_scene_to_file("res://scenes/main_menu/MainMenuScene.tscn")

# ── Геометрія ─────────────────────────────────────────────────────────────────
func _popup_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var s  := vp.y / 1080.0
	return Rect2(vp.x * 0.5 - 220.0 * s, vp.y * 0.5 - 280.0 * s, 440.0 * s, 560.0 * s)

func _item_rect(i: int) -> Rect2:
	var pr := _popup_rect()
	var s  := _s()
	return Rect2(pr.position.x + 24.0 * s,
			pr.position.y + 104.0 * s + float(i) * 88.0 * s,
			pr.size.x - 48.0 * s, 72.0 * s)

# ── Рендер ────────────────────────────────────────────────────────────────────
func _do_draw(d: Node2D) -> void:
	if not _open:
		return
	var vp := get_viewport().get_visible_rect().size
	var pr := _popup_rect()
	var s  := vp.y / 1080.0

	# Затемнення екрану
	d.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.65))

	# Фон панелі
	d.draw_rect(pr, Color(0.07, 0.05, 0.03, 0.97))
	d.draw_rect(pr, Color(0.65, 0.50, 0.18, 1.0), false, 2.0)

	# Заголовок "ПАУЗА"
	d.draw_string(_font, pr.position + Vector2(0.0, 52.0 * s),
			"ПАУЗА", HORIZONTAL_ALIGNMENT_CENTER, int(pr.size.x), int(28.0 * s),
			Color(0.95, 0.82, 0.35))

	# Роздільник під заголовком
	d.draw_line(
			pr.position + Vector2(20.0 * s, 68.0 * s),
			pr.position + Vector2(pr.size.x - 20.0 * s, 68.0 * s),
			Color(0.55, 0.42, 0.15, 0.7), 1.0)

	# Пункти меню
	for i in MENU_ITEMS.size():
		var r      := _item_rect(i)
		var is_hov := i == _hov_item
		var is_set := i == 2 and _settings_open
		d.draw_rect(r,
				Color(0.28, 0.20, 0.08, 0.95) if (is_hov or is_set) else Color(0.12, 0.09, 0.04, 0.90))
		d.draw_rect(r,
				Color(0.75, 0.58, 0.20) if (is_hov or is_set) else Color(0.38, 0.30, 0.12),
				false, 1.0)
		d.draw_string(_font,
				r.position + Vector2(0.0, r.size.y * 0.5 + 7.0 * s),
				MENU_ITEMS[i], HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), int(17.0 * s),
				Color(1.0, 0.95, 0.75) if (is_hov or is_set) else Color(0.78, 0.73, 0.60))

	# Статусне повідомлення
	if _status_msg != "":
		var ok := _status_msg.begins_with("✔")
		d.draw_string(_font,
				pr.position + Vector2(0.0, pr.size.y - 22.0 * s),
				_status_msg, HORIZONTAL_ALIGNMENT_CENTER, int(pr.size.x), int(14.0 * s),
				Color(0.45, 0.95, 0.45) if ok else Color(0.95, 0.40, 0.40))

	# Підказка знизу
	d.draw_string(_font,
			pr.position + Vector2(0.0, pr.size.y + 26.0 * s),
			"Esc — закрити  ·  F11 — повний екран",
			HORIZONTAL_ALIGNMENT_CENTER, int(pr.size.x), int(12.0 * s),
			Color(0.42, 0.40, 0.32))

	# Підпанель налаштувань (праворуч від головної)
	if _settings_open:
		_draw_settings(d)

func _draw_settings(d: Node2D) -> void:
	var pr := _popup_rect()
	var s  := _s()
	var sr := Rect2(pr.position.x + pr.size.x + 12.0 * s, pr.position.y, 280.0 * s, 240.0 * s)

	d.draw_rect(sr, Color(0.07, 0.05, 0.03, 0.97))
	d.draw_rect(sr, Color(0.55, 0.42, 0.15, 1.0), false, 1.5)

	d.draw_string(_font, sr.position + Vector2(0.0, 34.0 * s),
			"Налаштування", HORIZONTAL_ALIGNMENT_CENTER, int(sr.size.x), int(17.0 * s),
			Color(0.90, 0.78, 0.30))
	d.draw_line(
			sr.position + Vector2(16.0 * s, 46.0 * s),
			sr.position + Vector2(sr.size.x - 16.0 * s, 46.0 * s),
			Color(0.45, 0.35, 0.12, 0.6), 1.0)

	# Placeholder — буде доповнено пізніше
	d.draw_string(_font, sr.position + Vector2(16.0 * s, 74.0 * s),
			"(незабаром)", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * s),
			Color(0.42, 0.40, 0.32))
