class_name BardAbilities
## Навички класу Бард (class_idx = 7).

static func get_data() -> Dictionary:
	return {
		8: {
			"name":  "Натхнення",
			"desc":  "+8 HP всім союзникам у радіусі 2",
			"cd":    2,
			"mode":  AbilityEnums.TargetMode.SELF,
			"range": 0,
			"effects": [
				# include_self=false → бард не лікує себе (як в оригіналі)
				{"type": AbilityEnums.EffectType.AOE_HEAL, "power": 8, "radius": 2, "include_self": false},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [8]
