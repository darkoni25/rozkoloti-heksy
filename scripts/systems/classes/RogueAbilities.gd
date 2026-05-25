class_name RogueAbilities
## Навички класу Злодій (class_idx = 3).

static func get_data() -> Dictionary:
	return {
		4: {
			"name":  "Удар тіні",
			"desc":  "actor.damage+6, ігнорує броню",
			"cd":    3,
			"mode":  AbilityEnums.TargetMode.ENEMY_NEAR,
			"range": 1,
			"effects": [
				# power=0 → base = actor.damage; bonus=6 → +6; armor=false → ігнорує броню
				{"type": AbilityEnums.EffectType.DAMAGE, "power": 0, "bonus": 6, "armor": false},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [4]
