class_name ItemGenerator
extends RefCounted
## 独立掉落随机序列；已抽取数值写进实例，读档无需重新掷骰。
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var data: ItemsResource
var next_id: int:
	get: return data.next_id
	set(value): data.next_id = value

## 绑定角色物品模块，先恢复种子再恢复完整随机状态。
func _init(items: ItemsResource = null) -> void:
	data = items if items != null else ItemsResource.new()
	rng.seed = data.rng_seed
	rng.state = data.rng_state

## 在会话捕获前同步序列，含金币和材料抽取消耗的随机数。
func synchronize() -> void:
	if data.rng_seed != rng.seed or data.rng_state != rng.state:
		data.rng_seed = rng.seed
		data.rng_state = rng.state
		data.touch()

## 按普通与精英权重抽品质，再按等级、部位、互斥组筛词条。
func generate(level: int, elite: bool = false, unique_id: String = "") -> ItemInstanceResource:
	var definition: ItemBase = ItemCatalog.BASES[rng.randi_range(0, ItemCatalog.BASES.size() - 1)]
	var roll: float = rng.randf()
	var quality: int = (2 if roll < 0.6 else 1) if elite else (2 if roll < 0.15 else (1 if roll < 0.7 else 0))
	if unique_id.is_empty() and elite and rng.randf() < 0.12:
		unique_id = ItemCatalog.UNIQUES[rng.randi_range(0, ItemCatalog.UNIQUES.size() - 1)].id
	if not unique_id.is_empty():
		definition = ItemCatalog.base(ItemCatalog.unique(unique_id).base_id)
		quality = 3
	var item: ItemInstanceResource = ItemInstanceResource.new()
	item.id = str(next_id)
	item.base = definition.id
	item.level = level
	item.quality = quality
	item.unique_id = unique_id
	next_id += 1
	var count: int = 0
	if quality == 1:
		count = rng.randi_range(1, 2)
	elif quality == 2:
		count = rng.randi_range(3, 4)
	elif quality == 3:
		count = 1
	var pool: Array[AffixDefinition] = []
	for candidate: AffixDefinition in ItemCatalog.AFFIXES:
		if candidate.min_level <= level and candidate.slots.has(definition.slot):
			pool.append(candidate)
	for index: int in range(count):
		var total: float = 0.0
		for candidate: AffixDefinition in pool:
			total += candidate.weight
		if total <= 0.0:
			break
		var ticket: float = rng.randf() * total
		var chosen: AffixDefinition = pool.back()
		for candidate: AffixDefinition in pool:
			ticket -= candidate.weight
			if ticket <= 0.0:
				chosen = candidate
				break
		item.affixes.append(AffixRollResource.create(chosen.id, snappedf(rng.randf_range(chosen.minimum, chosen.maximum), 0.001)))
		for pool_index: int in range(pool.size() - 1, -1, -1):
			if pool[pool_index].group == chosen.group:
				pool.remove_at(pool_index)
	synchronize()
	return item

## 装备名称含品质和部位，地面与背包共同使用。
static func title(item: ItemInstanceResource) -> String:
	var definition: ItemBase = ItemCatalog.base(item.base)
	var name_text: String = ItemCatalog.unique(item.unique_id).display_name if not item.unique_id.is_empty() else definition.display_name
	return "%s %s [%s]" % [["普通", "魔法", "稀有", "独特"][int(item.quality)], name_text, ItemCatalog.SLOT_NAMES[definition.slot]]

## 说明取自底材与实际随机结果；独特机制文本含真实结算参数。
static func describe(item: ItemInstanceResource) -> String:
	var definition: ItemBase = ItemCatalog.base(item.base)
	var result: String = "%s\n物品等级 %d · 售价 %d 金\n%s" % [title(item), item.level, price(item), ItemCatalog.stat_text(definition.stat, definition.value)]
	for rolled: AffixRollResource in item.affixes:
		var entry: AffixDefinition = ItemCatalog.affix(rolled.id)
		result += "\n" + ItemCatalog.stat_text(entry.stat, rolled.value)
	var stats: Dictionary = ItemCatalog.unique_stats(item.unique_id)
	var defaults: BuildDefinition = BuildDefinition.new()
	for stat: String in stats:
		if stat == "chain_count":
			result += "\n直接暴击释放最多 %d 目标连锁闪电" % int(stats[stat])
			result += "\n闪电基础伤害 %.0f，间隔 %.2f 秒，跳跃 %.1f 米；存活目标感电 %.1f 秒" % [defaults.lightning_damage, defaults.lightning_cooldown_sec, defaults.chain_range_m, defaults.shock_duration_sec]
		elif stat == "death_explosion":
			result += "\n感电目标死亡时爆炸：基础伤害 %.0f，半径 %.1f 米" % [defaults.explosion_damage, defaults.explosion_radius_m]
		else:
			result += "\n" + ItemCatalog.stat_text(stat, float(stats[stat]))

	return result

## 出售价值由品质和物品等级计算。
static func price(item: ItemInstanceResource) -> int:
	return 5 + int(item.quality) * 12 + int(item.level) * 2
