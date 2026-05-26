extends Node

var current_slot: int = 0   # активний слот збереження (0-2)

var resources:  Dictionary[String, int] = {}
var base_slots: Array[int]             = []

# ── Головний герой ────────────────────────────────────────────────────────
var hero: Dictionary = {}

const HERO_DEFAULT: Dictionary = {
	"name":       "Герой",
	"move_range": 3,
	"hp":         50,
	"dmg":        12,
	"atk_range":  1,
}

# Companion stats indexed by building ID (matches BaseScene.BUILDINGS order)
# Індекс у масиві = uid компаньйона.
# "building" — яка будівля (BaseScene.BUILDINGS index) відкриває цього персонажа.
# Одна будівля може відкривати кількох компаньйонів (наприклад Каплиця → Клірик + Паладін).
# "class_idx" — відповідає індексу в CharacterCreationScene.CLASSES (для мультикласу).
# Імена зараз — плейсхолдери класу; згодом замінити на унікальні імена персонажів.
const COMPANIONS: Array = [
	# uid 0 — Каплиця (building 0)
	{"name": "Клірик",  "building": 0, "class_idx": 0,
	 "move_range": 2, "hp": 35, "dmg":  6, "atk_range": 1},
	# uid 1 — Каплиця (building 0)
	{"name": "Паладін", "building": 0, "class_idx": 1,
	 "move_range": 2, "hp": 38, "dmg":  7, "atk_range": 1},
	# uid 2 — Казарма (building 1)
	{"name": "Воїн",    "building": 1, "class_idx": 2,
	 "move_range": 3, "hp": 30, "dmg":  8, "atk_range": 1},
	# uid 3 — Гільдія злодіїв (building 2)
	{"name": "Злодій",  "building": 2, "class_idx": 3,
	 "move_range": 4, "hp": 20, "dmg": 10, "atk_range": 1},
	# uid 4 — Башта мага (building 3) — дальній
	{"name": "Маг",     "building": 3, "class_idx": 4,
	 "move_range": 2, "hp": 22, "dmg": 12, "atk_range": 3},
	# uid 5 — Мисливська хижа (building 4) — дальній
	{"name": "Мисл.",   "building": 4, "class_idx": 5,
	 "move_range": 3, "hp": 25, "dmg":  9, "atk_range": 2},
	# uid 6 — Святилище тіней (building 5) — дальній
	{"name": "Оккуль.", "building": 5, "class_idx": 6,
	 "move_range": 2, "hp": 28, "dmg":  8, "atk_range": 2},
	# uid 7 — Таверна (building 6)
	{"name": "Бард",    "building": 6, "class_idx": 7,
	 "move_range": 3, "hp": 26, "dmg":  7, "atk_range": 1},
	# Кузня (building 7) — немає компаньйона
]

# Скільки одиниць ресурсу виробляє 1 робітник за цикл
const WORKER_PRODUCTIVITY: Dictionary = {
	"wood":  2,   # дерево легко рубати
	"stone": 1,   # камінь важче
	"metal": 1,   # метал важче
	"food":  2,   # їжу легко вирощувати
}

# Скільки людей приходить до міста після побудови конкретної споруди (наступний цикл)
const BUILDING_POPULATION: Dictionary = {
	0: 10,   # Каплиця
	1: 8,    # Казарма
	2: 6,    # Гільдія злодіїв
	3: 5,    # Башта мага
	4: 7,    # Мисливська хижа
	5: 6,    # Святилище тіней
	6: 8,    # Таверна
	7: 5,    # Кузня
}

# ── Спорядження: константи ───────────────────────────────────────────────
# Типи броні за матеріалом (НЕ за вагою — немає класових обмежень!)
# Кожен тип дає різні бонуси, підштовхує до стилю, але нікого не блокує.
const ARMOR_CLOTH     := 0   # Тканина  — магія, лікування, ініціатива
const ARMOR_LEATHER   := 1   # Шкіра    — спритність, критик, ухилення
const ARMOR_CHAINMAIL := 2   # Кольчуга — баланс броні, HP, стійкість
const ARMOR_PLATE     := 3   # Латна    — максимальна броня, HP, витривалість
const ARMOR_TYPE_NAMES: Array[String] = ["Тканина", "Шкіра", "Кольчуга", "Латна"]

# 11 слотів спорядження (порядок = порядок у UI)
const EQUIP_SLOTS: Array[String] = [
	"helmet", "neck", "chest", "gloves", "belt",
	"legs",   "boots", "ring1", "ring2",
	"main_hand", "off_hand"
]
const SLOT_LABELS: Dictionary = {
	"helmet":    "Шолом",
	"neck":      "Шия",
	"chest":     "Тіло",
	"gloves":    "Наручі",
	"belt":      "Пояс",
	"legs":      "Поножі",
	"boots":     "Чоботи",
	"ring1":     "Кільце 1",
	"ring2":     "Кільце 2",
	"main_hand": "Осн. рука",
	"off_hand":  "Доп. рука",
}
# Слоти для кілець — предмет зі slot="ring" підходить у обидва
const RING_SLOTS: Array[String] = ["ring1", "ring2"]

# ── Рівні та прокачка ─────────────────────────────────────────────────────
const MAX_LEVEL: int = 10
# Мінімальний накопичений XP для досягнення кожного рівня (index = level − 1)
# Level 1 → 0 XP,  Level 2 → 150 XP,  Level 3 → 400 XP … Level 10 → 5000 XP
const LEVEL_XP: Array[int] = [0, 150, 400, 750, 1200, 1750, 2400, 3150, 4000, 5000]

# ── Трофеї з вилазок ─────────────────────────────────────────────────────
# rarity: 0=звичайні, 1=рідкісні, 2=дуже рідкісні
const EXPEDITION_LOOT: Array[Dictionary] = [
	{"id": 0, "name": "Гоблінське вухо",    "rarity": 0},
	{"id": 1, "name": "Вовча шкіра",        "rarity": 0},
	{"id": 2, "name": "Стародавня монета",  "rarity": 1},
	{"id": 3, "name": "Магічний кристал",   "rarity": 1},
	{"id": 4, "name": "Отруйне жало",       "rarity": 1},
	{"id": 5, "name": "Зламаний артефакт",  "rarity": 2},
	{"id": 6, "name": "Ельфійська реліквія","rarity": 2},
	{"id": 7, "name": "Кістка велетня",     "rarity": 2},
]

const GOSSIP_TEXTS: Array[String] = [
	"«Орки посилюють охорону на сході... будь обережний»",
	"«У руїнах стара вежа — кажуть, там схований скарб»",
	"«Гноми шукають союзників проти темної навали»",
	"«Бачив незнайомця з картою підземних ходів»",
	"«Ельфи закрили кордони. Але є таємний прохід крізь ліс»",
	"«Цей ліс прокляте місце — вдвічі більше чудовиськ»",
	"«Щось велике наближається з півночі...»",
	"«Торговець прийшов у місто — він продає дивні речі»",
]

# Дії кожної будівлі. Структура рядка:
#   label, desc — відображення
#   cost: {ресурс: кількість}   loot_cost: {item_id: кількість}
#   effect: ідентифікатор ефекту   effect_data: параметри
const BUILDING_ACTIONS: Dictionary = {
	0: [  # Каплиця
		{"label": "Благословення загону",
		 "desc": "+30 XP для всього загону",
		 "cost": {"food": 8}, "loot_cost": {},
		 "effect": "award_party_xp", "effect_data": {"xp": 30}},
	],
	1: [  # Казарма
		{"label": "Бойові тренування",
		 "desc": "+50 XP для всього загону",
		 "cost": {"food": 10, "wood": 5}, "loot_cost": {},
		 "effect": "award_party_xp", "effect_data": {"xp": 50}},
	],
	2: [  # Гільдія злодіїв
		{"label": "Крадіжка запасів",
		 "desc": "Здобути ресурси з міста",
		 "cost": {"food": 5}, "loot_cost": {},
		 "effect": "award_resources", "effect_data": {"wood": 8, "stone": 5, "metal": 3}},
		{"label": "Вулична розвідка",
		 "desc": "Знайти трофеї у місті",
		 "cost": {"food": 8}, "loot_cost": {},
		 "effect": "award_loot_random", "effect_data": {}},
	],
	3: [  # Башта мага
		{"label": "Кільце воїна",
		 "desc": "+12 HP, +2 Атк",
		 "cost": {}, "loot_cost": {0: 2},
		 "effect": "craft_item",
		 "effect_data": {"name": "Кільце воїна", "slot": "ring", "hp_bonus": 12, "dmg_bonus": 2}},
		{"label": "Кільце чаклуна",
		 "desc": "+15 Маг",
		 "cost": {}, "loot_cost": {3: 2},
		 "effect": "craft_item",
		 "effect_data": {"name": "Кільце чаклуна", "slot": "ring", "magic_bonus": 15}},
		{"label": "Амулет захисту",
		 "desc": "+5 Броня, +15 HP",
		 "cost": {}, "loot_cost": {2: 2, 3: 1},
		 "effect": "craft_item",
		 "effect_data": {"name": "Амулет захисту", "slot": "neck", "armor": 5, "hp_bonus": 15}},
		{"label": "Амулет спритності",
		 "desc": "+4 Спр, +2 Ініц, +5% Крит",
		 "cost": {}, "loot_cost": {4: 2, 2: 1},
		 "effect": "craft_item",
		 "effect_data": {"name": "Амулет спритності", "slot": "neck",
		                 "agility_bonus": 4, "initiative_bonus": 2, "critical_bonus": 5}},
		{"label": "Артефактне кільце",
		 "desc": "+20 HP, +3 Атк, +10 Маг",
		 "cost": {}, "loot_cost": {5: 1},
		 "effect": "craft_item",
		 "effect_data": {"name": "Артефактне кільце", "slot": "ring",
		                 "hp_bonus": 20, "dmg_bonus": 3, "magic_bonus": 10}},
	],
	4: [  # Мисл.хижа
		{"label": "Полювання",
		 "desc": "+15 їжі, шанс знайти трофеї",
		 "cost": {"food": 3}, "loot_cost": {},
		 "effect": "award_hunt", "effect_data": {"food": 15}},
	],
	5: [  # Святилище тіней
		{"label": "Темний ритуал",
		 "desc": "+80 XP загону",
		 "cost": {"food": 15}, "loot_cost": {5: 1},
		 "effect": "award_party_xp", "effect_data": {"xp": 80}},
		{"label": "Отруйний амулет",
		 "desc": "+15% Крит, +4 Спр",
		 "cost": {}, "loot_cost": {4: 3},
		 "effect": "craft_item",
		 "effect_data": {"name": "Амулет темряви", "slot": "neck",
		                 "critical_bonus": 15, "agility_bonus": 4}},
	],
	6: [  # Таверна
		{"label": "Почути чутки",
		 "desc": "Дізнатись про наступну вилазку",
		 "cost": {"food": 5}, "loot_cost": {},
		 "effect": "gossip", "effect_data": {}},
	],
	7: [  # Кузня
		{"label": "Кований меч",
		 "desc": "+7 Атк",
		 "cost": {"metal": 8, "wood": 3}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Кований меч", "slot": "main_hand", "dmg_bonus": 7}},
		{"label": "Довгий меч",
		 "desc": "+10 Атк",
		 "cost": {"metal": 15, "wood": 5}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Довгий меч", "slot": "main_hand", "dmg_bonus": 10}},
		{"label": "Бойова сокира",
		 "desc": "+12 Атк, дворучна",
		 "cost": {"metal": 18, "wood": 6}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Бойова сокира", "slot": "main_hand",
		                 "dmg_bonus": 12, "two_handed": true}},
		{"label": "Металевий щит",
		 "desc": "+10 Броня, +18 Щит",
		 "cost": {"metal": 12, "wood": 8}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Металевий щит", "slot": "off_hand",
		                 "armor": 10, "simple_barrier": 18}},
		{"label": "Кована кольчуга",
		 "desc": "+18 Броня, +5 HP",
		 "cost": {"metal": 20, "stone": 8}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Кована кольчуга", "slot": "chest",
		                 "armor_type": 2, "armor": 18, "hp_bonus": 5}},
		{"label": "Латний панцир",
		 "desc": "+25 Броня, +20 HP",
		 "cost": {"metal": 35, "stone": 12}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Латний панцир", "slot": "chest",
		                 "armor_type": 3, "armor": 25, "hp_bonus": 20}},
		{"label": "Кований шолом",
		 "desc": "+8 Броня",
		 "cost": {"metal": 10, "stone": 4}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Кований шолом", "slot": "helmet",
		                 "armor_type": 2, "armor": 8}},
		{"label": "Кольчужні поножі",
		 "desc": "+12 Броня, +8 HP",
		 "cost": {"metal": 14, "stone": 5}, "loot_cost": {},
		 "effect": "craft_item",
		 "effect_data": {"name": "Кольчужні поножі", "slot": "legs",
		                 "armor_type": 2, "armor": 12, "hp_bonus": 8}},
	],
}

# Варіанти вибору при левелапі (choice_id → дані)
const LEVELUP_CHOICES: Array = [
	{"id": 0, "label": "+12 HP  — Витривалість", "icon": "❤"},
	{"id": 1, "label": "+2 Атк  — Сила",         "icon": "⚔"},
	{"id": 2, "label": "+1 Очко навичок",         "icon": "✦"},
]

var hero_created:         bool        = false
var hero_recovery_raids:  int         = 0   # >0 → герой пропускає рейд
var tutorial_done:        bool        = false
var raid_party:           Array[int]  = []
var explored_directions:  Array[int]  = []   # legacy, не видаляємо
var current_direction:    int         = -1
var world_explored:       Array[int]  = []   # id вузлів карти світу що пройдені
var current_world_node:   int         = -1   # вузол карти світу поточної вилазки

# ── Населення та економіка ────────────────────────────────────────────────
var population:            int                    = 0
var pending_population:    int                    = 0   # прийдуть після наступного циклу
var workers:               Dictionary[String, int] = {}
var gold:                  int                    = 0

# Спорядження
# Структура предмету: {name, slot, armor_type, armor, dmg_bonus,
#                      atk_range, initiative_bonus, hp_bonus, two_handed}
var inventory: Array = []
# equipped["hero"]["chest"] = inventory_index
# equipped["c2"]["main_hand"] = inventory_index
var equipped:             Dictionary = {}
var loot_bag:             Dictionary = {}   # str(item_id) → quantity
# Прогрес компаньйонів: ключ = "c{uid}", значення = {level, xp, hp, dmg, skill_points}
var companion_progress:   Dictionary = {}
# Персонажі що підвищили рівень і чекають на вибір стату
# ключ = char_key ("hero" / "c{uid}"), значення = {name, new_level}
var pending_levelups:     Dictionary = {}

# Регіональна карта
var regional_nodes:   Array = []
var regional_edges:   Array = []
var regional_current: int   = 0
var regional_visited:      Array[int] = []
var in_regional_map:       bool       = false
var regional_combat_pending: bool     = false   # true = бій розпочато але не завершено

enum NodeType { START, COMBAT, LOOT, END }

func _ready() -> void:
	_init_state()
	load_game()

func _init_state() -> void:
	resources  = {"wood": 0, "stone": 0, "metal": 0, "food": 0}
	base_slots = [-1, -1, -1, -1, -1, -1, -1, -1]
	hero                 = {}
	hero_created         = false
	hero_recovery_raids  = 0
	tutorial_done        = false
	raid_party           = []
	explored_directions  = []
	current_direction    = -1
	world_explored       = []
	current_world_node   = -1
	population           = 0
	pending_population   = 0
	workers              = {"wood": 0, "stone": 0, "metal": 0, "food": 0}
	gold                 = 0
	inventory            = []
	equipped             = {}
	loot_bag             = {}
	companion_progress   = {}
	pending_levelups     = {}

func start_new_game(hero_data: Dictionary) -> void:
	_init_state()
	hero         = hero_data
	hero_created = true
	hero["level"] = 1
	hero["xp"]    = 0
	give_starter_items(int(hero_data.get("class_idx", 0)))
	save_game()

func get_hero_color() -> Color:
	if hero.has("color_r"):
		return Color(float(hero.get("color_r", 0.95)),
					 float(hero.get("color_g", 0.80)),
					 float(hero.get("color_b", 0.20)))
	return Color(0.95, 0.80, 0.20)   # default gold

# Повертає список uid компаньйонів, будівля яких побудована на базі.
func get_available_companions() -> Array[int]:
	var result: Array[int] = []
	for i in COMPANIONS.size():
		var bid: int = COMPANIONS[i]["building"]
		if base_slots.has(bid) and not result.has(i):
			result.append(i)
	return result

func start_regional_map() -> void:
	# Validate party against built companions
	var available := get_available_companions()
	var valid: Array[int] = []
	for uid in raid_party:
		if available.has(uid):
			valid.append(uid)
	if valid.is_empty() and not available.is_empty():
		valid.append(available[0])
	raid_party = valid
	if tutorial_done:
		_generate_map()
	else:
		_generate_tutorial_map()
	regional_current = 0
	regional_visited = [0]
	in_regional_map  = true

func end_regional_map() -> void:
	in_regional_map          = false
	regional_combat_pending  = false
	# Позначаємо вузол карти світу як пройдений
	if current_world_node >= 0 and not world_explored.has(current_world_node):
		world_explored.append(current_world_node)
	current_world_node = -1
	process_cycle()

# Викликається кожного разу при поверненні на базу після вилазки
func process_cycle() -> void:
	# 1. Нові люди прибувають
	population        += pending_population
	pending_population = 0

	# 2. Робітники виробляють ресурси
	for key in WORKER_PRODUCTIVITY:
		var w:    int = workers.get(key, 0)
		var prod: int = int(WORKER_PRODUCTIVITY[key])
		if key == "food" and has_building(4):   # Мисливська хижа: +1 їжа/робітник
			prod += 1
		resources[key] += w * prod

	# 3. Їжа споживається (1 їжа = 2 людини за цикл)
	var consumed: int = ceili(population / 2.0)
	if resources["food"] >= consumed:
		resources["food"] -= consumed
	else:
		# Нестача їжі — населення скорочується
		var shortage: int = consumed - resources["food"]
		resources["food"] = 0
		population        = maxi(0, population - shortage)
		_clamp_workers()

func _clamp_workers() -> void:
	# Якщо населення впало нижче суми робітників — знімаємо зайвих
	var total: int = 0
	for key in workers:
		total += int(workers[key])
	if total <= population:
		return
	for key in ["food", "metal", "stone", "wood"]:
		if total <= population:
			break
		var remove: int = mini(total - population, int(workers.get(key, 0)))
		workers[key]    = int(workers.get(key, 0)) - remove
		total          -= remove

# ── Хелпери будівель ──────────────────────────────────────────────────────
func get_built_buildings() -> Array[int]:
	var result: Array[int] = []
	for bid in base_slots:
		if bid != -1 and not result.has(bid):
			result.append(bid)
	return result

func has_building(bid: int) -> bool:
	return base_slots.has(bid)

# ── Збереження ────────────────────────────────────────────────────────────
func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot

func has_save(slot: int = -1) -> bool:
	var s := current_slot if slot < 0 else slot
	return FileAccess.file_exists(slot_path(s))

func any_save_exists() -> bool:
	for i in 3:
		if has_save(i):
			return true
	return false

func get_slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var data  := parsed as Dictionary
	var h     = data.get("hero", {})
	if not h is Dictionary:
		return {}
	var hd := h as Dictionary
	var loc: String = "Вилазка" if bool(data.get("in_regional_map", false)) else "База"
	return {
		"name":     str(hd.get("name",     "???")),
		"class":    str(hd.get("spec_name", "")),
		"location": loc,
		"date":     str(data.get("save_date", "")),
		"level":    int(hd.get("level", 1)),
	}

func save_game() -> void:
	var dt   := Time.get_datetime_dict_from_system()
	var date := "%02d.%02d  %02d:%02d" % [
		int(dt["day"]), int(dt["month"]), int(dt["hour"]), int(dt["minute"])]
	var data: Dictionary = {
		"resources":           resources,
		"base_slots":          Array(base_slots),
		"raid_party":          Array(raid_party),
		"explored_directions": Array(explored_directions),
		"world_explored":      Array(world_explored),
		"hero":                hero,
		"hero_created":        hero_created,
		"hero_recovery_raids": hero_recovery_raids,
		"tutorial_done":       tutorial_done,
		"population":          population,
		"pending_population":  pending_population,
		"workers":             workers,
		"gold":                gold,
		"inventory":           inventory,
		"equipped":            equipped,
		"loot_bag":            loot_bag,
		"companion_progress":  companion_progress,
		"pending_levelups":    pending_levelups,
		# ── Стан вилазки ─────────────────────────────────────────────────
		"in_regional_map":          in_regional_map,
		"current_direction":        current_direction,
		"current_world_node":       current_world_node,
		"regional_nodes":           regional_nodes,
		"regional_edges":           regional_edges,
		"regional_current":         regional_current,
		"regional_visited":         Array(regional_visited),
		"regional_combat_pending":  regional_combat_pending,
		"save_date":               date,
	}
	var file := FileAccess.open(slot_path(current_slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game(slot: int = -1) -> void:
	if slot >= 0:
		current_slot = slot
	if not FileAccess.file_exists(slot_path(current_slot)):
		return
	var file := FileAccess.open(slot_path(current_slot), FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	if data.has("resources") and data["resources"] is Dictionary:
		for key in data["resources"]:
			if resources.has(key):
				resources[key] = int(data["resources"][key])
	if data.has("base_slots") and data["base_slots"] is Array:
		var s: Array = data["base_slots"]
		for i in mini(s.size(), base_slots.size()):
			base_slots[i] = int(s[i])
	if data.has("raid_party") and data["raid_party"] is Array:
		raid_party.clear()
		for v in data["raid_party"]:
			raid_party.append(int(v))
	if data.has("explored_directions") and data["explored_directions"] is Array:
		explored_directions.clear()
		for v in data["explored_directions"]:
			explored_directions.append(int(v))
	if data.has("world_explored") and data["world_explored"] is Array:
		world_explored.clear()
		for v in data["world_explored"]:
			world_explored.append(int(v))
	if data.has("hero_created"):
		hero_created = bool(data["hero_created"])
	if data.has("hero_recovery_raids"):
		hero_recovery_raids = int(data["hero_recovery_raids"])
	if data.has("tutorial_done"):
		tutorial_done = bool(data["tutorial_done"])
	if data.has("population"):
		population = int(data["population"])
	if data.has("pending_population"):
		pending_population = int(data["pending_population"])
	if data.has("gold"):
		gold = int(data["gold"])
	if data.has("inventory") and data["inventory"] is Array:
		inventory = data["inventory"] as Array
	if data.has("equipped") and data["equipped"] is Dictionary:
		equipped = data["equipped"] as Dictionary
	if data.has("loot_bag") and data["loot_bag"] is Dictionary:
		loot_bag = data["loot_bag"] as Dictionary
	if data.has("companion_progress") and data["companion_progress"] is Dictionary:
		companion_progress = data["companion_progress"] as Dictionary
	if data.has("pending_levelups") and data["pending_levelups"] is Dictionary:
		pending_levelups = data["pending_levelups"] as Dictionary
	# ── Стан вилазки ─────────────────────────────────────────────────────
	if data.has("in_regional_map"):
		in_regional_map = bool(data["in_regional_map"])
	if data.has("current_direction"):
		current_direction = int(data["current_direction"])
	if data.has("current_world_node"):
		current_world_node = int(data["current_world_node"])
	if data.has("regional_nodes") and data["regional_nodes"] is Array:
		regional_nodes = data["regional_nodes"] as Array
	if data.has("regional_edges") and data["regional_edges"] is Array:
		regional_edges = data["regional_edges"] as Array
	if data.has("regional_current"):
		regional_current = int(data["regional_current"])
	if data.has("regional_visited") and data["regional_visited"] is Array:
		regional_visited.clear()
		for v in (data["regional_visited"] as Array):
			regional_visited.append(int(v))
	if data.has("regional_combat_pending"):
		regional_combat_pending = bool(data["regional_combat_pending"])
	if data.has("workers") and data["workers"] is Dictionary:
		var w = data["workers"]
		for key in ["wood", "stone", "metal", "food"]:
			workers[key] = int(w.get(key, 0))
	# Очищаємо equipped від невалідних індексів (може трапитись після пошкодження збереження)
	_validate_equipped()
	if data.has("hero") and data["hero"] is Dictionary:
		var h = data["hero"]
		hero["name"]       = str(h.get("name",       HERO_DEFAULT["name"]))
		hero["gender"]     = str(h.get("gender",     "m"))
		hero["class_idx"]  = int(h.get("class_idx",  0))
		hero["spec_name"]  = str(h.get("spec_name",  ""))
		hero["move_range"] = int(h.get("move_range",  HERO_DEFAULT["move_range"]))
		hero["hp"]         = int(h.get("hp",          HERO_DEFAULT["hp"]))
		hero["dmg"]        = int(h.get("dmg",         HERO_DEFAULT["dmg"]))
		hero["atk_range"]  = int(h.get("atk_range",   HERO_DEFAULT["atk_range"]))
		hero["level"]      = int(h.get("level", 1))
		hero["xp"]         = int(h.get("xp",    0))
		if h.has("color_r"):
			hero["color_r"] = float(h.get("color_r", 0.95))
			hero["color_g"] = float(h.get("color_g", 0.80))
			hero["color_b"] = float(h.get("color_b", 0.20))

# ── Спорядження: хелпери ─────────────────────────────────────────────────

# Видаляє з equipped всі записи що посилаються на невалідні або відсутні предмети
func _validate_equipped() -> void:
	var bad_chars: Array = []
	for char_key in equipped:
		var char_equip = equipped[char_key]
		if not char_equip is Dictionary:
			bad_chars.append(char_key); continue
		var d := char_equip as Dictionary
		var bad_slots: Array = []
		for slot in d:
			var idx := int(d[slot])
			if idx < 0 or idx >= inventory.size() or not inventory[idx] is Dictionary:
				bad_slots.append(slot)
		for slot in bad_slots:
			d.erase(slot)
		if d.is_empty():
			bad_chars.append(char_key)
	for key in bad_chars:
		equipped.erase(key)

# Перевіряє чи предмет може бути надітий у даний слот (кільця взаємозамінні)
func item_fits_slot(item: Dictionary, target_slot: String) -> bool:
	var isl: String = item.get("slot", "") as String
	if isl == target_slot:
		return true
	if isl == "ring" and RING_SLOTS.has(target_slot):
		return true
	return false

# Повертає предмет у слоті або {} якщо порожньо
func get_equipped_item(char_key: String, slot: String) -> Dictionary:
	if not equipped.has(char_key):
		return {}
	var char_equip = equipped[char_key]
	if not char_equip is Dictionary:
		return {}
	var d: Dictionary = char_equip as Dictionary
	if not d.has(slot):
		return {}
	var idx: int = int(d[slot])
	if idx < 0 or idx >= inventory.size():
		return {}
	var item = inventory[idx]
	return item if item is Dictionary else {}

# Сумарна броня персонажа (усі слоти)
func get_char_armor(char_key: String) -> int:
	var total := 0
	for slot in EQUIP_SLOTS:
		var item := get_equipped_item(char_key, slot)
		if not item.is_empty() and item.has("armor"):
			total += int(item["armor"])
	return total

# Бонус до атаки від зброї в основній руці
func get_char_dmg_bonus(char_key: String) -> int:
	var item := get_equipped_item(char_key, "main_hand")
	if not item.is_empty() and item.has("dmg_bonus"):
		return int(item["dmg_bonus"])
	return 0

# Дистанція атаки: зброя перевизначає базову (якщо atk_range > 0)
func get_char_atk_range(char_key: String, base_range: int) -> int:
	var item := get_equipped_item(char_key, "main_hand")
	if not item.is_empty() and int(item.get("atk_range", 0)) > 0:
		return int(item["atk_range"])
	return base_range

# Сумарний бонус ініціативи від спорядження (чоботи, пояс тощо)
func get_char_initiative_bonus(char_key: String) -> int:
	var total := 0
	for slot in EQUIP_SLOTS:
		var item := get_equipped_item(char_key, slot)
		if not item.is_empty() and item.has("initiative_bonus"):
			total += int(item["initiative_bonus"])
	return total

# Сумарний бонус HP від спорядження (амулети, кільця тощо)
func get_char_hp_bonus(char_key: String) -> int:
	var total := 0
	for slot in EQUIP_SLOTS:
		var item := get_equipped_item(char_key, slot)
		if not item.is_empty() and item.has("hp_bonus"):
			total += int(item["hp_bonus"])
	return total

# Початковий фіз. бар'єр (від щитів та схожих предметів)
func get_char_simple_barrier(char_key: String) -> int:
	var total := 0
	for slot in EQUIP_SLOTS:
		var item := get_equipped_item(char_key, slot)
		if not item.is_empty() and item.has("simple_barrier"):
			total += int(item["simple_barrier"])
	return total

# Початковий маг. бар'єр (від магічних предметів)
func get_char_magic_barrier(char_key: String) -> int:
	var total := 0
	for slot in EQUIP_SLOTS:
		var item := get_equipped_item(char_key, slot)
		if not item.is_empty() and item.has("magic_barrier"):
			total += int(item["magic_barrier"])
	return total

# ── Рівні: хелпери ───────────────────────────────────────────────────────

# Ліниво ініціалізує запис прогресу компаньйона
func _ensure_companion_progress(uid: int) -> void:
	var ckey := "c%d" % uid
	if companion_progress.has(ckey):
		return
	if uid >= COMPANIONS.size():
		return
	var c: Dictionary = COMPANIONS[uid]
	companion_progress[ckey] = {
		"level": 1, "xp": 0, "skill_points": 0,
		"hp":    int(c["hp"]),
		"dmg":   int(c["dmg"]),
	}

func get_companion_hp(uid: int) -> int:
	_ensure_companion_progress(uid)
	return int((companion_progress["c%d" % uid] as Dictionary).get("hp", 30))

func get_companion_dmg(uid: int) -> int:
	_ensure_companion_progress(uid)
	return int((companion_progress["c%d" % uid] as Dictionary).get("dmg", 8))

func get_companion_level(uid: int) -> int:
	_ensure_companion_progress(uid)
	return int((companion_progress["c%d" % uid] as Dictionary).get("level", 1))

func get_hero_level() -> int:
	return int(hero.get("level", 1))

# Нараховує XP всім учасникам загону; повертає рядки про підвищення рівня
func award_xp(amount: int) -> Array[String]:
	var msgs: Array[String] = []
	if not hero.is_empty():
		hero["xp"] = int(hero.get("xp", 0)) + amount
		var msg := _check_levelup_hero()
		if msg != "":
			msgs.append(msg)
	for uid in raid_party:
		_ensure_companion_progress(uid)
		var cp: Dictionary = companion_progress["c%d" % uid] as Dictionary
		cp["xp"] = int(cp.get("xp", 0)) + amount
		var msg := _check_levelup_companion(uid)
		if msg != "":
			msgs.append(msg)
	save_game()
	return msgs

func _check_levelup_hero() -> String:
	var last_msg := ""
	for _i in MAX_LEVEL:
		var lvl: int = int(hero.get("level", 1))
		if lvl >= MAX_LEVEL or int(hero.get("xp", 0)) < LEVEL_XP[lvl]:
			break
		hero["level"] = lvl + 1
		var new_lvl: int = lvl + 1
		var hname: String = str(hero.get("name", "Герой"))
		pending_levelups["hero"] = {"name": hname, "new_level": new_lvl}
		last_msg = "★ %s → Рівень %d!" % [hname, new_lvl]
	return last_msg

func _check_levelup_companion(uid: int) -> String:
	var cp: Dictionary = companion_progress["c%d" % uid] as Dictionary
	var last_msg := ""
	for _i in MAX_LEVEL:
		var lvl: int = int(cp.get("level", 1))
		if lvl >= MAX_LEVEL or int(cp.get("xp", 0)) < LEVEL_XP[lvl]:
			break
		cp["level"] = lvl + 1
		var new_lvl: int = lvl + 1
		var cname: String = COMPANIONS[uid]["name"] as String
		pending_levelups["c%d" % uid] = {"name": cname, "new_level": new_lvl}
		last_msg = "★ %s → Рівень %d!" % [cname, new_lvl]
	return last_msg

## Застосувати вибір гравця при левелапі.
## choice_id: 0=+12HP  1=+2Атк  2=+1Очко навичок
func apply_levelup_choice(char_key: String, choice_id: int) -> void:
	match char_key:
		"hero":
			match choice_id:
				0: hero["hp"]  = int(hero.get("hp",  50)) + 12
				1: hero["dmg"] = int(hero.get("dmg", 12)) + 2
				2: hero["skill_points"] = int(hero.get("skill_points", 0)) + 1
		_:
			var uid: int = int(char_key.substr(1))
			_ensure_companion_progress(uid)
			var cp: Dictionary = companion_progress[char_key] as Dictionary
			match choice_id:
				0: cp["hp"]  = int(cp.get("hp",  30)) + 12
				1: cp["dmg"] = int(cp.get("dmg",  8)) + 2
				2: cp["skill_points"] = int(cp.get("skill_points", 0)) + 1
	pending_levelups.erase(char_key)
	save_game()

## Повертає список char_key що чекають на вибір левелапу.
func get_pending_levelup_keys() -> Array[String]:
	var result: Array[String] = []
	for k in pending_levelups:
		result.append(str(k))
	return result

## Повертає очки навичок персонажа.
func get_skill_points(char_key: String) -> int:
	if char_key == "hero":
		return int(hero.get("skill_points", 0))
	var uid: int = int(char_key.substr(1))
	_ensure_companion_progress(uid)
	return int((companion_progress[char_key] as Dictionary).get("skill_points", 0))

# Надіти предмет (ind_idx — індекс в inventory)
func equip_item(char_key: String, slot: String, inv_idx: int) -> void:
	if not equipped.has(char_key):
		equipped[char_key] = {}
	var d: Dictionary = equipped[char_key] as Dictionary
	d[slot] = inv_idx
	# Двуручна зброя займає обидві руки
	if slot == "main_hand" and inv_idx >= 0 and inv_idx < inventory.size():
		var item = inventory[inv_idx]
		if item is Dictionary and (item as Dictionary).get("two_handed", false):
			d["off_hand"] = inv_idx
	save_game()

# Зняти предмет зі слоту
func unequip_item(char_key: String, slot: String) -> void:
	if not equipped.has(char_key):
		return
	var d: Dictionary = equipped[char_key] as Dictionary
	# Двуручна зброя: знімаємо з обох рук
	if slot == "main_hand" and d.has("main_hand"):
		var idx: int = int(d.get("main_hand", -1))
		if idx >= 0 and idx < inventory.size():
			var item = inventory[idx]
			if item is Dictionary and (item as Dictionary).get("two_handed", false):
				d.erase("off_hand")
	d.erase(slot)
	save_game()

# Дає герою стартовий набір спорядження відповідно до обраного класу.
# Предмети слабші ніж аналоги з Кузні — Кузня відкриває повний асортимент.
func give_starter_items(class_idx: int, char_key: String = "hero") -> void:
	# Не давати двічі — якщо персонаж вже має хоч один надітий предмет
	if equipped.has(char_key):
		var d: Dictionary = equipped[char_key] as Dictionary
		if not d.is_empty():
			return
	# Список: [{slot, ...item fields}]
	var items: Array[Dictionary] = []
	match class_idx:
		0:  # Клірик — захист + булава + тарч
			items = [
				{"name": "Посилена сорочка",  "slot": "chest",     "armor_type": ARMOR_CHAINMAIL, "armor": 10},
				{"name": "Скромна булава",    "slot": "main_hand", "dmg_bonus": 4},
				{"name": "Вербова тарч",      "slot": "off_hand",  "armor": 3, "simple_barrier": 6},
			]
		1:  # Паладін — важка броня + меч + щит
			items = [
				{"name": "Іржавий нагрудник", "slot": "chest",     "armor_type": ARMOR_PLATE, "armor": 14},
				{"name": "Давній меч",         "slot": "main_hand", "dmg_bonus": 4},
				{"name": "Фамільний щит",      "slot": "off_hand",  "armor": 6, "simple_barrier": 12},
			]
		2:  # Воїн — кільчуга + меч
			items = [
				{"name": "Кільчаста сорочка", "slot": "chest",     "armor_type": ARMOR_CHAINMAIL, "armor": 12},
				{"name": "Бойовий меч",        "slot": "main_hand", "dmg_bonus": 5},
			]
		3:  # Злодій — легка броня + два кинджали
			items = [
				{"name": "Злодійська куртка",  "slot": "chest",     "armor_type": ARMOR_LEATHER, "armor": 6, "agility_bonus": 2},
				{"name": "Отруйний кинджал",   "slot": "main_hand", "dmg_bonus": 4, "critical_bonus": 10},
				{"name": "Другий кинджал",     "slot": "off_hand",  "dmg_bonus": 2, "critical_bonus": 5},
			]
		4:  # Маг — мантія + посох (двуручний)
			items = [
				{"name": "Учнівська мантія",  "slot": "chest",     "armor_type": ARMOR_CLOTH, "armor": 3, "magic_bonus": 10},
				{"name": "Дубовий посох",      "slot": "main_hand", "dmg_bonus": 3, "atk_range": 2, "two_handed": true, "magic_bonus": 12},
			]
		5:  # Мисливець — куртка + лук + колчан
			items = [
				{"name": "Шкіряна куртка",    "slot": "chest",     "armor_type": ARMOR_LEATHER, "armor": 7},
				{"name": "Простий лук",       "slot": "main_hand", "dmg_bonus": 4, "atk_range": 2, "requires_quiver": true},
				{"name": "Колчан стріл",      "slot": "off_hand",  "is_quiver": true},
			]
		6:  # Оккультист — темна мантія + кинджал + магічна сфера
			items = [
				{"name": "Темна мантія",       "slot": "chest",     "armor_type": ARMOR_CLOTH, "armor": 3, "magic_bonus": 8},
				{"name": "Оккультний кинджал", "slot": "main_hand", "dmg_bonus": 4},
				{"name": "Сфера тіней",        "slot": "off_hand",  "magic_bonus": 10, "magic_barrier": 6},
			]
		7:  # Бард — куртка + легкий меч + мандрівні чоботи
			items = [
				{"name": "Мандрівна куртка",  "slot": "chest",     "armor_type": ARMOR_LEATHER, "armor": 5},
				{"name": "Легкий меч",         "slot": "main_hand", "dmg_bonus": 3},
				{"name": "Мандрівні чоботи",  "slot": "boots",     "armor_type": ARMOR_LEATHER, "armor": 3, "initiative_bonus": 2},
			]
	# Ініціалізуємо прогрес компаньйона якщо потрібно
	if char_key != "hero":
		var uid: int = int(char_key.substr(1))
		_ensure_companion_progress(uid)
	for item in items:
		var idx := inventory.size()
		inventory.append(item)
		equip_item(char_key, item.get("slot", "") as String, idx)

# Додає базовий набір предметів від Кузні (викликається при побудові Кузні)
# Структура предмету: name, slot, armor_type(-1=not armor), armor, dmg_bonus,
#   atk_range(0=no override), initiative_bonus, hp_bonus, two_handed,
#   simple_barrier(щит→фіз.бар.), magic_barrier, requires_quiver, is_quiver,
#   critical_bonus, magic_bonus, agility_bonus

# ── Трофеї ────────────────────────────────────────────────────────────────
func add_loot(item_id: int, qty: int = 1) -> void:
	var key := str(item_id)
	loot_bag[key] = int(loot_bag.get(key, 0)) + qty

# Видає рандомні трофеї і повертає рядок-опис для логу.
# is_combat=true → вищий шанс рідкостей
func award_expedition_loot(is_combat: bool) -> String:
	var parts: Array[String] = []
	# Завжди 1-2 звичайні (id 0-1)
	var c_id  := randi() % 2
	var c_qty := 1 + randi() % 2
	add_loot(c_id, c_qty)
	var cname: String = EXPEDITION_LOOT[c_id]["name"] as String
	parts.append(cname + ("×%d" % c_qty if c_qty > 1 else ""))
	# 40% (бій: 55%) шанс рідкісного (id 2-4)
	if randf() < (0.55 if is_combat else 0.40):
		var r_id := 2 + randi() % 3
		add_loot(r_id)
		parts.append(EXPEDITION_LOOT[r_id]["name"] as String)
	# 10% (бій: 15%) шанс дуже рідкісного (id 5-7)
	if randf() < (0.15 if is_combat else 0.10):
		var vr_id := 5 + randi() % 3
		add_loot(vr_id)
		parts.append("★ " + (EXPEDITION_LOOT[vr_id]["name"] as String))
	save_game()
	return "  ".join(parts)

func can_afford_action(bid: int, action_idx: int) -> bool:
	if not BUILDING_ACTIONS.has(bid): return false
	var acts: Array = BUILDING_ACTIONS[bid] as Array
	if action_idx >= acts.size(): return false
	var act: Dictionary = acts[action_idx] as Dictionary
	var cost: Dictionary = act.get("cost", {}) as Dictionary
	for k in cost:
		if int(resources.get(k, 0)) < int(cost[k]): return false
	var lc: Dictionary = act.get("loot_cost", {}) as Dictionary
	for id_key in lc:
		if int(loot_bag.get(str(id_key), 0)) < int(lc[id_key]): return false
	return true

# Виконати дію будівлі. Повертає {"success": bool, "msg": String}
func execute_building_action(bid: int, action_idx: int) -> Dictionary:
	if not can_afford_action(bid, action_idx):
		return {"success": false, "msg": "Не вистачає ресурсів або трофеїв"}
	var acts: Array    = BUILDING_ACTIONS[bid] as Array
	var act: Dictionary = acts[action_idx] as Dictionary
	# Списуємо ресурси
	var cost: Dictionary = act.get("cost", {}) as Dictionary
	for k in cost: resources[k] = int(resources.get(k, 0)) - int(cost[k])
	# Списуємо трофеї
	var lc: Dictionary = act.get("loot_cost", {}) as Dictionary
	for id_key in lc:
		var sk := str(id_key)
		loot_bag[sk] = int(loot_bag.get(sk, 0)) - int(lc[id_key])
		if int(loot_bag[sk]) <= 0: loot_bag.erase(sk)
	# Виконуємо ефект
	var effect: String     = act.get("effect", "") as String
	var edata: Dictionary  = act.get("effect_data", {}) as Dictionary
	var msg: String        = act.get("label", "Виконано") as String
	match effect:
		"craft_item":
			var item := edata.duplicate()
			inventory.append(item)
			msg = "Створено: " + (item.get("name", "?") as String)
		"award_party_xp":
			var xp: int  = int(edata.get("xp", 0))
			var leveled  := award_xp(xp)
			msg = "Загін отримав +%d XP" % xp
			if not leveled.is_empty(): msg += "  ★  " + "  ★  ".join(leveled)
		"award_resources":
			for rk in edata: resources[rk] = int(resources.get(rk, 0)) + int(edata[rk])
			msg = "Отримано ресурси"
		"award_loot_random":
			var ls := award_expedition_loot(false)
			msg = "Знайдено: " + ls
		"award_hunt":
			var food_gain: int = int(edata.get("food", 15))
			resources["food"] = int(resources.get("food", 0)) + food_gain
			msg = "Полювання! Їжа+%d" % food_gain
			if randf() < 0.6:
				msg += "  " + award_expedition_loot(false)
		"gossip":
			msg = GOSSIP_TEXTS[randi() % GOSSIP_TEXTS.size()] as String
	save_game()
	return {"success": true, "msg": msg}

# ── Генерація карти ───────────────────────────────────────────────────────
func _generate_tutorial_map() -> void:
	# Простий лінійний шлях: START → COMBAT (1 гоблін) → END
	regional_nodes = [
		{"id": 0, "type": NodeType.START,  "layer": 0, "slot": 0, "max_slots": 1, "total_layers": 3},
		{"id": 1, "type": NodeType.COMBAT, "layer": 1, "slot": 0, "max_slots": 1, "total_layers": 3},
		{"id": 2, "type": NodeType.END,    "layer": 2, "slot": 0, "max_slots": 1, "total_layers": 3},
	]
	regional_edges = [[0, 1], [1, 2]]

func _generate_map() -> void:
	regional_nodes = []
	regional_edges = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Шар 0: START (1 вузол)
	# Шар 1: ЗАВЖДИ 2 вузли — гарантований форк (ліва і права гілка)
	# Шари 2..N-2: 1-2 вузли на кожній гілці
	# Шар N-1: END (1 вузол)
	var layer_sizes: Array[int] = [1, 2]
	var mid_layers := rng.randi_range(1, 2)
	for _i in mid_layers:
		layer_sizes.append(rng.randi_range(1, 2))
	layer_sizes.append(1)
	var total_layers := layer_sizes.size()

	var node_id := 0
	var layers_nodes: Array = []
	for layer in total_layers:
		var count := layer_sizes[layer]
		var ids: Array[int] = []
		for slot in count:
			var ntype: int
			if layer == 0:
				ntype = NodeType.START
			elif layer == total_layers - 1:
				ntype = NodeType.END
			else:
				# Ліва гілка (slot 0) — трохи більше LOOT (безпечніша)
				# Права гілка (slot 1) — трохи більше COMBAT (ризикованіша)
				var combat_chance := 0.45 if slot == 0 else 0.80
				ntype = NodeType.COMBAT if rng.randf() < combat_chance else NodeType.LOOT
			regional_nodes.append({
				"id": node_id, "type": ntype,
				"layer": layer, "slot": slot, "max_slots": count,
				"total_layers": total_layers
			})
			ids.append(node_id)
			node_id += 1
		layers_nodes.append(ids)

	# З'єднуємо шари
	for layer in range(total_layers - 1):
		var froms: Array[int] = layers_nodes[layer]
		var tos:   Array[int] = layers_nodes[layer + 1]

		# Кожен TO отримує хоча б одне вхідне ребро
		var tos_shuffled := tos.duplicate()
		tos_shuffled.shuffle()
		for i in tos_shuffled.size():
			var f: int = froms[i % froms.size()]
			var t: int = tos_shuffled[i]
			if not regional_edges.has([f, t]):
				regional_edges.append([f, t])

		# Кожен FROM має хоча б одне вихідне ребро
		for f in froms:
			var has_out := false
			for edge in regional_edges:
				if (edge as Array)[0] == f:
					has_out = true; break
			if not has_out:
				var t: int = tos[rng.randi() % tos.size()]
				regional_edges.append([f, t])

		# Невеликий шанс перехресного зв'язку між гілками (20%)
		if tos.size() > 1:
			for f in froms:
				if rng.randf() < 0.20:
					var t: int = tos[rng.randi() % tos.size()]
					if not regional_edges.has([f, t]):
						regional_edges.append([f, t])
