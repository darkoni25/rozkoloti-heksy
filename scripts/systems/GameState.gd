extends Node

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
const LEVEL_HP_BONUS:  int = 5   # +HP за кожен рівень
const LEVEL_DMG_BONUS: int = 1   # +ATK за кожен рівень

var hero_created:         bool        = false
var hero_recovery_raids:  int         = 0   # >0 → герой пропускає рейд
var tutorial_done:        bool        = false
var raid_party:           Array[int]  = []
var explored_directions:  Array[int]  = []
var current_direction:    int         = -1

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
var smithy_items_given:   bool       = false   # Кузня вже наповнила інвентар
# Прогрес компаньйонів: ключ = "c{uid}", значення = {level, xp, hp, dmg}
var companion_progress:   Dictionary = {}

# Регіональна карта
var regional_nodes:   Array = []
var regional_edges:   Array = []
var regional_current: int   = 0
var regional_visited: Array[int] = []
var in_regional_map:  bool  = false

enum NodeType { START, COMBAT, LOOT, END }

func _ready() -> void:
	_init_state()
	load_game()

func _init_state() -> void:
	resources  = {"wood": 0, "stone": 0, "metal": 0, "food": 0}
	base_slots = [-1, -1, -1, -1, -1, -1, -1, -1, -1]
	hero                 = {}
	hero_created         = false
	hero_recovery_raids  = 0
	tutorial_done        = false
	raid_party           = []
	explored_directions  = []
	current_direction    = -1
	population           = 0
	pending_population   = 0
	workers              = {"wood": 0, "stone": 0, "metal": 0, "food": 0}
	gold                 = 0
	inventory            = []
	equipped             = {}
	smithy_items_given   = false
	companion_progress   = {}

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
	in_regional_map = false
	process_cycle()

# Викликається кожного разу при поверненні на базу після вилазки
func process_cycle() -> void:
	# 1. Нові люди прибувають
	population        += pending_population
	pending_population = 0

	# 2. Робітники виробляють ресурси
	for key in WORKER_PRODUCTIVITY:
		var w: int = workers.get(key, 0)
		resources[key] += w * int(WORKER_PRODUCTIVITY[key])

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

# ── Збереження ────────────────────────────────────────────────────────────
func save_game() -> void:
	var data: Dictionary = {
		"resources":           resources,
		"base_slots":          Array(base_slots),
		"raid_party":          Array(raid_party),
		"explored_directions": Array(explored_directions),
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
		"smithy_items_given":  smithy_items_given,
		"companion_progress":  companion_progress,
	}
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return
	var file := FileAccess.open("user://save.json", FileAccess.READ)
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
	if data.has("smithy_items_given"):
		smithy_items_given = bool(data["smithy_items_given"])
	if data.has("companion_progress") and data["companion_progress"] is Dictionary:
		companion_progress = data["companion_progress"] as Dictionary
	if data.has("workers") and data["workers"] is Dictionary:
		var w = data["workers"]
		for key in ["wood", "stone", "metal", "food"]:
			workers[key] = int(w.get(key, 0))
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
		"level": 1, "xp": 0,
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
		hero["hp"]    = int(hero.get("hp",  50)) + LEVEL_HP_BONUS
		hero["dmg"]   = int(hero.get("dmg", 12)) + LEVEL_DMG_BONUS
		last_msg = "%s → Рівень %d!" % [str(hero.get("name", "Герой")), lvl + 1]
	return last_msg

func _check_levelup_companion(uid: int) -> String:
	var cp: Dictionary = companion_progress["c%d" % uid] as Dictionary
	var last_msg := ""
	for _i in MAX_LEVEL:
		var lvl: int = int(cp.get("level", 1))
		if lvl >= MAX_LEVEL or int(cp.get("xp", 0)) < LEVEL_XP[lvl]:
			break
		cp["level"] = lvl + 1
		cp["hp"]    = int(cp.get("hp",  30)) + LEVEL_HP_BONUS
		cp["dmg"]   = int(cp.get("dmg",  8)) + LEVEL_DMG_BONUS
		last_msg = "%s → Рівень %d!" % [COMPANIONS[uid]["name"] as String, lvl + 1]
	return last_msg

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
func give_smithy_items() -> void:
	if smithy_items_given:
		return  # Вже видані
	smithy_items_given = true
	# ── Зброя (main_hand) ────────────────────────────────────────────────
	inventory.append({"name": "Короткий меч",  "slot": "main_hand", "dmg_bonus": 5,  "atk_range": 1})
	inventory.append({"name": "Кинджал",        "slot": "main_hand", "dmg_bonus": 3,  "atk_range": 1, "critical_bonus": 8})
	inventory.append({"name": "Булава",          "slot": "main_hand", "dmg_bonus": 7,  "atk_range": 1})
	inventory.append({"name": "Лук",             "slot": "main_hand", "dmg_bonus": 5,  "atk_range": 3, "requires_quiver": true})
	inventory.append({"name": "Посох",           "slot": "main_hand", "dmg_bonus": 4,  "atk_range": 2, "two_handed": true, "magic_bonus": 15})
	# ── Off hand ─────────────────────────────────────────────────────────
	inventory.append({"name": "Дерев'яний щит", "slot": "off_hand",  "armor": 5,  "simple_barrier": 10})
	inventory.append({"name": "Залізний щит",   "slot": "off_hand",  "armor": 8,  "simple_barrier": 16})
	inventory.append({"name": "Колчан стріл",   "slot": "off_hand",  "is_quiver": true})
	inventory.append({"name": "Магічна сфера",  "slot": "off_hand",  "magic_bonus": 12, "magic_barrier": 8})
	inventory.append({"name": "Кинджал (доп.)", "slot": "off_hand",  "dmg_bonus": 3, "critical_bonus": 8})
	# ── Шолом ────────────────────────────────────────────────────────────
	inventory.append({"name": "Тканинний каптур",  "slot": "helmet", "armor_type": 0, "armor": 2,  "magic_bonus": 8})
	inventory.append({"name": "Шкіряний шолом",    "slot": "helmet", "armor_type": 1, "armor": 6})
	inventory.append({"name": "Кольчужний шолом",  "slot": "helmet", "armor_type": 2, "armor": 10, "hp_bonus": 5})
	# ── Шия ──────────────────────────────────────────────────────────────
	inventory.append({"name": "Амулет витривалості", "slot": "neck", "hp_bonus": 10})
	inventory.append({"name": "Срібний медальйон",   "slot": "neck", "initiative_bonus": 2, "magic_bonus": 5})
	# ── Тіло ─────────────────────────────────────────────────────────────
	inventory.append({"name": "Тканинна мантія",  "slot": "chest", "armor_type": 0, "armor": 4,  "magic_bonus": 12})
	inventory.append({"name": "Шкіряна броня",    "slot": "chest", "armor_type": 1, "armor": 10, "agility_bonus": 3})
	inventory.append({"name": "Кольчуга",          "slot": "chest", "armor_type": 2, "armor": 16, "hp_bonus": 10})
	inventory.append({"name": "Латний панцир",     "slot": "chest", "armor_type": 3, "armor": 22, "hp_bonus": 15})
	# ── Наручі ───────────────────────────────────────────────────────────
	inventory.append({"name": "Тканинні рукавиці", "slot": "gloves", "armor_type": 0, "armor": 2, "magic_bonus": 4})
	inventory.append({"name": "Шкіряні наручі",    "slot": "gloves", "armor_type": 1, "armor": 4, "agility_bonus": 2})
	inventory.append({"name": "Кольчужні рукавиці","slot": "gloves", "armor_type": 2, "armor": 7, "hp_bonus": 3})
	# ── Пояс ─────────────────────────────────────────────────────────────
	inventory.append({"name": "Шкіряний пояс",   "slot": "belt", "armor_type": 1, "armor": 3, "hp_bonus": 8})
	inventory.append({"name": "Кольчужний пояс", "slot": "belt", "armor_type": 2, "armor": 5, "hp_bonus": 12})
	# ── Поножі ───────────────────────────────────────────────────────────
	inventory.append({"name": "Тканинні штани",   "slot": "legs", "armor_type": 0, "armor": 3,  "magic_bonus": 5})
	inventory.append({"name": "Шкіряні поножі",   "slot": "legs", "armor_type": 1, "armor": 8,  "agility_bonus": 2})
	inventory.append({"name": "Кольчужні поножі", "slot": "legs", "armor_type": 2, "armor": 12, "hp_bonus": 8})
	# ── Чоботи ───────────────────────────────────────────────────────────
	inventory.append({"name": "Тканинні сандалі", "slot": "boots", "armor_type": 0, "armor": 2, "initiative_bonus": 2})
	inventory.append({"name": "Шкіряні чоботи",   "slot": "boots", "armor_type": 1, "armor": 5, "initiative_bonus": 3})
	inventory.append({"name": "Кольчужні чоботи", "slot": "boots", "armor_type": 2, "armor": 9, "initiative_bonus": 1})
	# ── Кільця (slot="ring" — підходить у ring1 і ring2) ─────────────────
	inventory.append({"name": "Кільце сили",       "slot": "ring", "hp_bonus": 8})
	inventory.append({"name": "Кільце сили",       "slot": "ring", "hp_bonus": 8})
	inventory.append({"name": "Кільце спритності", "slot": "ring", "agility_bonus": 3, "initiative_bonus": 1})
	inventory.append({"name": "Кільце спритності", "slot": "ring", "agility_bonus": 3, "initiative_bonus": 1})
	inventory.append({"name": "Магічне кільце",    "slot": "ring", "magic_bonus": 10})
	inventory.append({"name": "Магічне кільце",    "slot": "ring", "magic_bonus": 10})
	save_game()

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

	var mid_layers := rng.randi_range(3, 4)
	var layer_sizes: Array[int] = [1]
	for _i in mid_layers:
		layer_sizes.append(rng.randi_range(1, 3))
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
				ntype = NodeType.COMBAT if rng.randf() < 0.70 else NodeType.LOOT
			regional_nodes.append({
				"id": node_id, "type": ntype,
				"layer": layer, "slot": slot, "max_slots": count,
				"total_layers": total_layers
			})
			ids.append(node_id)
			node_id += 1
		layers_nodes.append(ids)

	for layer in range(total_layers - 1):
		var froms: Array[int] = layers_nodes[layer]
		var tos:   Array[int] = layers_nodes[layer + 1]

		var tos_shuffled := tos.duplicate()
		tos_shuffled.shuffle()
		for i in tos_shuffled.size():
			var f: int = froms[i % froms.size()]
			var t: int = tos_shuffled[i]
			if not regional_edges.has([f, t]):
				regional_edges.append([f, t])

		for f in froms:
			var has_out := false
			for edge in regional_edges:
				if (edge as Array)[0] == f:
					has_out = true; break
			if not has_out:
				var t: int = tos[rng.randi() % tos.size()]
				regional_edges.append([f, t])

		for f in froms:
			if rng.randf() < 0.35 and tos.size() > 1:
				var t: int = tos[rng.randi() % tos.size()]
				if not regional_edges.has([f, t]):
					regional_edges.append([f, t])
