class_name AbilityEffects
## Виконавець готових ефектів здібностей.
## Не знає про класи, архетипи або конкретні навички.
## Знає тільки: як нанести урон, як лікувати, як AoE тощо.
##
## Щоб ДОДАТИ новий тип ефекту:
##   1. Новий рядок в AbilityEnums.EffectType
##   2. Новий match-case у apply()
##   3. Нова функція _do_*(...)

## Виконати один ефект. Повертає рядок-фрагмент для combat_log.
static func apply(effect: Dictionary, actor: Unit, target_hex: Vector2i,
		units: Array[Unit], hex_unit: Dictionary, hexes: Dictionary,
		kill_fn: Callable) -> String:
	var etype: int = int(effect.get("type", -1))
	match etype:
		AbilityEnums.EffectType.DAMAGE:
			return _do_damage(effect, actor, target_hex, units, hex_unit, kill_fn)
		AbilityEnums.EffectType.HEAL:
			return _do_heal(effect, target_hex, units, hex_unit)
		AbilityEnums.EffectType.SELF_HEAL:
			return _do_self_heal(effect, actor)
		AbilityEnums.EffectType.SELF_DAMAGE:
			return _do_self_damage(effect, actor, kill_fn)
		AbilityEnums.EffectType.AOE_DAMAGE:
			return _do_aoe_damage(effect, actor, target_hex, units, hex_unit, hexes, kill_fn)
		AbilityEnums.EffectType.AOE_HEAL:
			return _do_aoe_heal(effect, actor, units)
	return ""

# ── DAMAGE ────────────────────────────────────────────────────────────────────
## Поля ефекту:
##   power  int   Базовий урон. 0 = використати actor.damage.
##   mult   float Множник на базу (default 1.0).
##   bonus  int   Фіксований бонус після множника (default 0).
##   armor  bool  Застосувати формулу броні цілі (default true).
static func _do_damage(effect: Dictionary, actor: Unit, target_hex: Vector2i,
		units: Array[Unit], hex_unit: Dictionary, kill_fn: Callable) -> String:
	var uid_t: int = hex_unit.get(target_hex, -1)
	if uid_t == -1: return ""
	var t        := units[uid_t]
	var base     := int(effect.get("power", 0))
	if base == 0: base = actor.damage
	var mult     := float(effect.get("mult",  1.0))
	var bonus    := int(effect.get("bonus", 0))
	var raw      := maxi(1, int(round(float(base) * mult))) + bonus
	var use_arm  := bool(effect.get("armor", true))
	var dmg      := _armor_reduce(raw, t.char_key) if use_arm else raw
	t.take_damage(dmg)
	if not t.is_alive(): kill_fn.call(t)
	return "-%d HP (%s)" % [dmg, t.label]

# ── HEAL ──────────────────────────────────────────────────────────────────────
## Поля ефекту:
##   power  int   Кількість HP для відновлення.
static func _do_heal(effect: Dictionary, target_hex: Vector2i,
		units: Array[Unit], hex_unit: Dictionary) -> String:
	var uid_t: int = hex_unit.get(target_hex, -1)
	if uid_t == -1: return ""
	var t     := units[uid_t]
	var power := int(effect.get("power", 0))
	t.hp = mini(t.max_hp, t.hp + power)
	return "+%d HP (%s)" % [power, t.label]

# ── SELF_HEAL ─────────────────────────────────────────────────────────────────
## Поля ефекту:
##   power  int   Кількість HP для відновлення актору.
static func _do_self_heal(effect: Dictionary, actor: Unit) -> String:
	var power := int(effect.get("power", 0))
	actor.hp = mini(actor.max_hp, actor.hp + power)
	return "+%d HP (собі)" % power

# ── SELF_DAMAGE ───────────────────────────────────────────────────────────────
## Поля ефекту:
##   power  int   Урон актору (наприклад, жертва кров'ю).
static func _do_self_damage(effect: Dictionary, actor: Unit, kill_fn: Callable) -> String:
	var power := int(effect.get("power", 0))
	actor.take_damage(power)
	if not actor.is_alive(): kill_fn.call(actor)
	return "-%d HP (собі)" % power

# ── AOE_DAMAGE ────────────────────────────────────────────────────────────────
## Поля ефекту:
##   power          int   Урон (0 = actor.damage).
##   radius         int   Радіус від target_hex (default 1).
##   friendly_fire  bool  Бити також союзників (default false).
##   armor          bool  Застосувати броню (default false).
static func _do_aoe_damage(effect: Dictionary, actor: Unit, target_hex: Vector2i,
		units: Array[Unit], hex_unit: Dictionary, hexes: Dictionary,
		kill_fn: Callable) -> String:
	var power_val := int(effect.get("power",  0))
	var radius    := int(effect.get("radius", 1))
	var ff        := bool(effect.get("friendly_fire", false))
	var use_arm   := bool(effect.get("armor", false))

	var hits:    Array[String] = []
	var to_kill: Array[Unit]   = []
	for h in hexes:
		if HexGrid.distance(target_hex, h) > radius: continue
		var uid_h: int = hex_unit.get(h, -1)
		if uid_h == -1: continue
		var t := units[uid_h]
		if not ff and t.team == actor.team: continue
		var base := power_val if power_val > 0 else actor.damage
		var dmg  := _armor_reduce(base, t.char_key) if use_arm else base
		t.take_damage(dmg)
		hits.append(t.label)
		if not t.is_alive(): to_kill.append(t)
	for t in to_kill: kill_fn.call(t)
	var show_dmg := power_val if power_val > 0 else actor.damage
	return "-%d [%s]" % [show_dmg,
			", ".join(hits) if not hits.is_empty() else "ніхто"]

# ── AOE_HEAL ──────────────────────────────────────────────────────────────────
## Лікує союзників навколо АКТОРА (center = actor.hex, не target_hex).
## Поля ефекту:
##   power        int   HP для відновлення.
##   radius       int   Радіус від actor.hex (default 2).
##   include_self bool  Лікувати також актора (default false).
static func _do_aoe_heal(effect: Dictionary, actor: Unit,
		units: Array[Unit]) -> String:
	var power        := int(effect.get("power",  0))
	var radius       := int(effect.get("radius", 2))
	var include_self := bool(effect.get("include_self", false))
	var healed: Array[String] = []
	for u in units:
		if u.team != actor.team or not u.is_alive(): continue
		if u.id == actor.id and not include_self: continue
		if HexGrid.distance(actor.hex, u.hex) > radius: continue
		u.hp = mini(u.max_hp, u.hp + power)
		healed.append(u.label)
	return "+%d HP [%s]" % [power,
			", ".join(healed) if not healed.is_empty() else "ніхто поруч"]

# ── Armor helper ──────────────────────────────────────────────────────────────
static func _armor_reduce(raw: int, char_key: String) -> int:
	var armor := GameState.get_char_armor(char_key)
	if armor <= 0: return raw
	return maxi(1, int(round(float(raw) * (1.0 - float(armor) / float(armor + 100)))))
