class_name SaveValidator
extends RefCounted
## 在恢复前检查版本内结构、内容编号、持续状态和物品唯一归属，拒绝损坏数据。

## 校验有限数值和允许范围。
static func number(value: Variant, low: float = 0.0, high: float = 1.0e12) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

## 校验三维向量数组，坐标与速度均禁止非有限值。
static func vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for entry: Variant in value:
		if not number(entry, -10000.0, 10000.0):
			return false
	return true

## 快照字段必须完整且没有未知成员，避免任意对象属性写入。
static func fields(data: Variant, keys: Array, vectors: Array[String] = [], booleans: Array[String] = []) -> bool:
	if not data is Dictionary or data.size() != keys.size():
		return false
	for key: String in keys:
		if not data.has(key):
			return false
		if vectors.has(key):
			if not vector(data[key]):
				return false
		elif booleans.has(key):
			if not data[key] is bool:
				return false
		elif not number(data[key], -10000.0):
			return false
	return true

## 校验单层流血快照；仅允许玩家横扫来源和固定十字段结构。
static func bleed(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 10:
		return false
	for key: String in ["source", "root_attack_id", "damage", "remaining_sec", "next_tick_sec", "tick_interval_sec", "kill_energy", "death_explosion", "explosion_radius_m", "explosion_damage"]:
		if not data.has(key):
			return false
	if data.source != "player:sweep" or not data.death_explosion is bool:
		return false
	if not number(data.root_attack_id, 1) or float(data.root_attack_id) != int(data.root_attack_id):
		return false
	if not number(data.damage, 0.0001, 1000000.0) or not number(data.remaining_sec, 0.0, 60.0):
		return false
	if not number(data.next_tick_sec, 0.0, 60.0) or not number(data.tick_interval_sec, 0.01, 60.0):
		return false
	if not number(data.kill_energy, 0.0, 10000.0) or not number(data.explosion_radius_m, 0.0, 1000.0) or not number(data.explosion_damage, 0.0, 1000000.0):
		return false
	return true

## 检查底材、品质、独特装备部位、词条等级范围及互斥组。
static func item(data: Variant, ids: Dictionary) -> bool:
	if not data is Dictionary:
		return false
	for key: String in ["id", "base", "level", "quality", "unique", "affixes", "locked"]:
		if not data.has(key):
			return false
	if not data.id is String or not data.id.is_valid_int() or int(data.id) < 1 or ids.has(data.id):
		return false
	if not data.base is String or ItemCatalog.base(data.base) == null or not data.locked is bool:
		return false
	if not number(data.level, 1, 100000) or not number(data.quality, 0, 3) or not number(data.unique, -1, 2):
		return false
	if float(data.level) != int(data.level) or float(data.quality) != int(data.quality) or float(data.unique) != int(data.unique):
		return false
	if (int(data.quality) == 3) != (int(data.unique) >= 0):
		return false
	if int(data.unique) >= 0 and data.base != ItemCatalog.UNIQUES[int(data.unique)].base_id:
		return false
	if not data.affixes is Array:
		return false
	var limits: Array = [[0, 0], [1, 2], [3, 4], [1, 1]][int(data.quality)]
	if data.affixes.size() < limits[0] or data.affixes.size() > limits[1]:
		return false
	var groups: Array[String] = []
	for rolled: Variant in data.affixes:
		if not rolled is Dictionary or not rolled.get("id") is String:
			return false
		var definition: AffixDefinition = ItemCatalog.affix(rolled.id)
		if definition == null or definition.min_level > int(data.level) or groups.has(definition.group):
			return false
		if not definition.slots.has(ItemCatalog.base(data.base).slot) or not number(rolled.get("value"), definition.minimum - 0.00001, definition.maximum + 0.00001):
			return false
		groups.append(definition.group)
	ids[data.id] = true
	return true

## 检查完整会话，随机状态以字符串保存以避免 JSON 浮点精度损失。
static func expedition(data: Variant, version: int = 4) -> bool:
	if not data is Dictionary:
		return false
	for key: String in ["inventory", "in_town", "wave_completed", "minimum_quality", "ground", "next_drop_id", "next_item_id", "loot_rng", "combat_rng", "enemies", "projectiles", "player", "position", "facing", "skills", "clock", "attack_id", "kills", "damage", "lightning_ready", "lightning_count", "explosion_count"]:
		if not data.has(key):
			return false
	if not data.in_town is bool or not data.wave_completed is bool or not vector(data.position):
		return false
	if absf(data.position[0]) > 19.2 or absf(data.position[2]) > 19.2:
		return false
	for key: String in ["loot_rng", "combat_rng"]:
		if not data[key] is String or not data[key].is_valid_int():
			return false
	for key: String in ["next_drop_id", "next_item_id", "clock", "attack_id", "kills", "damage", "lightning_ready", "lightning_count", "explosion_count"]:
		if not number(data[key]):
			return false
	if not number(data.minimum_quality, 0, 2) or not number(data.facing, -10000, 10000):
		return false
	if version >= 3 and not LoadoutState.valid(data.get("loadout")):
		return false
	if version == 2 and data.has("loadout"):
		return false
	var inv: Variant = data.inventory
	if not inv is Dictionary or inv.size() != 9:
		return false
	for key: String in ["gold", "materials", "level", "experience", "difficulty", "completed"]:
		if not number(inv.get(key)) or float(inv[key]) != int(inv[key]):
			return false
	if inv.level < 1 or inv.difficulty < 1:
		return false
	if not inv.get("bag") is Array or not inv.get("stash") is Array or not inv.get("equipment") is Dictionary:
		return false
	if inv.bag.size() > 40 or inv.stash.size() > 120:
		return false
	var ids: Dictionary = {}
	for entry: Variant in inv.bag + inv.stash:
		if not item(entry, ids):
			return false
	for slot: Variant in inv.equipment:
		if not slot is String or not ItemCatalog.SLOTS.has(slot) or not item(inv.equipment[slot], ids):
			return false
		if ItemCatalog.base(inv.equipment[slot].base).slot != slot:
			return false
	if not data.ground is Array or not data.enemies is Array or not data.projectiles is Array:
		return false
	if data.ground.size() > 10000 or data.enemies.size() > 1000 or data.projectiles.size() > 10000:
		return false
	var drop_ids: Dictionary = {}
	for drop: Variant in data.ground:
		if not drop is Dictionary or not drop.get("id") is String or not drop.id.is_valid_int() or drop_ids.has(drop.id) or int(drop.id) >= int(data.next_drop_id):
			return false
		if not ["gold", "material", "item"].has(drop.get("kind")) or not vector(drop.get("position")) or not number(drop.get("amount"), 1):
			return false
		if drop.kind == "item" and not item(drop.get("item"), ids):
			return false
		drop_ids[drop.id] = true
	for id: String in ids:
		if int(id) >= int(data.next_item_id):
			return false
	var vectors: Array[String] = ["knockback_velocity", "velocity", "_dodge_direction"]
	if not fields(data.player, SessionSnapshot.ACTOR + SessionSnapshot.PLAYER, vectors, ["is_dead"]):
		return false
	var skill_fields: Array[String] = SessionSnapshot.SKILL if version >= 4 else SessionSnapshot.SKILL_V3
	var skill_bools: Array[String] = ["_exhausted", "_warcry_applied"] if version >= 4 else ["_exhausted"]
	if not fields(data.skills, skill_fields, [], skill_bools):
		return false
	if data.player.health <= 0 or data.player.health > data.player.max_health or data.player.is_dead:
		return false
	if data.skills.energy < 0 or data.skills.energy > 100:
		return false
	if version >= 4:
		for key: String in ["_sweep_remaining", "_warcry_remaining", "_warcry_cooldown_remaining", "_potion_remaining"]:
			if not number(data.skills[key], 0.0, 120.0):
				return false
		if data.skills._warcry_applied and data.skills._warcry_remaining <= 0.0:
			return false
		if not data.skills._warcry_applied and data.skills._warcry_remaining != 0.0:
			return false
	for enemy: Variant in data.enemies:
		if not enemy is Dictionary or not enemy.get("definition") is String:
			return false
		var path: String = enemy.definition
		if not ["res://content/enemies/melee.tres", "res://content/enemies/ranged.tres", "res://content/enemies/charger.tres", "res://content/enemies/elite.tres"].has(path):
			return false
		var runtime: Dictionary = enemy.duplicate()
		if version >= 4:
			if not enemy.get("bleeds") is Array or enemy.bleeds.size() > SkillRunner.SWEEP.bleed_max_stacks:
				return false
			for layer: Variant in enemy.bleeds:
				if not bleed(layer) or int(layer.root_attack_id) > int(data.attack_id):
					return false
			runtime.erase("bleeds")
		elif enemy.has("bleeds"):
			return false
		runtime.erase("definition")
		if not fields(runtime, SessionSnapshot.ACTOR + SessionSnapshot.ENEMY + ["position", "damage"], ["knockback_velocity", "velocity", "_locked_direction", "position"], ["is_dead"]):
			return false
		if not number(enemy.state, 0, 3) or enemy.is_dead or enemy.health <= 0 or enemy.health > enemy.max_health:
			return false
	for projectile: Variant in data.projectiles:
		if not fields(projectile, SessionSnapshot.PROJECTILE + ["position"], ["direction", "position"]):
			return false
	if data.in_town and (not data.enemies.is_empty() or not data.projectiles.is_empty() or not data.ground.is_empty()):
		return false
	return true
