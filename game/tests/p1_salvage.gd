extends Node
## P1_Task4 拆解回归：四品质收益、稳定 ID、防重复、归属/地点/锁定失败均保持原值。
var failures: int = 0
var checks: int = 0

## 启动后执行纯业务事务验证。
func _ready() -> void:
	_run()

## 记录单项断言。
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

## 用固定随机序列生成指定普通品质；独特直接指定稳定内容 ID。
func _quality_item(generator: ItemGenerator, quality: int, level: int) -> ItemInstanceResource:
	if quality == 3:
		return generator.generate(level, true, "blood_echo")
	for attempt: int in range(512):
		var item: ItemInstanceResource = generator.generate(level, false)
		if item.quality == quality:
			return item
	return null

## 验证拆解规则和失败事务边界。
func _run() -> void:
	var items: ItemsResource = ItemsResource.new()
	var economy: EconomyResource = EconomyResource.new()
	var inventory: InventoryState = InventoryState.new(items, null, economy)
	var generator: ItemGenerator = ItemGenerator.new(items)
	generator.rng.seed = 420240914
	var service: SalvageService = SalvageService.new(inventory, true)
	var qualities: Array[int] = [0, 1, 2, 3]
	var levels: Array[int] = [1, 4, 7, 10]
	var expected: Array[int] = [1, 3, 6, 10]
	for index: int in range(qualities.size()):
		var item: ItemInstanceResource = _quality_item(generator, qualities[index], levels[index])
		check(item != null and inventory.pickup(item), "品质 %d 装备可进入背包" % qualities[index])
		var preview: Dictionary = service.preview(item.id)
		check(bool(preview.ok) and int(preview.materials) == expected[index], "品质 %d、等级 %d 的拆解预览为 %d 材料" % [qualities[index], levels[index], expected[index]])
		var before_materials: int = inventory.materials
		var result: Dictionary = service.salvage(item.id)
		check(bool(result.ok) and inventory.materials == before_materials + expected[index] and not items.instances.has(item.id), "品质 %d 拆解删除单个实例并只增加一次材料" % qualities[index])

	var locked: ItemInstanceResource = _quality_item(generator, 1, 3)
	check(inventory.pickup(locked), "锁定失败用例装备进入背包")
	locked.locked = true
	var before_locked: int = inventory.materials
	check(not bool(service.salvage(locked.id).ok) and inventory.materials == before_locked and items.instances.has(locked.id), "锁定装备拆解失败且物品材料保持")

	var equipped: ItemInstanceResource = _quality_item(generator, 0, 2)
	check(inventory.pickup(equipped), "穿戴失败用例装备进入背包")
	var equipped_index: int = items.bag_ids.find(equipped.id)
	check(inventory.equip(equipped_index), "失败用例装备可先穿戴")
	var before_equipped: int = inventory.materials
	check(not bool(service.salvage(equipped.id).ok) and inventory.materials == before_equipped and items.instances.has(equipped.id), "已穿戴装备必须先卸下才能拆解")

	var stored: ItemInstanceResource = _quality_item(generator, 0, 2)
	check(inventory.pickup(stored), "仓库失败用例装备进入背包")
	var stored_index: int = items.bag_ids.find(stored.id)
	check(inventory.transfer(stored_index, true), "失败用例装备可存入仓库")
	var before_stored: int = inventory.materials
	check(not bool(service.salvage(stored.id).ok) and inventory.materials == before_stored and items.instances.has(stored.id), "仓库装备必须先移入背包才能拆解")

	var combat_item: ItemInstanceResource = _quality_item(generator, 0, 2)
	check(inventory.pickup(combat_item), "战斗地点失败用例装备进入背包")
	var combat_service: SalvageService = SalvageService.new(inventory, false)
	var before_combat: int = inventory.materials
	check(not bool(combat_service.salvage(combat_item.id).ok) and inventory.materials == before_combat and items.instances.has(combat_item.id), "探险地点拒绝拆解且余额与实例保持")

	var once: ItemInstanceResource = _quality_item(generator, 2, 6)
	check(inventory.pickup(once), "重复请求用例装备进入背包")
	var once_yield: int = SalvageService.RULES.materials_for(once)
	var before_once: int = inventory.materials
	check(bool(service.salvage(once.id).ok), "第一次稳定 ID 拆解成功")
	check(not bool(service.salvage(once.id).ok) and inventory.materials == before_once + once_yield, "同一实例第二次请求失败且不会重复发材料")

	var first: ItemInstanceResource = _quality_item(generator, 0, 1)
	var target: ItemInstanceResource = _quality_item(generator, 1, 4)
	check(inventory.pickup(first) and inventory.pickup(target), "排序变化用例两件装备进入背包")
	var target_id: String = target.id
	var other_id: String = first.id
	items.bag_ids.reverse()
	var before_sort: int = inventory.materials
	var target_yield: int = SalvageService.RULES.materials_for(target)
	check(bool(service.salvage(target_id).ok) and not items.instances.has(target_id) and items.instances.has(other_id) and inventory.materials == before_sort + target_yield, "列表顺序变化后仍按稳定实例 ID 拆中目标")
	check(items.validate().ok and economy.validate().ok, "拆解及失败操作后物品归属与经济模块仍合法")

	print("P1_SALVAGE_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
