extends Node2D

# ── Дані споруд ───────────────────────────────────────────────────────────
const BUILDINGS = [
	{"name": "Каплиця",         "companion": "Клірик",  "wood": 20, "stone": 10, "metal": 0,  "effect": "+15% HP загону"},
	{"name": "Казарма",          "companion": "Воїн",    "wood": 30, "stone": 20, "metal": 10, "effect": "+10 HP загону"},
	{"name": "Гільдія злодіїв",  "companion": "Злодій",  "wood": 25, "stone": 10, "metal": 15, "effect": "лут ×1.5"},
	{"name": "Башта мага",       "companion": "Маг",     "wood": 20, "stone": 30, "metal": 10, "effect": "+10 маг.бар."},
	{"name": "Мисливська хижа",  "companion": "Мисл.",   "wood": 35, "stone": 10, "metal": 5,  "effect": "+1 їжа/роб."},
	{"name": "Святилище тіней",  "companion": "Оккуль.", "wood": 25, "stone": 15, "metal": 20, "effect": "крит ×1.5"},
	{"name": "Таверна",          "companion": "Бард",    "wood": 30, "stone": 15, "metal": 5,  "effect": "XP ×1.25"},
	{"name": "Кузня",            "companion": "",        "wood": 25, "stone": 30, "metal": 25, "effect": "дає спорядження"},
]

# ── Layout ────────────────────────────────────────────────────────────────
const TOP_H   := 56.0
const BOT_H   := 44.0
const RIGHT_W := 220.0

# Фонове зображення (1672×941 ≈ 16:9)
const BG_W := 1672.0
const BG_H := 941.0

# UV-позиції 8 платформ (частка від BG_W/BG_H, anchor = низ-центр платформи)
# Порядок відповідає slot index 0-7; налаштуй якщо треба зміщення
const SLOT_UV: Array[Vector2] = [
	Vector2(0.227, 0.298),  # 0 — ліво-верх   (Каплиця за замовч.)
	Vector2(0.634, 0.285),  # 1 — право-верх  (Казарма)
	Vector2(0.093, 0.521),  # 2 — далеко-ліво (Мисл. хижа)
	Vector2(0.897, 0.508),  # 3 — далеко-право(Таверна)
	Vector2(0.167, 0.689),  # 4 — низ-ліво    (Гільдія злодіїв)
	Vector2(0.831, 0.674),  # 5 — низ-право   (Кузня)
	Vector2(0.322, 0.833),  # 6 — дно-ліво    (Святилище)
	Vector2(0.512, 0.887),  # 7 — дно-центр   (Башта мага ★)
]

# Яка «руїна» показується у порожньому слоті (building id за замовч.)
# Відповідає логіці розташування вище
const SLOT_DEFAULT_BID: Array[int] = [0, 1, 4, 6, 2, 7, 5, 3]

# Ширина спрайту будівлі як частка від vp.x (підбери під розмір платформ)
const SPRITE_W_FRAC := 0.155

# Половина розміру клікабельної зони слота (у частках vp)
const SLOT_HIT_HW := 0.090   # half-width
const SLOT_HIT_HH := 0.085   # half-height

# Назви файлів спрайтів (індекс = building id, як у BUILDINGS)
const TEX_NAMES: Array[String] = [
	"chapel", "barracks", "thieves_guild", "mage_tower",
	"hunter_lodge", "shadow_sanctuary", "tavern", "forge",
]

# ── Кольори ───────────────────────────────────────────────────────────────
const C_EMPTY    := Color(0.14, 0.11, 0.08, 1.0)
const C_BUILT    := Color(0.18, 0.14, 0.10, 1.0)
const C_SEL      := Color(0.38, 0.28, 0.08, 0.9)
const C_HOV      := Color(0.22, 0.18, 0.10, 0.9)
const C_BORDER   := Color(0.45, 0.38, 0.28, 1.0)
const C_BORDER_S := Color(0.85, 0.65, 0.15, 1.0)
const C_HDR      := Color(0.42, 0.30, 0.08, 1.0)
const C_MENU_OK  := Color(0.26, 0.20, 0.08, 0.95)
const C_MENU_HOV := Color(0.40, 0.30, 0.10, 0.95)
const C_MENU_NO  := Color(0.16, 0.08, 0.08, 0.95)
const C_IN_PARTY := Color(0.10, 0.22, 0.10, 0.9)
const C_HOV_ROW  := Color(0.20, 0.17, 0.10, 0.85)

# ── Стан ─────────────────────────────────────────────────────────────────
var _resources: Dictionary[String, int]:
	get: return GameState.resources
var _slots: Array[int]:
	get: return GameState.base_slots
var _sel_slot:      int    = -1
var _hov_slot:      int    = -1
var _hov_menu:      int    = -1
var _hov_companion: int    = -1
var _status:        String = ""
var _show_workers:  bool   = false
var _hov_wbtn:      int    = -1   # res_i * 2 + 0/1 (мінус/плюс)
var _show_equip:     bool = false
var _equip_char_idx: int  = 0
var _equip_hov_tab:  int  = -1
var _equip_hov_slot: int  = -1
var _equip_sel_slot: int  = -1   # обраний слот (для показу відповідних предметів)
var _equip_inv_off:  int  = 0    # зсув прокрутки інвентаря

# ── Текстури ──────────────────────────────────────────────────────────────
var _tex_bg:       Texture2D           = null
var _tex_restored: Array[Texture2D]   = []
var _tex_ruined:   Array[Texture2D]   = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.05, 0.04))
	_load_textures()
	if not GameState.hero_created:
		get_tree().change_scene_to_file(
			"res://scenes/character_creation/CharacterCreationScene.tscn")

func _load_textures() -> void:
	_tex_bg = load("res://assets/textures/Base/Back_ground.png") as Texture2D
	_tex_restored.resize(TEX_NAMES.size())
	_tex_ruined.resize(TEX_NAMES.size())
	for i in TEX_NAMES.size():
		var n := TEX_NAMES[i]
		_tex_restored[i] = load("res://assets/textures/Base/%s_restored.png" % n) as Texture2D
		_tex_ruined[i]   = load("res://assets/textures/Base/%s_ruined.png"   % n) as Texture2D

# ── Допоміжні ────────────────────────────────────────────────────────────
func _slot_rect(i: int) -> Rect2:
	var vp := get_viewport_rect().size
	var uv := SLOT_UV[i]
	var cx := uv.x * vp.x
	var cy := uv.y * vp.y
	var hw := SLOT_HIT_HW * vp.x
	var hh := SLOT_HIT_HH * vp.y
	return Rect2(cx - hw, cy - hh, hw * 2.0, hh * 2.0)

func _menu_rect(menu_i: int) -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - RIGHT_W + 8, TOP_H + 30 + menu_i * 64.0, RIGHT_W - 16, 60.0)

func _map_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 36, 163, 28)

func _workers_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 74, 163, 28)

func _equip_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 112, 163, 28)

func _equip_popup_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 280, vp.y * 0.5 - 300, 560, 600)

func _equip_close_rect() -> Rect2:
	var pr := _equip_popup_rect()
	return Rect2(pr.position.x + pr.size.x - 32, pr.position.y + 6, 26, 26)

func _equip_tab_rect(tab_i: int) -> Rect2:
	var pr := _equip_popup_rect()
	return Rect2(pr.position.x + 8 + tab_i * 108.0, pr.position.y + 38, 102, 28)

# 11 слотів у 2 колонки, 6 рядів; слоти 8-10 — спеціальне розташування
func _equip_slot_rect(slot_i: int) -> Rect2:
	var pr  := _equip_popup_rect()
	var col: int
	var row: int
	match slot_i:
		8:  col = 0; row = 4   # ring2 (ring1 займає col1 row3)
		9:  col = 0; row = 5   # main_hand
		10: col = 1; row = 5   # off_hand
		_:
			col = slot_i % 2
			row = slot_i >> 1
	return Rect2(pr.position.x + 8 + col * 278.0, pr.position.y + 76 + row * 56.0, 268, 50)

# Rect для кнопок прокрутки і рядків інвентаря (нижня частина попапу)
func _inv_header_y() -> float:
	return _equip_popup_rect().position.y + 76 + 6 * 56.0 + 8.0   # після слотів

func _inv_item_rect(row_i: int) -> Rect2:
	var pr := _equip_popup_rect()
	var iy := _inv_header_y() + 24.0 + row_i * 34.0
	return Rect2(pr.position.x + 8, iy, pr.size.x - 56, 30)

func _inv_scroll_up_rect() -> Rect2:
	var pr := _equip_popup_rect()
	return Rect2(pr.position.x + pr.size.x - 44, _inv_header_y() + 24, 36, 30)

func _inv_scroll_dn_rect() -> Rect2:
	var pr := _equip_popup_rect()
	return Rect2(pr.position.x + pr.size.x - 44, _inv_header_y() + 58, 36, 30)

func _popup_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 210, vp.y * 0.5 - 165, 420, 330)

func _popup_close_rect() -> Rect2:
	var pr := _popup_rect()
	return Rect2(pr.position.x + pr.size.x - 32, pr.position.y + 6, 26, 26)

func _popup_minus_rect(ri: int) -> Rect2:
	var pr := _popup_rect()
	return Rect2(pr.position.x + pr.size.x - 104, pr.position.y + 84 + ri * 54.0 + 12, 26, 26)

func _popup_plus_rect(ri: int) -> Rect2:
	var pr := _popup_rect()
	return Rect2(pr.position.x + pr.size.x - 38, pr.position.y + 84 + ri * 54.0 + 12, 26, 26)

func _companion_row_rect(row_i: int) -> Rect2:
	var vp := get_viewport_rect().size
	var rx := vp.x - RIGHT_W
	return Rect2(rx + 4, TOP_H + 112.0 + row_i * 44.0, RIGHT_W - 8, 40.0)

func _available() -> Array[int]:
	var built: Array[int] = []
	for bid in _slots:
		if bid != -1:
			built.append(bid)
	var result: Array[int] = []
	for i in BUILDINGS.size():
		if not built.has(i):
			result.append(i)
	return result

func _can_afford(bid: int) -> bool:
	var b: Dictionary = BUILDINGS[bid]
	var w: int = b["wood"]; var s: int = b["stone"]; var m: int = b["metal"]
	return _resources["wood"] >= w and _resources["stone"] >= s and _resources["metal"] >= m

func _build(slot: int, bid: int) -> void:
	var b: Dictionary = BUILDINGS[bid]
	_resources["wood"]  -= b["wood"]  as int
	_resources["stone"] -= b["stone"] as int
	_resources["metal"] -= b["metal"] as int
	_slots[slot] = bid
	var companion: String = b["companion"]
	_status = "Побудовано: %s%s" % [
		b["name"] as String,
		"  →  %s приєднується!" % companion if companion != "" else ""
	]
	# Після наступного циклу прийдуть нові люди
	if GameState.BUILDING_POPULATION.has(bid):
		GameState.pending_population += int(GameState.BUILDING_POPULATION[bid])
	# Кузня (bid 7) — одразу наповнює інвентар базовим спорядженням
	if bid == 7:
		GameState.give_smithy_items()

	# Дати стартове спорядження ВСІМ компаньйонам цієї будівлі (поки вони без предметів)
	for ci in GameState.COMPANIONS.size():
		var comp: Dictionary = GameState.COMPANIONS[ci]
		if int(comp["building"]) == bid:
			GameState.give_starter_items(int(comp["class_idx"]), "c%d" % ci)

	# Авто-додати першого компаньйона нової будівлі в загін якщо є місце
	for ci in GameState.COMPANIONS.size():
		var comp: Dictionary = GameState.COMPANIONS[ci]
		if int(comp["building"]) == bid and not GameState.raid_party.has(ci):
			if GameState.raid_party.size() < 3:
				GameState.raid_party.append(ci)
			break
	GameState.save_game()
	_sel_slot = -1; _hov_menu = -1

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		# Попапи мають пріоритет — не перетираємо hover основного UI
		if _show_equip:
			var prev_t := _equip_hov_tab; var prev_s := _equip_hov_slot
			_equip_hov_tab = -1; _equip_hov_slot = -1
			var chars := _equip_chars()
			for i in chars.size():
				if _equip_tab_rect(i).has_point(pos): _equip_hov_tab = i; break
			if _equip_hov_tab == -1:
				for i in GameState.EQUIP_SLOTS.size():
					if _equip_slot_rect(i).has_point(pos): _equip_hov_slot = i; break
			if _equip_hov_tab != prev_t or _equip_hov_slot != prev_s: queue_redraw()
			return
		if _show_workers:
			var prev := _hov_wbtn
			_hov_wbtn = -1
			var rkeys: Array[String] = ["wood", "stone", "metal", "food"]
			for ri in rkeys.size():
				if _popup_minus_rect(ri).has_point(pos): _hov_wbtn = ri * 2;     break
				if _popup_plus_rect(ri).has_point(pos):  _hov_wbtn = ri * 2 + 1; break
			if _hov_wbtn != prev: queue_redraw()
			return
		_hov_slot = -1; _hov_menu = -1; _hov_companion = -1
		for i in 8:
			if _slot_rect(i).has_point(pos):
				_hov_slot = i; break
		if _sel_slot != -1:
			var avail := _available()
			for i in avail.size():
				if _menu_rect(i).has_point(pos):
					_hov_menu = i; break
		elif _hov_slot == -1:
			var rows := GameState.get_available_companions()
			for i in rows.size():
				if _companion_row_rect(i).has_point(pos):
					_hov_companion = i; break
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position

		# Popup спорядження
		if _show_equip:
			if _equip_close_rect().has_point(pos):
				_show_equip = false; _equip_sel_slot = -1; queue_redraw(); return
			var chars := _equip_chars()
			# Клік на вкладку персонажа
			for i in chars.size():
				if _equip_tab_rect(i).has_point(pos):
					_equip_char_idx = i; _equip_sel_slot = -1; _equip_inv_off = 0
					queue_redraw(); return
			if not chars.is_empty():
				_equip_char_idx = mini(_equip_char_idx, chars.size() - 1)
				var char_key: String = chars[_equip_char_idx]["key"] as String
				# Клік на слот — обираємо або знімаємо
				for si in GameState.EQUIP_SLOTS.size():
					if _equip_slot_rect(si).has_point(pos):
						var slot: String = GameState.EQUIP_SLOTS[si]
						if _equip_sel_slot == si:
							# Повторний клік на обраний слот з предметом — зняти
							var item := GameState.get_equipped_item(char_key, slot)
							if not item.is_empty():
								GameState.unequip_item(char_key, slot)
								_status = "Знято: " + (item.get("name", "?") as String)
							_equip_sel_slot = -1
						else:
							_equip_sel_slot = si; _equip_inv_off = 0
						queue_redraw(); return
				# Клік на рядок інвентаря — екіпірувати
				if _equip_sel_slot != -1:
					var slot: String = GameState.EQUIP_SLOTS[_equip_sel_slot]
					var matching := _matching_items(char_key, slot)
					for ri in mini(4, matching.size()):
						if _inv_item_rect(ri).has_point(pos):
							var inv_idx: int = matching[_equip_inv_off + ri]
							GameState.equip_item(char_key, slot, inv_idx)
							_status = "Надіто: " + (GameState.inventory[inv_idx].get("name", "?") as String)
							_equip_sel_slot = -1; _equip_inv_off = 0
							queue_redraw(); return
					# Прокрутка
					if _inv_scroll_up_rect().has_point(pos):
						_equip_inv_off = maxi(0, _equip_inv_off - 1); queue_redraw(); return
					if _inv_scroll_dn_rect().has_point(pos):
						_equip_inv_off = mini(maxi(0, matching.size() - 4), _equip_inv_off + 1)
						queue_redraw(); return
			if not _equip_popup_rect().has_point(pos):
				_show_equip = false; _equip_sel_slot = -1; queue_redraw()
			return

		# Popup робітників
		if _show_workers:
			if _popup_close_rect().has_point(pos):
				_show_workers = false; queue_redraw(); return
			var rkeys: Array[String] = ["wood", "stone", "metal", "food"]
			for ri in rkeys.size():
				var key: String = rkeys[ri]
				if _popup_minus_rect(ri).has_point(pos):
					GameState.workers[key] = maxi(0, GameState.workers.get(key, 0) - 1)
					queue_redraw(); return
				if _popup_plus_rect(ri).has_point(pos):
					var used: int = 0
					for k in GameState.workers: used += int(GameState.workers[k])
					if used < GameState.population:
						GameState.workers[key] = GameState.workers.get(key, 0) + 1
					queue_redraw(); return
			if not _popup_rect().has_point(pos):
				_show_workers = false; queue_redraw()
			return

		if _map_btn_rect().has_point(pos):
			get_tree().change_scene_to_file("res://scenes/world_map/WorldMapScene.tscn")
			return
		if _equip_btn_rect().has_point(pos):
			_show_equip = true; _show_workers = false; _sel_slot = -1
			_equip_char_idx = 0; queue_redraw(); return
		if _workers_btn_rect().has_point(pos):
			_show_workers = true; _show_equip = false; _sel_slot = -1; queue_redraw(); return
		for i in 8:
			if _slot_rect(i).has_point(pos):
				_sel_slot = i if (_slots[i] == -1 and _sel_slot != i) else -1
				_hov_menu = -1; queue_redraw(); return
		if _sel_slot != -1:
			var avail := _available()
			for i in avail.size():
				if _menu_rect(i).has_point(pos):
					var bid: int = avail[i]
					if _can_afford(bid):
						_build(_sel_slot, bid)
					else:
						var b: Dictionary = BUILDINGS[bid]
						_status = "Не вистачає ресурсів для: %s" % (b["name"] as String)
						_sel_slot = -1
					queue_redraw(); return
		else:
			# Клік по рядку компаньйона — перемикання в/з загону
			var rows := GameState.get_available_companions()
			for i in rows.size():
				if _companion_row_rect(i).has_point(pos):
					var uid: int = rows[i]
					if GameState.raid_party.has(uid):
						GameState.raid_party.erase(uid)
					elif GameState.raid_party.size() < 3:
						GameState.raid_party.append(uid)
					queue_redraw(); return
		_sel_slot = -1; queue_redraw()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _show_equip:
				_show_equip = false; _equip_sel_slot = -1; queue_redraw()
				get_viewport().set_input_as_handled()
			elif _show_workers:
				_show_workers = false; queue_redraw()
				get_viewport().set_input_as_handled()
			elif _sel_slot != -1:
				_sel_slot = -1; queue_redraw()
				get_viewport().set_input_as_handled()
			# else — подія іде до PauseMenu._unhandled_input

# ── Рендер ───────────────────────────────────────────────────────────────
func _draw_bg_and_buildings() -> void:
	var vp := get_viewport_rect().size
	# Фон — розтягнутий на весь вьюпорт (fill)
	if _tex_bg != null:
		draw_texture_rect(_tex_bg, Rect2(Vector2.ZERO, vp), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.06, 0.05, 0.04))
	# Спрайти будівель — bottom-center прив'язаний до UV-позиції платформи
	var sw := SPRITE_W_FRAC * vp.x
	for i in 8:
		var bid     : int = _slots[i]
		var def_bid : int = SLOT_DEFAULT_BID[i]
		var tex: Texture2D
		if bid != -1:
			tex = _tex_restored[bid]
		else:
			tex = _tex_ruined[def_bid]
		if tex == null:
			continue
		var uv := SLOT_UV[i]
		var cx := uv.x * vp.x
		var cy := uv.y * vp.y
		# Висота зберігає пропорції спрайту
		var sh := sw * float(tex.get_height()) / float(tex.get_width())
		# Якір — низ-центр платформи
		draw_texture_rect(tex, Rect2(cx - sw * 0.5, cy - sh, sw, sh), false)

# Повертає індекси предметів в inventory, що підходять до слоту і не надіті на персонажа
func _matching_items(_char_key: String, slot: String) -> Array[int]:
	# Збираємо всі індекси що вже надіті на БУДЬ-ЯКОГО персонажа
	var in_use: Array[int] = []
	for ckey in GameState.equipped:
		var d: Dictionary = GameState.equipped[ckey] as Dictionary
		for s in d:
			var idx := int(d[s])
			if not in_use.has(idx):
				in_use.append(idx)

	var result: Array[int] = []
	for idx in GameState.inventory.size():
		var item = GameState.inventory[idx]
		if not item is Dictionary:
			continue
		if not GameState.item_fits_slot(item as Dictionary, slot):
			continue
		if in_use.has(idx):
			continue   # Вже надіто — на цьому або іншому персонажі
		result.append(idx)
	return result

func _equip_chars() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if GameState.hero_created:
		result.append({"key": "hero", "name": GameState.hero.get("name", "Герой") as String})
	for uid in GameState.raid_party:
		if uid < GameState.COMPANIONS.size():
			var c: Dictionary = GameState.COMPANIONS[uid]
			result.append({"key": "c%d" % uid, "name": c["name"] as String})
	return result

func _draw() -> void:
	var vp   := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	_draw_bg_and_buildings()
	_draw_resources(font, vp)
	_draw_slots(font)
	_draw_right_panel(font, vp)
	_draw_status(font, vp)
	if _show_equip:
		_draw_equip_popup(font)
	elif _show_workers:
		_draw_worker_popup(font)

func _draw_resources(font: Font, vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, TOP_H), Color(0, 0, 0, 0.6))
	var labels: Array[String] = ["Дерево", "Камінь", "Метал", "Їжа"]
	var keys:   Array[String] = ["wood",   "stone",  "metal", "food"]
	var colors: Array[Color]  = [Color(0.6,0.4,0.1), Color(0.55,0.55,0.55), Color(0.4,0.6,0.8), Color(0.3,0.7,0.3)]
	var cols := 4
	var sw   := (vp.x - RIGHT_W) / cols
	for i in cols:
		var cx := sw * i + sw * 0.5
		draw_rect(Rect2(cx - 10, 16, 20, 20), colors[i])
		var val: int = _resources[keys[i]]
		draw_string(font, Vector2(cx - 38, 50), "%s: %d" % [labels[i], val],
				HORIZONTAL_ALIGNMENT_CENTER, 76, 14, Color.WHITE)

func _draw_slots(font: Font) -> void:
	for i in 8:
		var r      := _slot_rect(i)
		var bid    : int = _slots[i]
		var is_sel := i == _sel_slot
		var is_hov := i == _hov_slot

		if is_sel:
			# Золоте виділення + підказка
			draw_rect(r, Color(0.85, 0.65, 0.15, 0.22))
			draw_rect(r, C_BORDER_S, false, 2.0)
			draw_string(font, r.position + Vector2(0.0, r.size.y - 10.0),
					"Обери споруду", HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 12,
					Color(0.9, 0.8, 0.3))
		elif is_hov and bid == -1:
			# Підсвічування порожнього слота
			draw_rect(r, Color(0.22, 0.18, 0.10, 0.30))
			draw_rect(r, C_BORDER, false, 1.5)
			draw_string(font, r.position + Vector2(0.0, r.size.y - 10.0),
					"клік — будувати", HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 11,
					Color(0.85, 0.75, 0.40))
		elif is_hov and bid != -1:
			# Підсвічування побудованої будівлі
			var b: Dictionary = BUILDINGS[bid]
			draw_rect(r, Color(0.0, 0.0, 0.0, 0.28))
			draw_rect(r, C_BORDER, false, 1.0)
			draw_string(font, r.position + Vector2(0.0, r.size.y - 10.0),
					b["name"] as String, HORIZONTAL_ALIGNMENT_CENTER, int(r.size.x), 12,
					Color(0.95, 0.85, 0.50))

func _draw_right_panel(font: Font, vp: Vector2) -> void:
	var rx := vp.x - RIGHT_W
	draw_rect(Rect2(rx, 0, RIGHT_W, vp.y), Color(0, 0, 0, 0.45))
	draw_line(Vector2(rx, 0), Vector2(rx, vp.y), C_BORDER, 1.0)

	if _sel_slot != -1:
		# ── Меню будівництва ────────────────────────────────────────────
		draw_string(font, Vector2(rx + 8, TOP_H + 20), "Що будуємо?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.8, 0.3))
		var avail := _available()
		for i in avail.size():
			var bid:   int        = avail[i]
			var b:     Dictionary = BUILDINGS[bid]
			var mr                := _menu_rect(i)
			var afford            := _can_afford(bid)
			var is_hov            := i == _hov_menu

			draw_rect(mr, C_MENU_HOV if is_hov and afford else (C_MENU_OK if afford else C_MENU_NO))
			draw_rect(mr, C_BORDER_S if is_hov else C_BORDER, false, 1.0)

			var name_col := Color.WHITE if afford else Color(0.45, 0.45, 0.45)
			draw_string(font, mr.position + Vector2(7, 19), b["name"] as String,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, name_col)

			var w: int = b["wood"]; var s: int = b["stone"]; var m: int = b["metal"]
			var cost_col := Color(0.65, 0.9, 0.55) if afford else Color(0.8, 0.35, 0.35)
			draw_string(font, mr.position + Vector2(7, 37), "Д:%d  К:%d  М:%d" % [w, s, m],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cost_col)

			var companion: String = b["companion"] as String
			var effect:    String = b.get("effect", "") as String
			var comp_eff: String
			if companion != "" and effect != "":
				comp_eff = "→ %s  ·  %s" % [companion, effect]
			elif companion != "":
				comp_eff = "→ " + companion
			else:
				comp_eff = "·  " + effect
			if comp_eff != "":
				draw_string(font, mr.position + Vector2(7, 53), comp_eff,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.72, 0.9))
	else:
		# ── Картка героя ─────────────────────────────────────────────────
		var h: Dictionary = GameState.hero
		if not h.is_empty():
			var hr := Rect2(rx + 4, TOP_H + 8, RIGHT_W - 8, 82)
			draw_rect(hr, Color(0.18, 0.14, 0.07, 0.9))
			draw_rect(hr, Color(0.85, 0.65, 0.15), false, 1.5)
			# Кружок + рівень
			var hcol     := GameState.get_hero_color()
			var hinitial := (h.get("name", "Г") as String).left(1).to_upper()
			draw_circle(Vector2(rx + 24, TOP_H + 45), 14, hcol)
			draw_arc(Vector2(rx + 24, TOP_H + 45), 14, 0, TAU, 32, Color.WHITE, 2.0)
			draw_string(font, Vector2(rx + 19, TOP_H + 50), hinitial,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			# Ім'я та спеціалізація
			var hname: String = h.get("name", "Герой") as String
			var hspec: String = h.get("spec_name", "") as String
			var hlvl:  int    = GameState.get_hero_level()
			draw_string(font, Vector2(rx + 44, TOP_H + 25), hname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.80, 0.20))
			draw_string(font, Vector2(rx + 44, TOP_H + 40),
					"%s  Рів.%d" % [hspec, hlvl],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.65, 0.65))
			# Стан / стати
			if GameState.hero_recovery_raids > 0:
				draw_string(font, Vector2(rx + 8, TOP_H + 57),
						"⚕ Відновлення — наступний рейд без героя",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.55, 0.20))
			else:
				var gender_sym := "♂" if h.get("gender", "m") == "m" else "♀"
				draw_string(font, Vector2(rx + 44, TOP_H + 55),
						"%s  HP:%d  АТК:%d" % [gender_sym, h.get("hp", 50) as int, h.get("dmg", 12) as int],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.55, 0.55))
			# XP-бар
			var xp_bar_x := rx + 8.0;  var xp_bar_w := float(RIGHT_W - 16)
			var xp_by    := TOP_H + 72.0
			var hxp: int = int(h.get("xp", 0))
			var xp_ratio := 1.0
			if hlvl < GameState.MAX_LEVEL:
				var xp_s := GameState.LEVEL_XP[hlvl - 1]
				var xp_e := GameState.LEVEL_XP[hlvl]
				xp_ratio = clampf(float(hxp - xp_s) / float(xp_e - xp_s), 0.0, 1.0)
			draw_rect(Rect2(xp_bar_x, xp_by, xp_bar_w, 6), Color(0.10, 0.10, 0.10))
			draw_rect(Rect2(xp_bar_x, xp_by, xp_bar_w * xp_ratio, 6),
					Color(0.55, 0.42, 0.80) if hlvl < GameState.MAX_LEVEL else Color(0.90, 0.75, 0.20))
			var xp_label: String = "XP %d" % hxp if hlvl >= GameState.MAX_LEVEL \
					else "XP %d / %d" % [hxp, GameState.LEVEL_XP[hlvl]]
			draw_string(font, Vector2(xp_bar_x, xp_by - 1), xp_label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.50, 0.70))

		# ── Загін / компаньйони ──────────────────────────────────────────
		var party_count: int = GameState.raid_party.size()
		draw_string(font, Vector2(rx + 8, TOP_H + 88), "Загін  (%d/3):" % party_count,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.80, 0.5))
		draw_string(font, Vector2(rx + 8, TOP_H + 104), "клік — додати/прибрати",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5))

		var rows := GameState.get_available_companions()
		for i in rows.size():
			var uid: int      = rows[i]
			var c: Dictionary = GameState.COMPANIONS[uid]
			var in_party      := GameState.raid_party.has(uid)
			var is_hov        := i == _hov_companion
			var rr            := _companion_row_rect(i)

			var bg: Color
			if in_party:    bg = C_IN_PARTY
			elif is_hov:    bg = C_HOV_ROW
			else:           bg = Color(0.10, 0.10, 0.10, 0.5)
			draw_rect(rr, bg)
			draw_rect(rr, C_BORDER_S if in_party else (C_BORDER if is_hov else Color(C_BORDER, 0.4)),
					false, 1.0)

			var prefix := "[+] " if in_party else "[ ] "
			var name_col := Color(0.7, 1.0, 0.7) if in_party else Color(0.75, 0.75, 0.75)
			var clvl: int = GameState.get_companion_level(uid)
			var lvl_col := Color(0.85, 0.75, 1.0) if in_party else Color(0.50, 0.47, 0.55)
			draw_string(font, rr.position + Vector2(6, 16), prefix + (c["name"] as String),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, name_col)
			draw_string(font, rr.position + Vector2(rr.size.x - 36, 16),
					"Рів.%d" % clvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lvl_col)
			var hp:  int = GameState.get_companion_hp(uid)
			var dmg: int = GameState.get_companion_dmg(uid)
			var ar:  int = c["atk_range"]
			var range_str := "дальній р.%d" % ar if ar > 1 else "ближній"
			# XP-смужка внизу рядка + текст
			var cxp: int = 0
			var cxp_next: int = 0
			if GameState.companion_progress.has("c%d" % uid):
				var cp_d: Dictionary = GameState.companion_progress["c%d" % uid] as Dictionary
				cxp = int(cp_d.get("xp", 0))
			var xp_cratio := 1.0
			if clvl < GameState.MAX_LEVEL:
				cxp_next = GameState.LEVEL_XP[clvl]
				var xp_cs: int = GameState.LEVEL_XP[clvl - 1]
				xp_cratio = clampf(float(cxp - xp_cs) / float(cxp_next - xp_cs), 0.0, 1.0)
			draw_rect(Rect2(rr.position.x, rr.position.y + rr.size.y - 3, rr.size.x, 3),
					Color(0.10, 0.10, 0.16))
			draw_rect(Rect2(rr.position.x, rr.position.y + rr.size.y - 3, rr.size.x * xp_cratio, 3),
					Color(0.50, 0.38, 0.75) if clvl < GameState.MAX_LEVEL else Color(0.90, 0.75, 0.20))
			var xp_str: String = ("MAX" if clvl >= GameState.MAX_LEVEL else "%d/%d" % [cxp, cxp_next])
			draw_string(font, rr.position + Vector2(6, 32),
					"HP:%d  АТК:%d  %s  XP:%s" % [hp, dmg, range_str, xp_str],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.55, 0.55))

func _draw_status(font: Font, vp: Vector2) -> void:
	draw_rect(Rect2(0, vp.y - BOT_H, vp.x, BOT_H), Color(0, 0, 0, 0.55))
	if _status != "":
		draw_string(font, Vector2(12, vp.y - 13), _status,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.5))
	var mbtn := _map_btn_rect()
	draw_rect(mbtn, Color(0.08, 0.16, 0.24, 0.9))
	draw_rect(mbtn, C_BORDER, false, 1.0)
	draw_string(font, mbtn.position + Vector2(10, 19), "> Карта світу",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var wb := _workers_btn_rect()
	draw_rect(wb, Color(0.10, 0.22, 0.12, 0.9))
	draw_rect(wb, C_BORDER, false, 1.0)
	var pop_str := "Люди: %d" % GameState.population
	if GameState.pending_population > 0:
		pop_str += "  (+%d)" % GameState.pending_population
	draw_string(font, wb.position + Vector2(10, 19), pop_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.9, 0.6))
	var eb := _equip_btn_rect()
	draw_rect(eb, Color(0.18, 0.14, 0.22, 0.9))
	draw_rect(eb, C_BORDER, false, 1.0)
	draw_string(font, eb.position + Vector2(10, 19), "⚔ Спорядження",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.75, 1.0))

func _draw_worker_popup(font: Font) -> void:
	var pr     := _popup_rect()
	var rkeys: Array[String]  = ["wood", "stone", "metal", "food"]
	var rlabels: Array[String] = ["Дерево", "Камінь", "Метал", "Їжа"]
	var rcols: Array[Color]    = [Color(0.6,0.4,0.1), Color(0.55,0.55,0.55),
								  Color(0.4,0.6,0.8), Color(0.3,0.7,0.3)]

	# Тінь + фон
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y),
			Color(0, 0, 0, 0.55))
	draw_rect(pr, Color(0.10, 0.08, 0.06, 0.97))
	draw_rect(pr, C_BORDER_S, false, 1.5)

	# Заголовок
	draw_string(font, pr.position + Vector2(12, 24), "Розподіл робітників",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.80, 0.20))

	# Кнопка закрити
	var cr := _popup_close_rect()
	draw_rect(cr, Color(0.25, 0.10, 0.10, 0.9))
	draw_rect(cr, C_BORDER, false, 1.0)
	draw_string(font, cr.position + Vector2(7, 18), "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Населення
	var used: int = 0
	for k in GameState.workers: used += int(GameState.workers[k])
	var free_pop: int = GameState.population - used
	draw_string(font, pr.position + Vector2(12, 48),
			"Населення: %d   |   Призначено: %d   |   Вільні: %d" % [
				GameState.population, used, free_pop],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.70, 0.60))
	draw_string(font, pr.position + Vector2(12, 64),
			"Їжа: %d  (споживання: %d/цикл)" % [
				GameState.resources.get("food", 0), ceili(GameState.population / 2.0)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.5))

	# Рядки ресурсів
	for ri in rkeys.size():
		var key:   String = rkeys[ri]
		var label: String = rlabels[ri]
		var col:   Color  = rcols[ri]
		var w:     int    = GameState.workers.get(key, 0)
		var prod:  int    = w * int(GameState.WORKER_PRODUCTIVITY[key])
		var ry    := pr.position.y + 80 + ri * 54.0

		draw_rect(Rect2(pr.position.x + 8, ry + 4, pr.size.x - 16, 46), Color(0.08, 0.07, 0.05))
		draw_rect(Rect2(pr.position.x + 8, ry + 4, pr.size.x - 16, 46), Color(col, 0.2), false, 1.0)
		draw_rect(Rect2(pr.position.x + 14, ry + 16, 12, 12), col)
		draw_string(font, Vector2(pr.position.x + 32, ry + 26), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(font, Vector2(pr.position.x + 32, ry + 42),
				"+%d/цикл" % prod,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col if prod > 0 else Color(0.4, 0.4, 0.4))

		# Кнопки [-] [N] [+]
		var mr := _popup_minus_rect(ri)
		var pr2 := _popup_plus_rect(ri)
		var hov_m := _hov_wbtn == ri * 2
		var hov_p := _hov_wbtn == ri * 2 + 1
		draw_rect(mr, Color(0.30, 0.10, 0.10, 0.9) if hov_m else Color(0.18, 0.08, 0.08, 0.9))
		draw_rect(mr, C_BORDER, false, 1.0)
		draw_string(font, mr.position + Vector2(8, 18), "−",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(font, Vector2(mr.position.x + mr.size.x + 6, mr.position.y + 18),
				"%d" % w, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_rect(pr2, Color(0.10, 0.28, 0.10, 0.9) if hov_p else Color(0.08, 0.18, 0.08, 0.9))
		draw_rect(pr2, C_BORDER, false, 1.0)
		draw_string(font, pr2.position + Vector2(8, 18), "+",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw_equip_popup(font: Font) -> void:
	var pr    := _equip_popup_rect()
	var chars := _equip_chars()

	# Затемнення + фон
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y),
			Color(0, 0, 0, 0.55))
	draw_rect(pr, Color(0.10, 0.08, 0.12, 0.97))
	draw_rect(pr, C_BORDER_S, false, 1.5)

	# Заголовок + закрити
	draw_string(font, pr.position + Vector2(12, 24), "Спорядження",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.75, 1.0))
	var cr := _equip_close_rect()
	draw_rect(cr, Color(0.25, 0.10, 0.10, 0.9))
	draw_rect(cr, C_BORDER, false, 1.0)
	draw_string(font, cr.position + Vector2(7, 18), "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	if chars.is_empty():
		draw_string(font, pr.position + Vector2(12, 100),
				"Немає персонажів у загоні. Додай компаньйона і відкрий знову.",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.55))
		return

	# ── Вкладки персонажів ────────────────────────────────────────────────
	_equip_char_idx = mini(_equip_char_idx, chars.size() - 1)
	for i in chars.size():
		var tab_r := _equip_tab_rect(i)
		var is_a  := i == _equip_char_idx
		var is_h  := i == _equip_hov_tab and not is_a
		draw_rect(tab_r, Color(0.32,0.22,0.40,0.95) if is_a else
				(Color(0.22,0.17,0.28,0.9) if is_h else Color(0.15,0.12,0.18,0.85)))
		draw_rect(tab_r, C_BORDER_S if is_a else C_BORDER, false, 1.0)
		draw_string(font, tab_r.position + Vector2(6, 18), chars[i]["name"] as String,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color.WHITE if is_a else Color(0.75, 0.75, 0.75))

	# ── 11 слотів спорядження ────────────────────────────────────────────
	var char_key: String = chars[_equip_char_idx]["key"] as String
	for si in GameState.EQUIP_SLOTS.size():
		var slot:  String = GameState.EQUIP_SLOTS[si]
		var label: String = GameState.SLOT_LABELS[slot] as String
		var item  := GameState.get_equipped_item(char_key, slot)
		var sr    := _equip_slot_rect(si)
		var is_sel := si == _equip_sel_slot
		var is_h   := si == _equip_hov_slot and not is_sel

		var bg: Color
		if is_sel:           bg = Color(0.28, 0.20, 0.40, 0.95)
		elif is_h:           bg = Color(0.20, 0.16, 0.26, 0.9)
		elif not item.is_empty(): bg = Color(0.15, 0.12, 0.20, 0.9)
		else:                bg = Color(0.10, 0.08, 0.14, 0.9)
		draw_rect(sr, bg)
		draw_rect(sr, C_BORDER_S if is_sel else (C_BORDER_S if not item.is_empty() else C_BORDER),
				false, 1.0 if not is_sel else 2.0)

		# Назва слоту (дрібно зверху)
		draw_string(font, sr.position + Vector2(5, 13), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.50, 0.70))

		if item.is_empty():
			var hint := "[ клік → вибрати ]" if is_sel else "[ порожньо ]"
			var hcol := Color(0.55, 0.50, 0.75) if is_sel else Color(0.35, 0.32, 0.38)
			draw_string(font, sr.position + Vector2(5, 36), hint,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hcol)
		else:
			var iname: String = item.get("name", "???") as String
			draw_string(font, sr.position + Vector2(5, 34), iname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.88, 1.0))
			var stats := _item_stat_str(item)
			if stats != "":
				draw_string(font, sr.position + Vector2(5, 47), stats,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.60, 0.85, 0.60))
			if is_sel:
				draw_string(font, sr.position + Vector2(sr.size.x - 64, 47), "кліщ:зняти",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.90, 0.40, 0.40))

	# ── Секція інвентаря (показується коли обраний слот) ──────────────────
	var iy0 := _inv_header_y()
	draw_line(Vector2(pr.position.x + 8, iy0), Vector2(pr.position.x + pr.size.x - 8, iy0),
			Color(C_BORDER, 0.5), 1.0)

	if _equip_sel_slot != -1:
		var sel_slot: String = GameState.EQUIP_SLOTS[_equip_sel_slot]
		draw_string(font, Vector2(pr.position.x + 8, iy0 + 14),
				"Інвентар  [%s]:" % (GameState.SLOT_LABELS[sel_slot] as String),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.75, 1.0))

		var matching := _matching_items(char_key, sel_slot)
		if matching.is_empty():
			draw_string(font, Vector2(pr.position.x + 8, iy0 + 42),
					"Немає підходящих предметів (Кузня → будуй для отримання)",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.42, 0.48))
		else:
			_equip_inv_off = mini(_equip_inv_off, maxi(0, matching.size() - 4))
			for ri in mini(4, matching.size() - _equip_inv_off):
				var idx: int = matching[_equip_inv_off + ri]
				var it: Dictionary = GameState.inventory[idx] as Dictionary
				var ir := _inv_item_rect(ri)
				var _ih := ri == _equip_hov_slot - 100  # hack: use separate hover? no
				draw_rect(ir, Color(0.18, 0.14, 0.24, 0.9))
				draw_rect(ir, C_BORDER, false, 1.0)
				draw_string(font, ir.position + Vector2(6, 20),
						(it.get("name", "?") as String) + "  " + _item_stat_str(it),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.88, 0.85, 0.95))
			# Кнопки прокрутки
			if matching.size() > 4:
				var su := _inv_scroll_up_rect()
				var sd := _inv_scroll_dn_rect()
				draw_rect(su, Color(0.20,0.15,0.28,0.9)); draw_rect(su, C_BORDER, false, 1.0)
				draw_rect(sd, Color(0.20,0.15,0.28,0.9)); draw_rect(sd, C_BORDER, false, 1.0)
				draw_string(font, su.position + Vector2(10,20), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
				draw_string(font, sd.position + Vector2(10,20), "↓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	else:
		draw_string(font, Vector2(pr.position.x + 8, iy0 + 14),
				"Клікни на слот щоб побачити доступні предмети",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.50, 0.48, 0.55))

	# ── Підсумок броні ────────────────────────────────────────────────────
	var by  := pr.position.y + pr.size.y - 26
	draw_rect(Rect2(pr.position.x + 8, by - 6, pr.size.x - 16, 24), Color(0.09, 0.07, 0.12))
	var total_armor := GameState.get_char_armor(char_key)
	var total_dmg   := GameState.get_char_dmg_bonus(char_key)
	var summary     := "Броня: %d" % total_armor
	if total_armor > 0:
		var reduc := int(round(float(total_armor) / float(total_armor + 100) * 100.0))
		summary += "  (-%d%% урону)" % reduc
	if total_dmg > 0: summary += "   АТК: +%d" % total_dmg
	draw_string(font, Vector2(pr.position.x + 12, by + 10), summary,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.70, 0.90, 0.70))

func _item_stat_str(item: Dictionary) -> String:
	var parts: Array[String] = []
	if int(item.get("armor",            0)) > 0: parts.append("Бр+%d"   % int(item.get("armor",            0)))
	if int(item.get("dmg_bonus",        0)) > 0: parts.append("АТК+%d"  % int(item.get("dmg_bonus",        0)))
	if int(item.get("hp_bonus",         0)) > 0: parts.append("HP+%d"   % int(item.get("hp_bonus",         0)))
	if int(item.get("magic_bonus",      0)) > 0: parts.append("Маг+%d"  % int(item.get("magic_bonus",      0)))
	if int(item.get("agility_bonus",    0)) > 0: parts.append("Спр+%d"  % int(item.get("agility_bonus",    0)))
	if int(item.get("initiative_bonus", 0)) > 0: parts.append("Ініц+%d" % int(item.get("initiative_bonus", 0)))
	if int(item.get("critical_bonus",   0)) > 0: parts.append("Крит+%d%%"% int(item.get("critical_bonus",  0)))
	if int(item.get("simple_barrier",   0)) > 0: parts.append("Щит+%d"  % int(item.get("simple_barrier",   0)))
	if int(item.get("magic_barrier",    0)) > 0: parts.append("МБар+%d" % int(item.get("magic_barrier",    0)))
	if item.get("two_handed",  false): parts.append("2h")
	if item.get("is_quiver",   false): parts.append("колчан")
	return "  ".join(parts)
