class_name AbilityDatabase
## Реєстр усіх навичок гри.
## Збирає дані з файлів класів та архетипів.
## Не виконує ефекти — тільки зберігає й повертає дані.
##
## Щоб підключити новий клас або архетип:
##   1. Створи файл у scripts/systems/classes/  (або archetypes/)
##   2. Додай виклик .merge() у _all_data() нижче
##   3. Додай ability_id у CLASS_TO_ABILITY (якщо це базовий клас)

# ── Прив'язка класу до першої навички ────────────────────────────────────────
## class_idx 0-7 → ability_id першої активної навички.
## 0=Клірик 1=Паладін 2=Воїн 3=Злодій 4=Маг 5=Мисл. 6=Окк. 7=Бард
const CLASS_TO_ABILITY: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]

# ── Внутрішній збір даних ─────────────────────────────────────────────────────
## Збирає словники з усіх зареєстрованих джерел.
## Ключ = ability_id (int), значення = Dictionary з даними навички.
static func _all_data() -> Dictionary:
	var d: Dictionary = {}
	# ── Базові класи ──
	d.merge(ClericAbilities.get_data())
	d.merge(PaladinAbilities.get_data())
	d.merge(WarriorAbilities.get_data())
	d.merge(RogueAbilities.get_data())
	d.merge(MageAbilities.get_data())
	d.merge(HunterAbilities.get_data())
	d.merge(OccultistAbilities.get_data())
	d.merge(BardAbilities.get_data())
	# ── Архетипи (додавати сюди пізніше) ──
	# d.merge(RuneKnightAbilities.get_data())
	return d

# ── Публічний API ─────────────────────────────────────────────────────────────

## Повернути дані однієї навички за id.
## Повертає порожній dict {} якщо навичку не знайдено.
static func get_ability(id: int) -> Dictionary:
	return _all_data().get(id, {}) as Dictionary

## Повернути список ability_id для базового класу (class_idx 0-7).
static func get_ids_for_class(class_idx: int) -> Array[int]:
	if class_idx < 0 or class_idx >= CLASS_TO_ABILITY.size():
		return []
	return [CLASS_TO_ABILITY[class_idx]]
