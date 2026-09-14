extends Node
## P1_Task4 拆解回归：四品质收益、稳定 ID、防重复与失败事务边界。
var failures: int = 0
var checks: int = 0

## 启动业务回归。
func _ready() -> void:
	_run()

## 记录断言。
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 固定随机序列生成指定品质；独特直接指定稳定内容 ID。
func _item(generator: ItemGenerator, quality: int, level: int) -> ItemInstanceResource:
	if quality == 3:
		return generator.generate(level, true, "blood_echo")
	for _attempt: int in range(512):
		var item: ItemInstanceResource = generator.generate(level, false)
		if item.quality == quality:
			return item
	return null

## 验证收益和按稳定实例 ID 提交的事务规则。
func _run() -> void:
	var items := ItemsResource.new()
	items.module_version = items.current_version()
	var economy := EconomyResource.new()
	economy.module_version = economy.current_version()
	var inventory := InventoryState.new(items, null, economy)
	var generator := ItemGenerator.new(items)
	generator.rng.seed = 420240914
	var service := SalvageService.new(inventory, true)

	var qualities: Array[int] = [0, 1, 2, 3]
	var levels: Array[int] = [1, 4, 7, 10]
	var yields: Array[int] = [1, 3, 6, 10]
	for i: int in range(4):
		var item := _item(generator, qualities[i], levels[i])
		check(item != null and inventory.pickup(item), "四品质装备可进入背包 %d" % i)
		var preview := service.preview(item.id)
		check(bool(preview.ok) and int(preview.materials) == yields[i], "拆解预览与配置一致 %d" % i)
		var before := inventory.materials
		check(bool(service.salvage(item.id).ok) and inventory.materials == before + yields[i] and not items.instances.has(item.id), "拆解删除实例并增加一次材料 %d" % i)

	var locked := _item(generator, 1, 3)
	inventory.pickup(locked)
	locked.locked = true
	var before_locked := inventory.materials
	check(not bool(service.salvage(locked.id).ok) and inventory.materials == before_locked and items.instances.has(locked.id), "锁定失败保持原值")

	var equipped := _item(generator, 0, 2)
	inventory.pickup(equipped)
	inventory.equip(items.bag_ids.find(equipped.id))
	var before_equipped := inventory.materials
	check(not bool(service.salvage(equipped.id).ok) and inventory.materials == before_equipped, "穿戴装备拒绝拆解")

	var stored := _item(generator, 0, 2)
	inventory.pickup(stored)
	inventory.transfer(items.bag_ids.find(stored.id), true)
	var before_stored := inventory.materials
	check(not bool(service.salvage(stored.id).ok) and inventory.materials == before_stored, "仓库装备拒绝拆解")

	var combat_item := _item(generator, 0, 2)
	inventory.pickup(combat_item)
	var combat_service := SalvageService.new(inventory, false)
	var before_combat := inventory.materials
	check(not bool(combat_service.salvage(combat_item.id).ok) and inventory.materials == before_combat and items.instances.has(combat_item.id), "探险地点拒绝拆解")

	var once := _item(generator, 2, 6)
	inventory.pickup(once)
	var once_yield := SalvageService.RULES.materials_for(once)
	var before_once := inventory.materials
	check(bool(service.salvage(once.id).ok), "首次稳定 ID 拆解成功")
	check(not bool(service.salvage(once.id).ok) and inventory.materials == before_once + once_yield, "重复请求只结算一次")

	var first := _item(generator, 0, 1)
	var target := _item(generator, 1, 4)
	inventory.pickup(first)
	inventory.pickup(target)
	var target_id := target.id
	var other_id := first.id
	items.bag_ids.reverse()
	var before_sort := inventory.materials
	check(bool(service.salvage(target_id).ok) and not items.instances.has(target_id) and items.instances.has(other_id) and inventory.materials == before_sort + SalvageService.RULES.materials_for(target), "列表顺序变化仍按稳定 ID 拆中目标")
	check(items.validate().ok and economy.validate().ok, "最终物品归属与经济模块合法")

	print("P1_SALVAGE_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
