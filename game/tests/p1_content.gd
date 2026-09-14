extends Node
## P1_Task3 内容回归：装备额度、稳定 ID、词条合法性与流血装备属性。
var failures: int = 0
var checks: int = 0

## 记录失败并继续执行，完整暴露内容配置问题。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 延迟运行，确保 Resource 类和自动加载服务完成初始化。
func _ready() -> void:
	_run.call_deferred()

## 核对累计 14/18/4，并抽样生成各等级装备。
func _run() -> void:
	check(ItemCatalog.BASES.size() == 14, "累计底材数量为 14")
	check(ItemCatalog.AFFIXES.size() == 18, "累计普通随机词条数量为 18")
	check(ItemCatalog.UNIQUES.size() == 4, "累计独特装备数量为 4")
	var base_ids: Dictionary = {}
	for entry: ItemBase in ItemCatalog.BASES:
		base_ids[entry.id] = true
		check(ItemCatalog.SLOTS.has(entry.slot), "底材 %s 使用合法部位" % entry.id)
	var affix_ids: Dictionary = {}
	for entry: AffixDefinition in ItemCatalog.AFFIXES:
		affix_ids[entry.id] = true
		check(ItemCatalog.STAT_NAMES.has(entry.stat), "词条 %s 有中文结算属性" % entry.id)
		check(not entry.slots.is_empty(), "词条 %s 至少适用一个部位" % entry.id)
	var unique_ids: Dictionary = {}
	for entry: UniqueDefinition in ItemCatalog.UNIQUES:
		unique_ids[entry.id] = true
		check(ItemCatalog.base(entry.base_id) != null, "独特 %s 引用存在的底材" % entry.id)
	check(base_ids.size() == 14 and affix_ids.size() == 18 and unique_ids.size() == 4, "底材、词条、独特 ID 均唯一")
	check(unique_ids.has("thunder_ring") and unique_ids.has("ember_mail") and unique_ids.has("energy_grips") and unique_ids.has("blood_echo"), "前三个稳定独特 ID 保持并新增 blood_echo")
	var generator: ItemGenerator = ItemGenerator.new()
	generator.rng.seed = 3103
	var legal: bool = true
	var seen_slots: Dictionary = {}
	var seen_qualities: Dictionary = {}
	for index: int in range(2400):
		var item: ItemInstanceResource = generator.generate(1 + index % 6, index % 4 == 0)
		legal = legal and item.validate().ok
		seen_slots[ItemCatalog.base(item.base).slot] = true
		seen_qualities[item.quality] = true
		var groups: Dictionary = {}
		for rolled: AffixRollResource in item.affixes:
			var affix: AffixDefinition = ItemCatalog.affix(rolled.id)
			legal = legal and affix != null and affix.min_level <= item.level and affix.slots.has(ItemCatalog.base(item.base).slot) and not groups.has(affix.group)
			groups[affix.group] = true
	check(legal and seen_slots.size() == 6 and seen_qualities.has(0) and seen_qualities.has(1) and seen_qualities.has(2) and seen_qualities.has(3), "多等级样本覆盖六部位与四品质且全部实例合法")
	var blood: ItemInstanceResource = generator.generate(6, true, "blood_echo")
	check(blood.validate().ok and blood.unique_id == "blood_echo" and blood.base == "serrated_blade", "第四件独特使用稳定 ID 和指定底材")
	var inventory: InventoryState = InventoryState.new()
	inventory.pickup(blood)
	inventory.equip(0)
	var build: BuildDefinition = inventory.build()
	check(build.bleed_damage_multiplier > 1.0 and build.bleed_spread_max_targets == 3 and build.bleed_spread_max_generation == 1, "流血底材与独特传播参数进入真实属性汇总")
	check(ItemGenerator.describe(blood).contains("流血击杀传播"), "第四件独特说明展示真实传播参数")
	print("P1_CONTENT_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
