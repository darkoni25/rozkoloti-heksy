extends Node2D

# ── Дані споруд ───────────────────────────────────────────────────────────
const BUILDINGS = [
	{"name": "Каплиця",         "companion": "Клірик",  "wood": 0, "stone": 0, "metal": 0,  "effect": "+15% HP загону"},
	{"name": "Казарма",          "companion": "Воїн",    "wood": 0, "stone": 0, "metal": 0, "effect": "+10 HP загону"},
	{"name": "Гільдія злодіїв",  "companion": "Злодій",  "wood": 0, "stone": 0, "metal": 0, "effect": "лут ×1.5"},
	{"name": "Башта мага",       "companion": "Маг",     "wood": 0, "stone": 0, "metal": 0, "effect": "+10 маг.бар."},
	{"name": "Мисливська хижа",  "companion": "Мисл.",   "wood": 0, "stone": 0, "metal": 0,  "effect": "+1 їжа/роб."},
	{"name": "Святилище тіней",  "companion": "Оккуль.", "wood": 0, "stone": 0, "metal": 0, "effect": "крит ×1.5"},
	{"name": "Таверна",          "companion": "Бард",    "wood": 0, "stone": 0, "metal": 0,  "effect": "XP ×1.25"},
	{"name": "Кузня",            "companion": "",        "wood": 0, "stone": 0, "metal": 0, "effect": "дає спорядження"},
]

# ── Layout ────────────────────────────────────────────────────────────────
const TOP_H   := 40.0
const BOT_H   := 36.0
const RIGHT_W := 190.0

# Фонове зображення (1672×941 ≈ 16:9)
const BG_W := 1672.0
const BG_H := 941.0

# UV-позиції 8 платформ (частка від BG_W/BG_H, anchor = низ-центр платформи)
# Порядок відповідає slot index 0-7; налаштуй якщо треба зміщення
const SLOT_UV: Array[Vector2] = [
	Vector2(0.18, 0.28),  # 0 — ряд 1, ліво
	Vector2(0.44, 0.28),  # 1 — ряд 1, центр
	Vector2(0.70, 0.28),  # 2 — ряд 1, право
	Vector2(0.18, 0.55),  # 3 — ряд 2, ліво
	Vector2(0.44, 0.55),  # 4 — ряд 2, центр
	Vector2(0.70, 0.55),  # 5 — ряд 2, право
	Vector2(0.31, 0.80),  # 6 — ряд 3, ліво-центр
	Vector2(0.57, 0.80),  # 7 — ряд 3, право-центр
]

# Фіксована будівля для кожного слота — змінювати тут, а не в рантаймі
# slot 0→Каплиця  1→Казарма  2→Мисл.хижа  3→Святилище
# slot 4→Гільдія  5→Кузня    6→Таверна    7→Башта мага
const SLOT_BUILDING: Array[int] = [0, 1, 4, 6, 2, 7, 5, 3]

# Половина розміру клікабельної зони слота (у частках vp)
const SLOT_HIT_HW := 0.090   # half-width

# Вмикає номерні кружки на кожному слоті для калібрування позицій
# Постав false коли позиції вже правильні
const DEBUG_SLOTS := true
const SLOT_HIT_HH := 0.085   # half-height

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
# ── Стиль попапів — темна фентезі-таверна ────────────────────────────────
const C_INK      := Color(0.039, 0.031, 0.020, 1.0)  # #0a0805 фон попапу
const C_BR_SHADOW:= Color(0.290, 0.220, 0.094, 1.0)  # #4a3818 темна бронза
const C_BR_FLARE := Color(0.941, 0.812, 0.471, 1.0)  # #f0cf78 яскраве золото
const C_BONE     := Color(0.910, 0.851, 0.702, 1.0)  # #e8d9b3 теплий білий
const C_PARCH    := Color(0.784, 0.706, 0.529, 1.0)  # #c8b487 пергамент
const C_DIM      := Color(0.541, 0.471, 0.345, 1.0)  # #8a7858 приглушений
const C_FADED    := Color(0.353, 0.302, 0.212, 1.0)  # #5a4d36 дуже тьмяний

# ── Стан ─────────────────────────────────────────────────────────────────
var _resources: Dictionary[String, int]:
	get: return GameState.resources
var _slots: Array[int]:
	get: return GameState.base_slots
var _sel_slot:      int    = -1
var _hov_slot:      int    = -1
var _hov_companion: int    = -1
var _status:        String = ""
var _show_workers:  bool   = false
var _hov_wbtn:      int    = -1   # res_i * 2 + 0/1 (мінус/плюс)
var _show_equip:     bool = false
var _equip_char_idx: int  = 0
var _equip_hov_tab:  int  = -1
var _equip_hov_slot: int  = -1
var _equip_inv_hov:  int  = -1   # hover над рядком інвентаря в попапі спорядження
var _equip_sel_slot: int  = -1   # обраний слот (для показу відповідних предметів)
var _equip_inv_off:  int  = 0    # зсув прокрутки інвентаря

# Попап левелапу
var _show_levelup:      bool = false
var _levelup_hov:       int  = -1   # індекс вибору що hover (-1 = жоден)

# Попап інвентаря
var _show_inv:    bool = false
var _inv_tab:     int  = 0   # 0 = речі, 1 = трофеї
var _inv_scroll:  int  = 0

# Попап будівлі
var _show_bld:  bool   = false
var _bld_bid:   int    = -1
var _bld_hov:   int    = -1
var _bld_sel:   int    = -1   # обраний рецепт (для превʼю + кнопки)
var _bld_msg:   String = ""

# ── Анімація ──────────────────────────────────────────────────────────────
var _popup_alpha:   float  = 1.0   # 0→1 при відкритті будь-якого попапу
var _rest_anim:     float  = -1.0  # -1=вимк; 0..1.2=грається
var _rest_done:     bool   = false # цикл вже виконано під час анімації
var _rest_preview:  String = ""    # виробництво (показується під час анімації)

# ── Текстури ──────────────────────────────────────────────────────────────
var _tex_bg: Texture2D = null

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.06, 0.05, 0.04))
	_load_textures()
	if not GameState.hero_created:
		get_tree().change_scene_to_file(
			"res://scenes/character_creation/CharacterCreationScene.tscn")
		return
	if not GameState.get_pending_levelup_keys().is_empty():
		_show_levelup = true

func _process(delta: float) -> void:
	var dirty := false
	# Fade-in попапу
	if _popup_alpha < 1.0:
		_popup_alpha = minf(_popup_alpha + delta * 6.0, 1.0)   # ~0.17с
		dirty = true
	# Анімація відпочинку
	if _rest_anim >= 0.0:
		_rest_anim = minf(_rest_anim + delta, 1.2)
		if _rest_anim >= 0.35 and not _rest_done:              # пік темряви
			_rest_done = true
			GameState.process_cycle()
			GameState.save_game()
		if _rest_anim >= 1.2:
			_rest_anim = -1.0
			_status    = "Відпочинок: " + _rest_preview
		dirty = true
	if dirty:
		queue_redraw()

func _load_textures() -> void:
	_tex_bg = load("res://assets/Textures/Base/new_BG.png") as Texture2D

# ── Допоміжні ────────────────────────────────────────────────────────────
func _slot_rect(i: int) -> Rect2:
	var vp := get_viewport_rect().size
	var uv := SLOT_UV[i]
	var cx := uv.x * vp.x
	var cy := uv.y * vp.y
	var hw := SLOT_HIT_HW * vp.x
	var hh := SLOT_HIT_HH * vp.y
	return Rect2(cx - hw, cy - hh, hw * 2.0, hh * 2.0)

func _build_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - RIGHT_W + 8, TOP_H + 148, RIGHT_W - 16, 34)

func _map_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 36, 163, 28)

func _workers_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 74, 163, 28)

func _equip_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 112, 163, 28)

func _inv_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 150, 163, 28)

func _rest_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 175, vp.y - 188, 163, 28)

func _inv_popup_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 280, vp.y * 0.5 - 260, 560, 520)

func _inv_close_rect() -> Rect2:
	var pr := _inv_popup_rect()
	return Rect2(pr.position.x + pr.size.x - 32, pr.position.y + 6, 26, 26)

func _inv_tab_rect(i: int) -> Rect2:
	var pr := _inv_popup_rect()
	return Rect2(pr.position.x + 8 + i * 142.0, pr.position.y + 38, 136, 28)

func _inv_row_rect(i: int) -> Rect2:
	var pr := _inv_popup_rect()
	return Rect2(pr.position.x + 8, pr.position.y + 76 + i * 38.0, pr.size.x - 16, 34)

func _bld_popup_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 290, vp.y * 0.5 - 240, 580, 480)

func _bld_close_rect() -> Rect2:
	var pr := _bld_popup_rect()
	return Rect2(pr.position.x + pr.size.x - 32, pr.position.y + 6, 26, 26)

# Ліва колонка — список рецептів
func _bld_list_rect() -> Rect2:
	var pr := _bld_popup_rect()
	return Rect2(pr.position.x + 8, pr.position.y + 44, 236, pr.size.y - 52)

func _bld_list_item_rect(i: int) -> Rect2:
	var lr := _bld_list_rect()
	return Rect2(lr.position.x, lr.position.y + i * 40, lr.size.x, 38)

# Права колонка — превʼю + кнопка
func _bld_preview_rect() -> Rect2:
	var pr := _bld_popup_rect()
	return Rect2(pr.position.x + 252, pr.position.y + 44, pr.size.x - 260, pr.size.y - 52)

func _bld_craft_btn_rect() -> Rect2:
	var pv := _bld_preview_rect()
	return Rect2(pv.position.x + 8, pv.position.y + pv.size.y - 40, pv.size.x - 16, 32)

# Залишаємо для сумісності з hover detection у MouseMotion
func _bld_action_rect(i: int) -> Rect2:
	return _bld_list_item_rect(i)

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

func _levelup_popup_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var w  := 380.0; var h := 240.0
	return Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)

func _levelup_choice_rect(i: int) -> Rect2:
	var pr := _levelup_popup_rect()
	return Rect2(pr.position.x + 24, pr.position.y + 120.0 + i * 36.0, pr.size.x - 48, 30)

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

func _do_rest_cycle() -> void:
	if _rest_anim >= 0.0: return   # вже грається
	# Обчислюємо preview ДО циклу
	var rkeys:   Array[String] = ["wood", "stone", "metal", "food"]
	var rlabels: Array[String] = ["Дер",  "Кам",   "Мет",   "Їжа"]
	var parts: Array[String] = []
	for i in rkeys.size():
		var k: String = rkeys[i]
		var w:    int = int(GameState.workers.get(k, 0))
		var prod: int = int(GameState.WORKER_PRODUCTIVITY[k])
		if k == "food" and GameState.has_building(4): prod += 1
		if w > 0: parts.append("%s+%d" % [rlabels[i], w * prod])
	var consumed: int = ceili(GameState.population / 2.0)
	_rest_preview = ("  ".join(parts) if not parts.is_empty() else "Робітники відпочивають")
	if consumed > 0: _rest_preview += "  |  Їжа−%d" % consumed
	# Запускаємо анімацію — цикл виконається в _process при _rest_anim >= 0.35
	_rest_anim = 0.0
	_rest_done = false

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
	_sel_slot = -1

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		# Попап левелапу — найвищий пріоритет
		if _show_levelup:
			var prev := _levelup_hov
			_levelup_hov = -1
			for i in GameState.LEVELUP_CHOICES.size():
				if _levelup_choice_rect(i).has_point(pos): _levelup_hov = i; break
			if _levelup_hov != prev: queue_redraw()
			return
		# Попап будівлі
		if _show_bld:
			var prev_h := _bld_hov
			_bld_hov = -1
			if GameState.BUILDING_ACTIONS.has(_bld_bid):
				var acts: Array = GameState.BUILDING_ACTIONS[_bld_bid] as Array
				for i in acts.size():
					if _bld_action_rect(i).has_point(pos): _bld_hov = i; break
			if _bld_hov != prev_h: queue_redraw()
			return
		# Попап інвентаря — пріоритет перед equipment
		if _show_inv:
			return
		# Попапи мають пріоритет — не перетираємо hover основного UI
		if _show_equip:
			var prev_t := _equip_hov_tab; var prev_s := _equip_hov_slot; var prev_i := _equip_inv_hov
			_equip_hov_tab = -1; _equip_hov_slot = -1; _equip_inv_hov = -1
			var chars := _equip_chars()
			for i in chars.size():
				if _equip_tab_rect(i).has_point(pos): _equip_hov_tab = i; break
			if _equip_hov_tab == -1:
				for i in GameState.EQUIP_SLOTS.size():
					if _equip_slot_rect(i).has_point(pos): _equip_hov_slot = i; break
			if _equip_hov_slot == -1 and _equip_sel_slot != -1:
				for ri in 4:
					if _inv_item_rect(ri).has_point(pos): _equip_inv_hov = ri; break
			if _equip_hov_tab != prev_t or _equip_hov_slot != prev_s or _equip_inv_hov != prev_i:
				queue_redraw()
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
		_hov_slot = -1; _hov_companion = -1
		for i in 8:
			if _slot_rect(i).has_point(pos):
				_hov_slot = i; break
		if _hov_slot == -1:
			var rows := GameState.get_available_companions()
			for i in rows.size():
				if _companion_row_rect(i).has_point(pos):
					_hov_companion = i; break
		queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position

		# Попап левелапу — найвищий пріоритет
		if _show_levelup:
			var keys := GameState.get_pending_levelup_keys()
			if not keys.is_empty():
				for i in GameState.LEVELUP_CHOICES.size():
					if _levelup_choice_rect(i).has_point(pos):
						var ch := GameState.LEVELUP_CHOICES[i] as Dictionary
						GameState.apply_levelup_choice(keys[0], int(ch.get("id", 0)))
						_levelup_hov = -1
						if GameState.get_pending_levelup_keys().is_empty():
							_show_levelup = false
						queue_redraw()
						return
			return   # клік поза кнопками — ігноруємо (попап не закривається)

		# Popup будівлі
		if _show_bld:
			if _bld_close_rect().has_point(pos):
				_show_bld = false; _bld_sel = -1; queue_redraw(); return
			if GameState.BUILDING_ACTIONS.has(_bld_bid):
				var acts: Array = GameState.BUILDING_ACTIONS[_bld_bid] as Array
				# Клік на рецепт у лівій колонці → вибрати (не виконати)
				for i in acts.size():
					if _bld_list_item_rect(i).has_point(pos):
						_bld_sel = i if _bld_sel != i else -1
						_bld_msg = ""
						queue_redraw(); return
				# Клік на кнопку виконати у правій колонці
				if _bld_sel != -1 and _bld_craft_btn_rect().has_point(pos):
					if GameState.can_afford_action(_bld_bid, _bld_sel):
						var res := GameState.execute_building_action(_bld_bid, _bld_sel)
						_bld_msg = res["msg"] as String
						if res["success"] as bool: _status = _bld_msg
						_bld_sel = -1
						queue_redraw(); return
			if not _bld_popup_rect().has_point(pos):
				_show_bld = false; _bld_sel = -1; queue_redraw()
			return

		# Popup інвентаря
		if _show_inv:
			if _inv_close_rect().has_point(pos):
				_show_inv = false; queue_redraw(); return
			for i in 2:
				if _inv_tab_rect(i).has_point(pos):
					_inv_tab = i; _inv_scroll = 0; queue_redraw(); return
			if not _inv_popup_rect().has_point(pos):
				_show_inv = false; queue_redraw()
			return

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

		if _rest_btn_rect().has_point(pos):
			_do_rest_cycle(); return
		if _map_btn_rect().has_point(pos):
			get_tree().change_scene_to_file("res://scenes/world_map/WorldMapScene.tscn")
			return
		if _inv_btn_rect().has_point(pos):
			_show_inv = true; _show_equip = false; _show_workers = false
			_inv_tab = 0; _inv_scroll = 0; _popup_alpha = 0.0; queue_redraw(); return
		if _equip_btn_rect().has_point(pos):
			_show_equip = true; _show_workers = false; _show_inv = false; _sel_slot = -1
			_equip_char_idx = 0; _equip_sel_slot = -1; _equip_inv_off = 0
			_equip_inv_hov = -1; _popup_alpha = 0.0; queue_redraw(); return
		if _workers_btn_rect().has_point(pos):
			_show_workers = true; _show_equip = false; _sel_slot = -1
			_popup_alpha = 0.0; queue_redraw(); return
		for i in 8:
			if _slot_rect(i).has_point(pos):
				if _slots[i] != -1:
					_show_bld = true; _bld_bid = _slots[i]
					_bld_hov = -1; _bld_sel = -1; _bld_msg = ""
					_show_inv = false; _show_equip = false; _show_workers = false
					_popup_alpha = 0.0
				else:
					_sel_slot = i if _sel_slot != i else -1
				queue_redraw(); return
		if _sel_slot != -1:
			# Кнопка "Побудувати" у правому панелі
			if _slots[_sel_slot] == -1 and _build_btn_rect().has_point(pos):
				var bid: int = SLOT_BUILDING[_sel_slot]
				if _can_afford(bid):
					_build(_sel_slot, bid)
				else:
					var b: Dictionary = BUILDINGS[bid]
					_status = "Не вистачає ресурсів: %s" % (b["name"] as String)
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

	elif event is InputEventMouseButton and event.pressed and \
			event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _show_inv and _inv_tab == 0:
			var dir := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			var max_s := maxi(0, GameState.inventory.size() - int(((_inv_popup_rect().size.y - 84) / 38)))
			_inv_scroll = clampi(_inv_scroll + dir, 0, max_s)
			queue_redraw()

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _show_bld:
				_show_bld = false; queue_redraw()
				get_viewport().set_input_as_handled()
			elif _show_inv:
				_show_inv = false; queue_redraw()
				get_viewport().set_input_as_handled()
			elif _show_equip:
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
	var vp   := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	# Фон
	if _tex_bg != null:
		draw_texture_rect(_tex_bg, Rect2(Vector2.ZERO, vp), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.06, 0.05, 0.04))

	# Умовні позначки будівель
	for i in 8:
		var uv  := SLOT_UV[i]
		var cx  := uv.x * vp.x
		var cy  := uv.y * vp.y
		var bid : int = _slots[i]
		var built := bid != -1

		var marker_col  := Color(0.42, 0.30, 0.08, 0.90) if built else Color(0.16, 0.13, 0.10, 0.80)
		var border_col  := Color(0.82, 0.62, 0.18, 0.95) if built else Color(0.38, 0.32, 0.24, 0.85)
		draw_circle(Vector2(cx, cy), 24, marker_col)
		draw_arc(Vector2(cx, cy), 24, 0, TAU, 40, border_col, 2.0)

		# Іконка або цифра
		if DEBUG_SLOTS:
			draw_string(font, Vector2(cx - 5, cy + 6), str(i),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		else:
			var icon := "✓" if built else "+"
			draw_string(font, Vector2(cx - 6, cy + 6), icon,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

		# Назва будівлі під маркером
		var target_bid := bid if built else SLOT_BUILDING[i]
		var bname: String = BUILDINGS[target_bid]["name"] as String
		# Скорочуємо довгі назви
		if bname.length() > 10:
			bname = bname.left(10) + "."
		var name_col := Color(0.95, 0.80, 0.35) if built else Color(0.52, 0.46, 0.36)
		draw_string(font, Vector2(cx - 60.0, cy + 36), bname,
				HORIZONTAL_ALIGNMENT_CENTER, 120, 11, name_col)

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
	if _rest_anim >= 0.0:
		_draw_rest_anim(font, vp)
	elif _show_levelup:
		_draw_levelup_popup(font)
	elif _show_bld:
		_draw_bld_popup(font)
	elif _show_inv:
		_draw_inv_popup(font)
	elif _show_equip:
		_draw_equip_popup(font)
	elif _show_workers:
		_draw_worker_popup(font)

func _draw_levelup_popup(font: Font) -> void:
	var keys := GameState.get_pending_levelup_keys()
	if keys.is_empty():
		_show_levelup = false
		return
	var char_key  := keys[0]
	var info      := GameState.pending_levelups[char_key] as Dictionary
	var char_name := str(info.get("name",      "?"))
	var new_lvl   := int(info.get("new_level", 2))
	var vp        := get_viewport_rect().size
	var pr        := _levelup_popup_rect()

	# Затемнення
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.72))
	# Тінь + тіло попапу
	draw_rect(pr.grow(4.0), Color(0, 0, 0, 0.40))
	draw_rect(pr, Color(0.12, 0.095, 0.065, 0.98))
	draw_rect(pr, Color(C_BORDER_S, 0.85), false, 1.5)
	# Заголовок — власна смуга
	var hdr_r_lu := Rect2(pr.position.x, pr.position.y, pr.size.x, 38)
	draw_rect(hdr_r_lu, Color(0.08, 0.062, 0.040, 0.95))
	draw_string(font,
		Vector2(pr.position.x, pr.position.y + 25),
		"★  %s  →  Рівень %d!" % [char_name, new_lvl],
		HORIZONTAL_ALIGNMENT_CENTER, int(pr.size.x), 16, C_BR_FLARE)
	_draw_ornament_divider(pr.position.x + 8, pr.position.x + pr.size.x - 8,
		pr.position.y + 38.0, Color(C_BORDER_S, 0.50))
	draw_string(font,
		Vector2(pr.position.x, pr.position.y + 62),
		"Оберіть покращення:",
		HORIZONTAL_ALIGNMENT_CENTER, int(pr.size.x), 13, C_PARCH)
	# Розділювач-орнамент
	_draw_ornament_divider(
		pr.position.x + 20, pr.position.x + pr.size.x - 20,
		pr.position.y + 74, Color(C_BORDER_S, 0.40))
	# Кнопки вибору
	for i in GameState.LEVELUP_CHOICES.size():
		var ch  := GameState.LEVELUP_CHOICES[i] as Dictionary
		var cr  := _levelup_choice_rect(i)
		var hov := _levelup_hov == i
		draw_rect(cr, Color(0.25, 0.18, 0.04, 0.97) if hov else Color(0.10, 0.07, 0.03, 0.93))
		draw_rect(cr, Color(C_BORDER_S, 0.9) if hov else Color(C_BORDER, 0.7), false, 1.0)
		draw_string(font,
			Vector2(cr.position.x, cr.position.y + 21),
			"%s  %s" % [str(ch.get("icon", "")), str(ch.get("label", ""))],
			HORIZONTAL_ALIGNMENT_CENTER, int(cr.size.x), 14,
			C_BR_FLARE if hov else C_PARCH)
	_draw_popup_fade(_levelup_popup_rect())

# Накладає темний шар поверх попапу — зникає в міру того як _popup_alpha → 1
func _draw_popup_fade(pr: Rect2) -> void:
	if _popup_alpha >= 1.0: return
	draw_rect(pr, Color(0.04, 0.03, 0.02, 1.0 - _popup_alpha))

# Горизонтальна лінія з алмазом у центрі — декоративний розділювач
func _draw_ornament_divider(x1: float, x2: float, y: float, col: Color) -> void:
	var mid  := (x1 + x2) * 0.5
	var gap  := 9.0
	draw_line(Vector2(x1, y), Vector2(mid - gap, y), col, 1.0)
	draw_line(Vector2(mid + gap, y), Vector2(x2, y), col, 1.0)
	# Алмаз
	var d := 4.0
	draw_line(Vector2(mid, y - d), Vector2(mid + d, y), Color(col, col.a * 0.85), 1.0)
	draw_line(Vector2(mid + d, y), Vector2(mid, y + d), Color(col, col.a * 0.85), 1.0)
	draw_line(Vector2(mid, y + d), Vector2(mid - d, y), Color(col, col.a * 0.85), 1.0)
	draw_line(Vector2(mid - d, y), Vector2(mid, y - d), Color(col, col.a * 0.85), 1.0)
	draw_circle(Vector2(mid, y), 1.5, Color(C_BR_FLARE, col.a))

func _draw_rest_anim(font: Font, vp: Vector2) -> void:
	var t    := _rest_anim / 1.2                          # 0..1 нормалізований
	var ov   := sin(t * PI) * 0.82                        # 0→пік→0, макс ~0.82
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.04, 0.02, 0.10, ov))

	# Текст і зірки — видимі в середній частині анімації
	var ta := clampf((t - 0.2) / 0.25, 0.0, 1.0) * clampf((0.85 - t) / 0.15, 0.0, 1.0)
	if ta <= 0.0: return
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5

	# Три зірки що обертаються по еліпсу
	var angle_off := _rest_anim * TAU * 0.45
	for i in 3:
		var a  := angle_off + float(i) / 3.0 * TAU
		var sx := cx + cos(a) * 62.0
		var sy := cy - 18.0 + sin(a) * 24.0
		var sa := ta * (0.6 + 0.4 * sin(_rest_anim * TAU + float(i) * 1.3))
		draw_circle(Vector2(sx, sy), 5.0, Color(0.95, 0.82, 0.28, sa))
		draw_circle(Vector2(sx, sy), 3.0, Color(1.00, 0.98, 0.75, sa))

	# Заголовок
	draw_string(font,
		Vector2(cx, cy - 10.0),
		"Відпочинок...",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 20,
		Color(0.92, 0.85, 0.50, ta))

	# Підсумок виробництва
	if _rest_preview != "":
		draw_string(font,
			Vector2(cx, cy + 20.0),
			_rest_preview,
			HORIZONTAL_ALIGNMENT_CENTER, 420, 13,
			Color(0.65, 0.90, 0.65, ta * 0.9))

func _draw_bld_popup(font: Font) -> void:
	var pr  := _bld_popup_rect()
	var vp  := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.72))
	# Тінь під попапом
	draw_rect(pr.grow(4.0), Color(0, 0, 0, 0.45))
	# Фон попапу — темно-коричневий, але не чорний
	draw_rect(pr, Color(0.12, 0.095, 0.065, 0.98))
	draw_rect(pr, Color(C_BORDER_S, 0.85), false, 1.5)

	# Заголовок — власна смуга
	var hdr_r := Rect2(pr.position.x, pr.position.y, pr.size.x, 38)
	draw_rect(hdr_r, Color(0.08, 0.062, 0.040, 0.95))
	var bname: String = BUILDINGS[_bld_bid]["name"] as String
	draw_string(font, pr.position + Vector2(12, 24), bname,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_BR_FLARE)
	var cr := _bld_close_rect()
	draw_rect(cr, Color(0.22, 0.06, 0.06, 0.95))
	draw_rect(cr, Color(C_BORDER, 0.8), false, 1.0)
	draw_string(font, cr.position + Vector2(7, 18), "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C_BONE, 0.9))
	_draw_ornament_divider(pr.position.x + 8, pr.position.x + pr.size.x - 8,
			pr.position.y + 38.0, Color(C_BORDER_S, 0.55))

	if not GameState.BUILDING_ACTIONS.has(_bld_bid):
		draw_string(font, pr.position + Vector2(12, 70),
				"Ця будівля поки не має дій...",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		_draw_popup_fade(pr); return

	var acts: Array = GameState.BUILDING_ACTIONS[_bld_bid] as Array

	# ── Ліва колонка: список рецептів ─────────────────────────────────────
	var lr := _bld_list_rect()
	draw_rect(lr, Color(0.06, 0.05, 0.03, 0.55))
	draw_rect(lr, Color(C_BORDER, 0.7), false, 0.8)

	var rmap: Dictionary = {"wood": "Дер", "stone": "Кам", "metal": "Мет", "food": "Їжа"}
	for i in acts.size():
		var act:   Dictionary = acts[i] as Dictionary
		var ar     := _bld_list_item_rect(i)
		var is_sel := i == _bld_sel
		var is_hov := i == _bld_hov and not is_sel
		var afford := GameState.can_afford_action(_bld_bid, i)

		var bg: Color
		if is_sel:               bg = Color(0.26, 0.19, 0.04, 0.98)
		elif is_hov and afford:  bg = Color(0.18, 0.13, 0.04, 0.92)
		elif is_hov:             bg = Color(0.16, 0.07, 0.07, 0.88)
		elif afford:             bg = Color(0.10, 0.08, 0.03, 0.85)
		else:                    bg = Color(0.06, 0.05, 0.04, 0.80)
		draw_rect(ar, bg)
		if is_sel:
			draw_rect(ar, Color(C_BORDER_S, 0.95), false, 1.5)
		elif is_hov:
			draw_rect(ar, C_BORDER_S if afford else Color(0.30, 0.15, 0.15), false, 1.0)

		var nc := C_PARCH if afford else C_FADED
		if is_sel: nc = C_BR_FLARE
		draw_string(font, ar.position + Vector2(6, 15),
				act.get("label", "?") as String,
				HORIZONTAL_ALIGNMENT_LEFT, 150, 12, nc)

		# Вартість компактно (права частина рядка)
		var cost: Dictionary = act.get("cost", {}) as Dictionary
		var lc:   Dictionary = act.get("loot_cost", {}) as Dictionary
		var cost_parts: Array[String] = []
		for k in ["wood", "stone", "metal", "food"]:
			if cost.has(k): cost_parts.append("%s%d" % [rmap[k], int(cost[k])])
		for id_key in lc:
			var meta: Dictionary = GameState.EXPEDITION_LOOT[int(id_key)] as Dictionary
			var nm := (meta.get("name", "?") as String).split(" ")[0]
			cost_parts.append("%s×%d" % [nm, int(lc[id_key])])
		if not cost_parts.is_empty():
			var cost_col := Color(0.45, 0.80, 0.45) if afford else Color(0.75, 0.35, 0.35)
			draw_string(font, ar.position + Vector2(6, 31),
					"  ".join(cost_parts), HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 12, 9, cost_col)

	# Роздільник між колонками (вертикальна лінія)
	draw_line(Vector2(pr.position.x + 248, pr.position.y + 44),
			Vector2(pr.position.x + 248, pr.position.y + pr.size.y - 8),
			Color(C_BORDER, 0.55), 1.0)

	# ── Права колонка: превʼю предмету ────────────────────────────────────
	var pv := _bld_preview_rect()
	draw_rect(pv, Color(0.06, 0.05, 0.03, 0.50))
	draw_rect(pv, Color(C_BORDER, 0.6), false, 0.8)

	if _bld_sel == -1:
		# Підказка — нічого не обрано
		draw_string(font, Vector2(pv.position.x, pv.position.y + pv.size.y * 0.5),
				"← Обери рецепт",
				HORIZONTAL_ALIGNMENT_CENTER, int(pv.size.x), 12, C_FADED)
	else:
		var sel_act: Dictionary = acts[_bld_sel] as Dictionary
		var effect:  String     = sel_act.get("effect", "") as String
		var edata:   Dictionary = sel_act.get("effect_data", {}) as Dictionary
		var afford_sel := GameState.can_afford_action(_bld_bid, _bld_sel)

		var py := pv.position.y + 18.0
		var px := pv.position.x + 10.0
		var pw := pv.size.x - 20.0

		# Назва дії
		draw_string(font, Vector2(px, py),
				sel_act.get("label", "?") as String,
				HORIZONTAL_ALIGNMENT_LEFT, int(pw), 14, C_BR_FLARE)
		py += 20.0

		if effect == "craft_item":
			# ── Статистики предмету ────────────────────────────────────
			var slot_label_map: Dictionary = {
				"main_hand": "Основна рука", "off_hand": "Ліва рука",
				"helmet": "Шолом", "chest": "Нагрудник", "legs": "Поножі",
				"boots": "Чоботи", "gloves": "Рукавиці", "belt": "Пояс",
				"neck": "Шия", "ring": "Каблучка", "ring1": "Каблучка 1",
				"ring2": "Каблучка 2",
			}
			var slot: String = edata.get("slot", "") as String
			var slot_lbl: String = slot_label_map.get(slot, slot) as String

			draw_string(font, Vector2(px, py), "Слот: " + slot_lbl,
					HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11, C_DIM)
			py += 18.0

			# Тип броні
			var at: int = int(edata.get("armor_type", -1))
			if at >= 0:
				var atype_names: Array[String] = ["Тканина", "Шкіра", "Кольчуга", "Пластина"]
				draw_string(font, Vector2(px, py), "Тип: " + atype_names[at],
						HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11, C_DIM)
				py += 18.0

			_draw_ornament_divider(px, px + pw, py - 4, Color(C_BORDER, 0.40))

			# Бойові характеристики
			var stat_defs: Array[Array] = [
				["armor",            "Броня",       Color(0.60, 0.85, 0.60)],
				["dmg_bonus",        "Атака",       Color(0.90, 0.50, 0.35)],
				["hp_bonus",         "HP",          Color(0.40, 0.80, 0.95)],
				["magic_bonus",      "Магія",       Color(0.70, 0.50, 1.00)],
				["agility_bonus",    "Спритність",  Color(0.90, 0.85, 0.40)],
				["initiative_bonus", "Ініціатива",  Color(0.40, 0.90, 0.80)],
				["critical_bonus",   "Критичний",   Color(1.00, 0.70, 0.20)],
				["simple_barrier",   "Щит",         Color(0.65, 0.75, 0.90)],
				["magic_barrier",    "Маг.бар'єр",  Color(0.80, 0.55, 1.00)],
			]
			for sd in stat_defs:
				var val: int = int(edata.get(sd[0] as String, 0))
				if val == 0: continue
				var suffix := "%" if sd[0] == "critical_bonus" else ""
				draw_string(font, Vector2(px, py),
						"%s:  +%d%s" % [sd[1] as String, val, suffix],
						HORIZONTAL_ALIGNMENT_LEFT, int(pw), 12, sd[2] as Color)
				py += 17.0

			# Особливості
			if bool(edata.get("two_handed", false)):
				draw_string(font, Vector2(px, py), "Дворучна зброя",
						HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11, Color(0.80, 0.65, 0.30))
				py += 17.0
			if bool(edata.get("requires_quiver", false)):
				draw_string(font, Vector2(px, py), "Потрібен колчан",
						HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11, Color(0.80, 0.65, 0.30))
				py += 17.0
			if bool(edata.get("is_quiver", false)):
				draw_string(font, Vector2(px, py), "Колчан для лука",
						HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11, Color(0.80, 0.65, 0.30))
				py += 17.0
			var atk_range: int = int(edata.get("atk_range", 0))
			if atk_range > 0:
				draw_string(font, Vector2(px, py), "Дальність: %d" % atk_range,
						HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11, Color(0.75, 0.70, 0.50))
				py += 17.0
		else:
			# Не крафт — показуємо опис ефекту
			draw_string(font, Vector2(px, py),
					sel_act.get("desc", "") as String,
					HORIZONTAL_ALIGNMENT_LEFT, int(pw), 12, Color(0.65, 0.90, 0.65))
			py += 20.0

		# Вартість у правій панелі (детально)
		py = pv.position.y + pv.size.y - 90.0
		_draw_ornament_divider(px, px + pw, py - 6, Color(C_BORDER, 0.45))
		draw_string(font, Vector2(px, py), "Вартість:",
				HORIZONTAL_ALIGNMENT_LEFT, int(pw), 10, C_DIM)
		py += 14.0
		var cost_sel: Dictionary = sel_act.get("cost", {}) as Dictionary
		var lc_sel:   Dictionary = sel_act.get("loot_cost", {}) as Dictionary
		var cost_all_parts: Array[String] = []
		for k in ["wood", "stone", "metal", "food"]:
			if cost_sel.has(k):
				cost_all_parts.append("%s: %d" % [rmap[k], int(cost_sel[k])])
		for id_key in lc_sel:
			var meta: Dictionary = GameState.EXPEDITION_LOOT[int(id_key)] as Dictionary
			cost_all_parts.append("%s × %d" % [meta.get("name", "?") as String, int(lc_sel[id_key])])
		var cost_str := "  ".join(cost_all_parts) if not cost_all_parts.is_empty() else "Безкоштовно"
		draw_string(font, Vector2(px, py), cost_str,
				HORIZONTAL_ALIGNMENT_LEFT, int(pw), 11,
				Color(0.50, 0.88, 0.50) if afford_sel else Color(0.85, 0.38, 0.38))

		# ── Кнопка виконати ───────────────────────────────────────────
		var cb := _bld_craft_btn_rect()
		var btn_label: String = "Виконати"
		if effect == "craft_item": btn_label = "⚒  Скрафтити"
		elif effect == "gossip":   btn_label = "Послухати"
		elif effect == "award_party_xp": btn_label = "Отримати XP"

		if afford_sel:
			draw_rect(cb, Color(0.20, 0.15, 0.04, 0.97))
			draw_rect(cb, Color(C_BORDER_S, 0.92), false, 1.5)
			draw_string(font, Vector2(cb.position.x, cb.position.y + 21), btn_label,
					HORIZONTAL_ALIGNMENT_CENTER, int(cb.size.x), 13, C_BR_FLARE)
		else:
			draw_rect(cb, Color(0.10, 0.08, 0.07, 0.9))
			draw_rect(cb, Color(C_FADED, 0.6), false, 1.0)
			draw_string(font, Vector2(cb.position.x, cb.position.y + 21), "Недостатньо ресурсів",
					HORIZONTAL_ALIGNMENT_CENTER, int(cb.size.x), 11, C_FADED)

	# Повідомлення результату (внизу лівої колонки)
	if _bld_msg != "":
		var my := pr.position.y + pr.size.y - 22.0
		draw_string(font, Vector2(pr.position.x + 12, my), _bld_msg,
				HORIZONTAL_ALIGNMENT_LEFT, 236, 11, C_BR_FLARE)

	_draw_popup_fade(pr)

func _draw_inv_popup(font: Font) -> void:
	var pr := _inv_popup_rect()
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.72))
	draw_rect(pr.grow(4.0), Color(0, 0, 0, 0.40))
	draw_rect(pr, Color(0.12, 0.095, 0.065, 0.98))
	draw_rect(pr, Color(C_BORDER_S, 0.85), false, 1.5)
	# Заголовок — власна смуга
	var hdr_r_inv := Rect2(pr.position.x, pr.position.y, pr.size.x, 38)
	draw_rect(hdr_r_inv, Color(0.08, 0.062, 0.040, 0.95))
	draw_string(font, pr.position + Vector2(12, 25), "Інвентар",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_BR_FLARE)
	var cr := _inv_close_rect()
	draw_rect(cr, Color(0.18, 0.06, 0.06, 0.95))
	draw_rect(cr, Color(C_BORDER, 0.8), false, 1.0)
	draw_string(font, cr.position + Vector2(7, 18), "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C_BONE, 0.9))
	var tabs := ["Речі", "Трофеї"]
	for i in tabs.size():
		var tr := _inv_tab_rect(i)
		var is_a := i == _inv_tab
		draw_rect(tr, Color(0.22, 0.16, 0.04, 0.95) if is_a else Color(0.08, 0.065, 0.042, 0.85))
		draw_rect(tr, C_BORDER_S if is_a else Color(C_BORDER, 0.6), false, 1.0)
		draw_string(font, tr.position + Vector2(0, 19), tabs[i],
				HORIZONTAL_ALIGNMENT_CENTER, int(tr.size.x), 13,
				C_BR_FLARE if is_a else C_DIM)
	_draw_ornament_divider(pr.position.x + 8, pr.position.x + pr.size.x - 8,
			pr.position.y + 70, Color(C_BORDER_S, 0.42))
	if _inv_tab == 0:
		_draw_inv_equipment(font, pr)
	else:
		_draw_inv_loot(font, pr)
	_draw_popup_fade(pr)

func _draw_inv_equipment(font: Font, pr: Rect2) -> void:
	var items := GameState.inventory
	if items.is_empty():
		draw_string(font, pr.position + Vector2(12, 110),
				"Інвентар порожній. Побудуй Кузню для отримання предметів.",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		return
	var max_rows := int((pr.size.y - 84) / 38)
	_inv_scroll = clampi(_inv_scroll, 0, maxi(0, items.size() - max_rows))
	for ri in mini(max_rows, items.size() - _inv_scroll):
		var idx  := _inv_scroll + ri
		var item := items[idx] as Dictionary
		var rr   := _inv_row_rect(ri)
		draw_rect(rr, Color(0.08, 0.06, 0.04, 0.9))
		draw_rect(rr, Color(C_BORDER, 0.55), false, 0.8)
		# Власник
		var owner_str := ""
		for ck in GameState.equipped:
			var d: Dictionary = GameState.equipped[ck] as Dictionary
			for s in d:
				if int(d[s]) == idx:
					owner_str = "Герой" if ck == "hero" else str(ck)
					break
			if owner_str != "": break
		var iname  := item.get("name", "?") as String
		var islot  := item.get("slot", "") as String
		var slabel := GameState.SLOT_LABELS.get(islot, islot) as String
		var stats  := _item_stat_str(item)
		draw_string(font, rr.position + Vector2(6, 14), iname,
				HORIZONTAL_ALIGNMENT_LEFT, 210, 13, C_BONE)
		draw_string(font, rr.position + Vector2(6, 28),
				"[%s]  %s" % [slabel, stats],
				HORIZONTAL_ALIGNMENT_LEFT, 340, 10, C_DIM)
		var oc := Color(0.45, 0.88, 0.45) if owner_str != "" else C_FADED
		draw_string(font, rr.position + Vector2(rr.size.x - 82, 14),
				owner_str if owner_str != "" else "вільна",
				HORIZONTAL_ALIGNMENT_LEFT, 80, 11, oc)
	if items.size() > max_rows:
		draw_string(font, pr.position + Vector2(pr.size.x - 58, pr.size.y - 8),
				"%d/%d" % [mini(_inv_scroll + max_rows, items.size()), items.size()],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_FADED)
		draw_string(font, pr.position + Vector2(8, pr.size.y - 8),
				"↑↓ прокрутка колесом миші",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_FADED)

func _draw_inv_loot(font: Font, pr: Rect2) -> void:
	var loot := GameState.loot_bag
	if loot.is_empty():
		draw_string(font, pr.position + Vector2(12, 110),
				"Трофеїв ще немає. Ходи у вилазки!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		return
	var rarity_col: Array[Color] = [
		Color(0.75, 0.75, 0.75),
		Color(0.30, 0.70, 1.00),
		Color(1.00, 0.65, 0.15),
	]
	var rarity_label: Array[String] = ["звичайний", "рідкісний", "★ дуже рідк."]
	var ri := 0
	for key in loot:
		var item_id := int(key)
		if item_id < 0 or item_id >= GameState.EXPEDITION_LOOT.size():
			continue
		var qty    := int(loot[key])
		var meta   := GameState.EXPEDITION_LOOT[item_id] as Dictionary
		var iname  := meta.get("name", "?") as String
		var rarity := clampi(int(meta.get("rarity", 0)), 0, 2)
		var col    := rarity_col[rarity]
		var rr     := _inv_row_rect(ri)
		draw_rect(rr, Color(0.07, 0.06, 0.04, 0.9))
		draw_rect(rr, Color(col.r, col.g, col.b, 0.30), false, 0.8)
		draw_string(font, rr.position + Vector2(6, 22), iname,
				HORIZONTAL_ALIGNMENT_LEFT, 260, 13, col)
		draw_string(font, rr.position + Vector2(270, 22), rarity_label[rarity],
				HORIZONTAL_ALIGNMENT_LEFT, 160, 11, Color(col.r, col.g, col.b, 0.70))
		draw_string(font, rr.position + Vector2(rr.size.x - 52, 22),
				"×%d" % qty, HORIZONTAL_ALIGNMENT_LEFT, 50, 14, Color.WHITE)
		ri += 1

func _draw_resources(font: Font, vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, TOP_H), Color(0.02, 0.016, 0.010, 0.92))
	draw_line(Vector2(0, TOP_H - 1), Vector2(vp.x - RIGHT_W, TOP_H - 1),
			Color(C_BR_SHADOW, 0.7), 1.0)
	var labels: Array[String] = ["Дерево", "Камінь", "Метал", "Їжа"]
	var keys:   Array[String] = ["wood",   "stone",  "metal", "food"]
	var colors: Array[Color]  = [Color(0.7,0.5,0.15), Color(0.60,0.58,0.55), Color(0.45,0.65,0.85), Color(0.35,0.72,0.35)]
	var cols := 4
	var sw   := (vp.x - RIGHT_W) / cols
	for i in cols:
		var cx := sw * i + sw * 0.5
		draw_rect(Rect2(cx - 10, 14, 20, 16), colors[i])
		draw_rect(Rect2(cx - 10, 14, 20, 16), Color(C_BR_SHADOW, 0.4), false, 0.8)
		var val: int = _resources[keys[i]]
		draw_string(font, Vector2(cx - 38, 36), "%s: %d" % [labels[i], val],
				HORIZONTAL_ALIGNMENT_CENTER, 76, 13, C_BONE)

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
	draw_rect(Rect2(rx, 0, RIGHT_W, vp.y), Color(0.02, 0.016, 0.010, 0.88))
	draw_line(Vector2(rx, 0), Vector2(rx, vp.y), Color(C_BR_SHADOW, 0.8), 1.0)

	if _sel_slot != -1:
		# ── Картка будівлі (статична) ───────────────────────────────────
		var bid: int        = SLOT_BUILDING[_sel_slot]
		var b:   Dictionary = BUILDINGS[bid]
		var built           := _slots[_sel_slot] != -1
		var afford          := _can_afford(bid)

		draw_string(font, Vector2(rx + 8, TOP_H + 20),
				b["name"] as String,
				HORIZONTAL_ALIGNMENT_LEFT, RIGHT_W - 10, 15, C_BR_FLARE)

		if built:
			draw_string(font, Vector2(rx + 8, TOP_H + 42),
					"✓ Побудовано",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.88, 0.45))
		else:
			var w: int = b["wood"]; var s: int = b["stone"]; var m: int = b["metal"]
			var cost_col := Color(0.55, 0.85, 0.45) if afford else Color(0.85, 0.38, 0.38)
			draw_string(font, Vector2(rx + 8, TOP_H + 42),
					"Д:%d  К:%d  М:%d" % [w, s, m],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cost_col)

		var companion: String = b["companion"] as String
		var effect:    String = b.get("effect", "") as String
		if companion != "":
			draw_string(font, Vector2(rx + 8, TOP_H + 62),
					"→ " + companion,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_PARCH)
		if effect != "":
			draw_string(font, Vector2(rx + 8, TOP_H + 78),
					effect,
					HORIZONTAL_ALIGNMENT_LEFT, RIGHT_W - 12, 11, C_DIM)

		if not built:
			var br      := _build_btn_rect()
			var btn_col := Color(0.10, 0.36, 0.10, 0.95) if afford else Color(0.28, 0.12, 0.12, 0.9)
			draw_rect(br, btn_col)
			draw_rect(br, Color(C_BORDER, 0.85), false, 1.0)
			var btn_lbl := "Побудувати" if afford else "Не вистачає"
			var lbl_col := C_BONE if afford else C_FADED
			draw_string(font, Vector2(br.position.x + br.size.x * 0.5, br.position.y + 23),
					btn_lbl, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 13, lbl_col)
	else:
		# ── Картка героя ─────────────────────────────────────────────────
		var h: Dictionary = GameState.hero
		if not h.is_empty():
			var hr := Rect2(rx + 4, TOP_H + 8, RIGHT_W - 8, 82)
			draw_rect(hr, Color(0.10, 0.08, 0.03, 0.92))
			draw_rect(hr, Color(C_BORDER_S, 0.85), false, 1.5)
			# Кружок + рівень
			var hcol     := GameState.get_hero_color()
			var hinitial := (h.get("name", "Г") as String).left(1).to_upper()
			draw_circle(Vector2(rx + 24, TOP_H + 45), 14, hcol)
			draw_arc(Vector2(rx + 24, TOP_H + 45), 14, 0, TAU, 32, Color(C_BR_FLARE, 0.9), 2.0)
			draw_string(font, Vector2(rx + 19, TOP_H + 50), hinitial,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			# Ім'я та спеціалізація
			var hname: String = h.get("name", "Герой") as String
			var hspec: String = h.get("spec_name", "") as String
			var hlvl:  int    = GameState.get_hero_level()
			draw_string(font, Vector2(rx + 44, TOP_H + 25), hname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_BR_FLARE)
			draw_string(font, Vector2(rx + 44, TOP_H + 40),
					"%s  Рів.%d" % [hspec, hlvl],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
			# Стан / стати
			if GameState.hero_recovery_raids > 0:
				draw_string(font, Vector2(rx + 8, TOP_H + 57),
						"⚕ Відновлення — наступний рейд без героя",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.55, 0.20))
			else:
				var gender_sym := "♂" if h.get("gender", "m") == "m" else "♀"
				draw_string(font, Vector2(rx + 44, TOP_H + 55),
						"%s  HP:%d  АТК:%d" % [gender_sym, h.get("hp", 50) as int, h.get("dmg", 12) as int],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_FADED)
			# XP-бар
			var xp_bar_x := rx + 8.0;  var xp_bar_w := float(RIGHT_W - 16)
			var xp_by    := TOP_H + 72.0
			var hxp: int = int(h.get("xp", 0))
			var xp_ratio := 1.0
			if hlvl < GameState.MAX_LEVEL:
				var xp_s := GameState.LEVEL_XP[hlvl - 1]
				var xp_e := GameState.LEVEL_XP[hlvl]
				xp_ratio = clampf(float(hxp - xp_s) / float(xp_e - xp_s), 0.0, 1.0)
			draw_rect(Rect2(xp_bar_x, xp_by, xp_bar_w, 6), Color(0.06, 0.05, 0.03))
			draw_rect(Rect2(xp_bar_x, xp_by, xp_bar_w * xp_ratio, 6),
					Color(C_BR_SHADOW, 1.0) if hlvl < GameState.MAX_LEVEL else Color(C_BR_FLARE, 1.0))
			draw_rect(Rect2(xp_bar_x, xp_by, xp_bar_w * xp_ratio, 6),
					Color(C_BORDER_S, 0.45) if hlvl < GameState.MAX_LEVEL else Color(C_BR_FLARE, 0.7), false, 1.0)
			var xp_label: String = "XP %d" % hxp if hlvl >= GameState.MAX_LEVEL \
					else "XP %d / %d" % [hxp, GameState.LEVEL_XP[hlvl]]
			draw_string(font, Vector2(xp_bar_x, xp_by - 1), xp_label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_DIM)

		# ── Загін / компаньйони ──────────────────────────────────────────
		var party_count: int = GameState.raid_party.size()
		draw_string(font, Vector2(rx + 8, TOP_H + 88), "Загін  (%d/3):" % party_count,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_PARCH)
		draw_string(font, Vector2(rx + 8, TOP_H + 104), "клік — додати/прибрати",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_FADED)

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
			var name_col := C_BR_FLARE if in_party else C_PARCH
			var clvl: int = GameState.get_companion_level(uid)
			var lvl_col := C_PARCH if in_party else C_DIM
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
					Color(0.06, 0.05, 0.03))
			draw_rect(Rect2(rr.position.x, rr.position.y + rr.size.y - 3, rr.size.x * xp_cratio, 3),
					Color(C_BR_SHADOW, 1.0) if clvl < GameState.MAX_LEVEL else Color(C_BR_FLARE, 1.0))
			var xp_str: String = ("MAX" if clvl >= GameState.MAX_LEVEL else "%d/%d" % [cxp, cxp_next])
			draw_string(font, rr.position + Vector2(6, 32),
					"HP:%d  АТК:%d  %s  XP:%s" % [hp, dmg, range_str, xp_str],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_FADED)

func _draw_status(font: Font, vp: Vector2) -> void:
	draw_rect(Rect2(0, vp.y - BOT_H, vp.x, BOT_H), Color(0.02, 0.016, 0.010, 0.88))
	draw_line(Vector2(0, vp.y - BOT_H), Vector2(vp.x - RIGHT_W, vp.y - BOT_H),
			Color(C_BR_SHADOW, 0.7), 1.0)
	if _status != "":
		draw_string(font, Vector2(12, vp.y - 13), _status,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, C_BR_FLARE)
	# Усі кнопки — єдиний темно-коричневий стиль, різняться іконкою/кольором тексту
	var mbtn := _map_btn_rect()
	draw_rect(mbtn, Color(0.07, 0.06, 0.03, 0.92))
	draw_rect(mbtn, Color(C_BORDER, 0.75), false, 1.0)
	draw_string(font, mbtn.position + Vector2(10, 19), "> Карта світу",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_PARCH)
	var wb := _workers_btn_rect()
	draw_rect(wb, Color(0.07, 0.06, 0.03, 0.92))
	draw_rect(wb, Color(C_BORDER, 0.75), false, 1.0)
	var pop_str := "⚑ Люди: %d" % GameState.population
	if GameState.pending_population > 0:
		pop_str += "  (+%d)" % GameState.pending_population
	draw_string(font, wb.position + Vector2(10, 19), pop_str,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.85, 0.55))
	var eb := _equip_btn_rect()
	draw_rect(eb, Color(0.07, 0.06, 0.03, 0.92))
	draw_rect(eb, Color(C_BORDER, 0.75), false, 1.0)
	draw_string(font, eb.position + Vector2(10, 19), "⚔ Спорядження",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_PARCH)
	var ib := _inv_btn_rect()
	draw_rect(ib, Color(0.07, 0.06, 0.03, 0.92))
	draw_rect(ib, Color(C_BORDER, 0.75), false, 1.0)
	draw_string(font, ib.position + Vector2(10, 19), "◆ Інвентар",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_PARCH)
	var rb := _rest_btn_rect()
	draw_rect(rb, Color(0.07, 0.06, 0.03, 0.92))
	draw_rect(rb, Color(C_BORDER, 0.75), false, 1.0)
	draw_string(font, rb.position + Vector2(10, 19), "⏭ Відпочити",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.50, 0.80, 0.50))

func _draw_worker_popup(font: Font) -> void:
	var pr     := _popup_rect()
	var rkeys: Array[String]  = ["wood", "stone", "metal", "food"]
	var rlabels: Array[String] = ["Дерево", "Камінь", "Метал", "Їжа"]
	var rcols: Array[Color]    = [Color(0.6,0.4,0.1), Color(0.55,0.55,0.55),
								  Color(0.4,0.6,0.8), Color(0.3,0.7,0.3)]

	# Тінь + фон
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y),
			Color(0, 0, 0, 0.72))
	draw_rect(pr.grow(4.0), Color(0, 0, 0, 0.40))
	draw_rect(pr, Color(0.12, 0.095, 0.065, 0.98))
	draw_rect(pr, Color(C_BORDER_S, 0.85), false, 1.5)
	# Заголовок — власна смуга
	var hdr_r_w := Rect2(pr.position.x, pr.position.y, pr.size.x, 38)
	draw_rect(hdr_r_w, Color(0.08, 0.062, 0.040, 0.95))
	draw_string(font, pr.position + Vector2(12, 25), "Розподіл робітників",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_BR_FLARE)
	_draw_ornament_divider(pr.position.x + 8, pr.position.x + pr.size.x - 8,
			pr.position.y + 38.0, Color(C_BORDER_S, 0.45))

	# Кнопка закрити
	var cr := _popup_close_rect()
	draw_rect(cr, Color(0.18, 0.06, 0.06, 0.95))
	draw_rect(cr, Color(C_BORDER, 0.8), false, 1.0)
	draw_string(font, cr.position + Vector2(7, 18), "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C_BONE, 0.9))

	# Населення
	var used: int = 0
	for k in GameState.workers: used += int(GameState.workers[k])
	var free_pop: int = GameState.population - used
	draw_string(font, pr.position + Vector2(12, 48),
			"Населення: %d   |   Призначено: %d   |   Вільні: %d" % [
				GameState.population, used, free_pop],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_PARCH)
	draw_string(font, pr.position + Vector2(12, 64),
			"Їжа: %d  (споживання: %d/цикл)" % [
				GameState.resources.get("food", 0), ceili(GameState.population / 2.0)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)

	# Рядки ресурсів
	for ri in rkeys.size():
		var key:   String = rkeys[ri]
		var label: String = rlabels[ri]
		var col:   Color  = rcols[ri]
		var w:     int    = GameState.workers.get(key, 0)
		var prod:  int    = w * int(GameState.WORKER_PRODUCTIVITY[key])
		var ry    := pr.position.y + 80 + ri * 54.0

		draw_rect(Rect2(pr.position.x + 8, ry + 4, pr.size.x - 16, 46), Color(0.06, 0.05, 0.03))
		draw_rect(Rect2(pr.position.x + 8, ry + 4, pr.size.x - 16, 46), Color(col, 0.22), false, 1.0)
		draw_rect(Rect2(pr.position.x + 14, ry + 16, 12, 12), col)
		draw_string(font, Vector2(pr.position.x + 32, ry + 26), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_BONE)
		draw_string(font, Vector2(pr.position.x + 32, ry + 42),
				"+%d/цикл" % prod,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col if prod > 0 else C_FADED)

		# Кнопки [-] [N] [+]
		var mr := _popup_minus_rect(ri)
		var pr2 := _popup_plus_rect(ri)
		var hov_m := _hov_wbtn == ri * 2
		var hov_p := _hov_wbtn == ri * 2 + 1
		draw_rect(mr, Color(0.28, 0.08, 0.08, 0.95) if hov_m else Color(0.14, 0.06, 0.06, 0.9))
		draw_rect(mr, Color(C_BORDER, 0.8), false, 1.0)
		draw_string(font, mr.position + Vector2(8, 18), "−",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_BONE)
		draw_string(font, Vector2(mr.position.x + mr.size.x + 6, mr.position.y + 18),
				"%d" % w, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_BR_FLARE)
		draw_rect(pr2, Color(0.08, 0.22, 0.08, 0.95) if hov_p else Color(0.06, 0.14, 0.06, 0.9))
		draw_rect(pr2, Color(C_BORDER, 0.8), false, 1.0)
		draw_string(font, pr2.position + Vector2(8, 18), "+",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_BONE)
	_draw_popup_fade(_popup_rect())

func _draw_equip_popup(font: Font) -> void:
	var pr    := _equip_popup_rect()
	var chars := _equip_chars()

	# Затемнення + фон
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, get_viewport_rect().size.y),
			Color(0, 0, 0, 0.72))
	draw_rect(pr.grow(4.0), Color(0, 0, 0, 0.40))
	draw_rect(pr, Color(0.12, 0.095, 0.065, 0.98))
	draw_rect(pr, Color(C_BORDER_S, 0.85), false, 1.5)
	# Заголовок — власна смуга
	var hdr_r_eq := Rect2(pr.position.x, pr.position.y, pr.size.x, 38)
	draw_rect(hdr_r_eq, Color(0.08, 0.062, 0.040, 0.95))
	draw_string(font, pr.position + Vector2(12, 25), "Спорядження",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_BR_FLARE)
	var cr := _equip_close_rect()
	draw_rect(cr, Color(0.18, 0.06, 0.06, 0.95))
	draw_rect(cr, Color(C_BORDER, 0.8), false, 1.0)
	draw_string(font, cr.position + Vector2(7, 18), "✕",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(C_BONE, 0.9))

	if chars.is_empty():
		draw_string(font, pr.position + Vector2(12, 100),
				"Немає персонажів у загоні. Додай компаньйона і відкрий знову.",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_DIM)
		return

	# ── Вкладки персонажів ────────────────────────────────────────────────
	_equip_char_idx = mini(_equip_char_idx, chars.size() - 1)
	for i in chars.size():
		var tab_r := _equip_tab_rect(i)
		var is_a  := i == _equip_char_idx
		var is_h  := i == _equip_hov_tab and not is_a
		draw_rect(tab_r, Color(0.22, 0.16, 0.04, 0.95) if is_a else
				(Color(0.15, 0.11, 0.04, 0.92) if is_h else Color(0.08, 0.065, 0.042, 0.88)))
		draw_rect(tab_r, C_BORDER_S if is_a else Color(C_BORDER, 0.65), false, 1.0)
		draw_string(font, tab_r.position + Vector2(6, 18), chars[i]["name"] as String,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				C_BR_FLARE if is_a else C_DIM)

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
		if is_sel:                bg = Color(0.22, 0.16, 0.04, 0.95)
		elif is_h:                bg = Color(0.16, 0.12, 0.04, 0.92)
		elif not item.is_empty(): bg = Color(0.11, 0.09, 0.03, 0.9)
		else:                     bg = Color(0.075, 0.060, 0.038, 0.90)
		draw_rect(sr, bg)
		draw_rect(sr, C_BORDER_S if is_sel else (Color(C_BORDER_S, 0.65) if not item.is_empty() else Color(C_BORDER, 0.5)),
				false, 1.5 if is_sel else 1.0)

		# Назва слоту (дрібно зверху)
		draw_string(font, sr.position + Vector2(5, 13), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C_DIM)

		if item.is_empty():
			var hint := "[ клік → вибрати ]" if is_sel else "[ порожньо ]"
			var hcol := Color(C_BORDER_S, 0.75) if is_sel else C_FADED
			draw_string(font, sr.position + Vector2(5, 36), hint,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hcol)
		else:
			var iname: String = item.get("name", "???") as String
			draw_string(font, sr.position + Vector2(5, 34), iname,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_BONE)
			var stats := _item_stat_str(item)
			if stats != "":
				draw_string(font, sr.position + Vector2(5, 47), stats,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.85, 0.55))
			if is_sel:
				draw_string(font, sr.position + Vector2(sr.size.x - 64, 47), "кліщ:зняти",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.90, 0.40, 0.35))

	# ── Секція інвентаря (показується коли обраний слот) ──────────────────
	var iy0 := _inv_header_y()
	_draw_ornament_divider(pr.position.x + 8, pr.position.x + pr.size.x - 8,
			iy0, Color(C_BORDER_S, 0.40))

	if _equip_sel_slot != -1:
		var sel_slot: String = GameState.EQUIP_SLOTS[_equip_sel_slot]
		draw_string(font, Vector2(pr.position.x + 8, iy0 + 14),
				"Інвентар  [%s]:" % (GameState.SLOT_LABELS[sel_slot] as String),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_BR_FLARE)

		var matching := _matching_items(char_key, sel_slot)
		if matching.is_empty():
			draw_string(font, Vector2(pr.position.x + 8, iy0 + 42),
					"Немає підходящих предметів (Кузня → будуй для отримання)",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
		else:
			_equip_inv_off = mini(_equip_inv_off, maxi(0, matching.size() - 4))
			for ri in mini(4, matching.size() - _equip_inv_off):
				var idx: int = matching[_equip_inv_off + ri]
				var it: Dictionary = GameState.inventory[idx] as Dictionary
				var ir    := _inv_item_rect(ri)
				var is_ih := ri == _equip_inv_hov
				draw_rect(ir, Color(0.22, 0.16, 0.04, 0.95) if is_ih else Color(0.08, 0.07, 0.04, 0.9))
				draw_rect(ir, C_BORDER_S if is_ih else Color(C_BORDER, 0.55), false, 1.0 if is_ih else 0.8)
				draw_string(font, ir.position + Vector2(6, 20),
						(it.get("name", "?") as String) + "  " + _item_stat_str(it),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
						C_BR_FLARE if is_ih else C_BONE)
			# Кнопки прокрутки
			if matching.size() > 4:
				var su := _inv_scroll_up_rect()
				var sd := _inv_scroll_dn_rect()
				draw_rect(su, Color(0.12, 0.09, 0.04, 0.92)); draw_rect(su, Color(C_BORDER, 0.7), false, 1.0)
				draw_rect(sd, Color(0.12, 0.09, 0.04, 0.92)); draw_rect(sd, Color(C_BORDER, 0.7), false, 1.0)
				draw_string(font, su.position + Vector2(10,20), "↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_BONE)
				draw_string(font, sd.position + Vector2(10,20), "↓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_BONE)
	else:
		draw_string(font, Vector2(pr.position.x + 8, iy0 + 14),
				"Клікни на слот щоб побачити доступні предмети",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)

	# ── Підсумок броні ────────────────────────────────────────────────────
	var by  := pr.position.y + pr.size.y - 26
	draw_rect(Rect2(pr.position.x + 8, by - 6, pr.size.x - 16, 24), Color(0.05, 0.04, 0.02))
	var total_armor := GameState.get_char_armor(char_key)
	var total_dmg   := GameState.get_char_dmg_bonus(char_key)
	var summary     := "Броня: %d" % total_armor
	if total_armor > 0:
		var reduc := int(round(float(total_armor) / float(total_armor + 100) * 100.0))
		summary += "  (-%d%% урону)" % reduc
	if total_dmg > 0: summary += "   АТК: +%d" % total_dmg
	draw_string(font, Vector2(pr.position.x + 12, by + 10), summary,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.88, 0.55))
	_draw_popup_fade(pr)

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
