class_name HunterAbilities
## Навички класу Мисливець (class_idx = 5).

static func get_data() -> Dictionary:
	return {
		6: {
			"name":  "Влучний пос.",
			"desc":  "×2 урон ворогу на відстані до 4 гексів",
			"cd":    2,
			"mode":  AbilityEnums.TargetMode.ENEMY_NEAR,
			"range": 4,
			"effects": [
				# power=0 → base = actor.damage; mult=2.0 → ×2; armor=true
				{"type": AbilityEnums.EffectType.DAMAGE, "power": 0, "mult": 2.0, "armor": true},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [6]
