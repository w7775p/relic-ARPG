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

## 返回某件装备在指定替换位置可抽到的合法词条；空 definitions 使用正式目录，测试可传入小候选池。
static func affix_candidates(item: ItemInstanceResource, replace_index: int = -1, definitions: Array = []) -> Array[AffixDefinition]:
	var result: Array[AffixDefinition] = []
	if item == null:
		return result
	var base_definition: ItemBase = ItemCatalog.base(item.base)
	if base_definition == null:
		return result
	var source: Array = definitions if not definitions.is_empty() else ItemCatalog.AFFIXES
	var blocked_ids: Dictionary = {}
	var blocked_groups: Dictionary = {}
	for index: int in range(item.affixes.size()):
		if index == replace_index:
			continue
		var roll: AffixRollResource = item.affixes[index]
		if roll == null:
			continue
		blocked_ids[roll.id] = true
		var occupied: AffixDefinition = _affix_in(source, roll.id)
		if occupied == null:
			occupied = ItemCatalog.affix(roll.id)
		if occupied != null and not occupied.group.is_empty():
			blocked_groups[occupied.group] = true
	for value: Variant in source:
		var candidate: AffixDefinition = value as AffixDefinition
		if candidate == null or candidate.min_level > item.level or not candidate.slots.has(base_definition.slot):
			continue
		if blocked_ids.has(candidate.id) or (not candidate.group.is_empty() and blocked_groups.has(candidate.group)):
			continue
		result.append(candidate)
	return result

## 按权重从合法候选中抽一个词条并写入实际数值；允许抽回当前词条和相同数值。
static func roll_affix(random: RandomNumberGenerator, pool: Array[AffixDefinition]) -> AffixRollResource:
	if random == null or pool.is_empty():
		return null
	var total: float = 0.0
	for candidate: AffixDefinition in pool:
		total += maxf(0.0, candidate.weight)
	if total <= 0.0:
		return null
	var ticket: float = random.randf() * total
	var chosen: AffixDefinition = pool.back()
	for candidate: AffixDefinition in pool:
		ticket -= maxf(0.0, candidate.weight)
		if ticket <= 0.0:
			chosen = candidate
			break
	return AffixRollResource.create(chosen.id, snappedf(random.randf_range(chosen.minimum, chosen.maximum), 0.001))

## 在给定候选池按稳定内容 ID 找定义，供小候选池测试和互斥检查共用。
static func _affix_in(definitions: Array, id: String) -> AffixDefinition:
	for value: Variant in definitions:
		var definition: AffixDefinition = value as AffixDefinition
		if definition != null and definition.id == id:
			return definition
	return null

## 按普通与精英权重抽品质，再复用合法候选规则逐条生成随机词条。
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
	for index: int in range(count):
		var pool: Array[AffixDefinition] = affix_candidates(item)
		var rolled: AffixRollResource = roll_affix(rng, pool)
		if rolled == null:
			break
		item.affixes.append(rolled)
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
		if stat.begins_with("bleed_spread_"):
			continue
		if stat == "chain_count":
			result += "\n直接暴击释放最多 %d 目标连锁闪电" % int(stats[stat])
			result += "\n闪电基础伤害 %.0f，间隔 %.2f 秒，跳跃 %.1f 米；存活目标感电 %.1f 秒" % [defaults.lightning_damage, defaults.lightning_cooldown_sec, defaults.chain_range_m, defaults.shock_duration_sec]
		elif stat == "death_explosion":
			result += "\n感电目标死亡时爆炸：基础伤害 %.0f，半径 %.1f 米" % [defaults.explosion_damage, defaults.explosion_radius_m]
		else:
			result += "\n" + ItemCatalog.stat_text(stat, float(stats[stat]))
	if int(stats.get("bleed_spread_max_targets", 0)) > 0:
		result += "\n流血击杀传播：%.1f 米内最多 %d 个目标，继承 %.0f%% 流血伤害，最多传播 %d 代" % [float(stats.get("bleed_spread_radius_m", 0.0)), int(stats.get("bleed_spread_max_targets", 0)), float(stats.get("bleed_spread_damage_ratio", 0.0)) * 100.0, int(stats.get("bleed_spread_max_generation", 0))]
	return result

## 出售价值由品质和物品等级计算。
static func price(item: ItemInstanceResource) -> int:
	return 5 + int(item.quality) * 12 + int(item.level) * 2
