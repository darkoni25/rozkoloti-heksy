class_name AbilitySystem
## Головний вхід у систему навичок для CombatScene.
## Делегує дані → AbilityDatabase, ефекти → AbilityEffects.
##
## ══ Як додати нову навичку ══════════════════════════════════════════════════
##
##  Якщо навичка складається з ІСНУЮЧИХ ефектів (DAMAGE, HEAL, SELF_HEAL тощо):
##    1. Відкрий файл класу у scripts/systems/classes/  (або створи новий)
##    2. Додай новий ability_id у get_data() з полями name/desc/cd/mode/range/effects
##    3. Додай цей id у get_ids()
##    4. У AbilityDatabase._all_data() — переконайся що файл вже підключений
##    5. Якщо новий базовий клас — оновити CLASS_TO_ABILITY у AbilityDatabase
##    Більше нічого чіпати НЕ ТРЕБА.
##
##  Якщо навичка потребує НОВОЇ механіки (отрута, щит, телепорт…):
##    1. Новий рядок в AbilityEnums.EffectType
##    2. Новий match-case у AbilityEffects.apply()
##    3. Нова функція _do_*() у AbilityEffects
##    4. Після цього — дивись вище (кроки 1-5)
##
## ════════════════════════════════════════════════════════════════════════════

# ── Метадані ─────────────────────────────────────────────────────────────────

static func get_ability_name(id: int) -> String:
	return str(AbilityDatabase.get_ability(id).get("name", ""))

static func get_cd(id: int) -> int:
	return int(AbilityDatabase.get_ability(id).get("cd", 0))

## true якщо здібність не потребує вибору цілі (SELF mode).
static func is_instant(id: int) -> bool:
	var d := AbilityDatabase.get_ability(id)
	if d.is_empty(): return true
	return int(d.get("mode", AbilityEnums.TargetMode.SELF)) == AbilityEnums.TargetMode.SELF

## Прив'язати першу навичку класу до юніта.
static func setup_unit(unit: Unit, class_idx: int) -> void:
	var ids := AbilityDatabase.get_ids_for_class(class_idx)
	if ids.is_empty(): return
	var ab_id          := ids[0]
	unit.ability_id     = ab_id
	unit.ability_cd_max = get_cd(ab_id)
	unit.ability_cd     = 0

# ── Таргетинг ─────────────────────────────────────────────────────────────────

## Повертає гекси, доступні як цілі здібності actor'а.
## Для SELF mode повертає порожній масив (цілі не потрібні).
static func get_targets(id: int, actor: Unit,
		hex_unit: Dictionary, units: Array[Unit], hexes: Dictionary) -> Array[Vector2i]:
	var d := AbilityDatabase.get_ability(id)
	if d.is_empty(): return []
	var mode := int(d.get("mode", AbilityEnums.TargetMode.SELF))
	var rng  := int(d.get("range", 1))
	if mode == AbilityEnums.TargetMode.SELF: return []

	var result: Array[Vector2i] = []
	for hex in hexes:
		if HexGrid.distance(actor.hex, hex) > rng: continue
		var uid: int = hex_unit.get(hex, -1)
		match mode:
			AbilityEnums.TargetMode.ALLY_NEAR:
				if uid != -1 and units[uid].team == actor.team and units[uid].id != actor.id:
					result.append(hex)
			AbilityEnums.TargetMode.ENEMY_NEAR:
				if uid != -1 and units[uid].team != actor.team:
					result.append(hex)
			AbilityEnums.TargetMode.ANY_HEX:
				result.append(hex)
			AbilityEnums.TargetMode.EMPTY_HEX:
				if uid == -1:
					result.append(hex)
			AbilityEnums.TargetMode.ALLY_OR_SELF:
				if uid != -1 and units[uid].team == actor.team:
					result.append(hex)
	return result

# ── Виконання ─────────────────────────────────────────────────────────────────

## Виконати здібність. Повертає рядок для combat_log.
## kill_fn: Callable(unit: Unit) — видалити юніта з поля бою.
static func execute(id: int, actor: Unit, target_hex: Vector2i,
		units: Array[Unit], hex_unit: Dictionary, hexes: Dictionary,
		kill_fn: Callable) -> String:
	var ability := AbilityDatabase.get_ability(id)
	if ability.is_empty(): return ""
	var effects: Array = ability.get("effects", []) as Array
	var parts: Array[String] = []
	for eff in effects:
		var part := AbilityEffects.apply(
			eff as Dictionary, actor, target_hex,
			units, hex_unit, hexes, kill_fn
		)
		if not part.is_empty():
			parts.append(part)
	var ability_name: String = str(ability.get("name", "Здібність"))
	return "✦ %s → %s: %s" % [
		actor.label,
		ability_name,
		", ".join(parts) if not parts.is_empty() else "без ефекту",
	]
