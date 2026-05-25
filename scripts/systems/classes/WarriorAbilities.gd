class_name WarriorAbilities
## Навички класу Воїн (class_idx = 2).

static func get_data() -> Dictionary:
	return {
		3: {
			"name":  "Пот. удар",
			"desc":  "×2 урон ворогу (з урахуванням броні)",
			"cd":    3,
			"mode":  AbilityEnums.TargetMode.ENEMY_NEAR,
			"range": 1,
			"effects": [
				# power=0 → base = actor.damage; mult=2.0 → ×2; armor=true
				{"type": AbilityEnums.EffectType.DAMAGE, "power": 0, "mult": 2.0, "armor": true},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [3]
