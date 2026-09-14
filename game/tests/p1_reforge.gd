extends Node
## P1_Task5 重铸回归：候选规则、固定位置、独立 RNG、失败原子性与真实 Resource 往返。
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 创建测试候选定义；沿用正式词条 ID，使重铸结果仍能通过实例内容校验。
func definition(id: String, group: String, minimum: float, maximum: float, min_level: int = 1) -> AffixDefinition:
	var result: AffixDefinition = AffixDefinition.new()
	result.id = id
	result.display_name = "测试-" + id
	result.stat = ItemCatalog.affix(id).stat
	result.group = group
	result.slots = PackedStringArray(["weapon"])
	result.min_level = min_level
	result.weight = 1.0
	result.minimum = minimum
	result.maximum = maximum
	return result

## 生成指定词条的合法魔法武器并放入背包。
func magic_weapon(session: GameSession, power_value: float = 2.0, vitality_value: float = 10.0) -> ItemInstanceResource:
	var item: ItemInstanceResource = ItemInstanceResource.new()
	item.id = str(session.modules.items.next_id)
	item.base = "rust_sword"
	item.level = 1
	item.quality = 1
	item.affixes = [AffixRollResource.create("power", power_value), AffixRollResource.create("vitality", vitality_value)]
	check(session.inventory.pickup(item), "测试魔法武器进入背包")
	return item

func _ready() -> void:
	var session: GameSession = GameSession.new()
	session.inventory.materials = 30
	var target: ItemInstanceResource = magic_weapon(session)
	var sibling: ItemInstanceResource = magic_weapon(session, 3.0, 11.0)
	var power_fixed: AffixDefinition = definition("power", "power", 6.0, 6.0)
	var precision: AffixDefinition = definition("precision", "precision", 0.05, 0.10)
	var vitality: AffixDefinition = definition("vitality", "health", 8.0, 16.0)
	var high_level: AffixDefinition = definition("execution", "execution", 0.05, 0.15, 5)
	var small_pool: Array = [power_fixed, precision, vitality, high_level]
	var candidates: Array[AffixDefinition] = ItemGenerator.affix_candidates(target, 0, small_pool)
	var ids: Array[String] = []
	for candidate: AffixDefinition in candidates:
		ids.append(candidate.id)
	ids.sort()
	check(ids == ["power", "precision"], "小候选池按部位/等级保留合法项，并排除其他位置占据的互斥组")
	check(ItemGenerator.affix_candidates(target, 0, [vitality, high_level]).is_empty(), "小候选池可明确形成零候选边界")

	var target_index: int = session.modules.items.bag_ids.find(target.id)
	check(session.inventory.equip(target_index), "重铸目标可先穿戴用于属性基线")
	var damage_before: float = session.inventory.build().damage
	check(session.inventory.unequip("weapon"), "重铸前目标已卸下返回背包")
	var sibling_before: String = ResourceFingerprint.digest(sibling)
	var static_minimum: float = ItemCatalog.affix("power").minimum
	var drop_snapshot: ItemsResource = session.modules.items.capture() as ItemsResource
	var drop_seed: int = session.modules.items.rng_seed
	var drop_state: int = session.modules.items.rng_state
	var reforge_state_before: int = session.modules.items.reforge_rng_state
	var service: ReforgeService = ReforgeService.new(session.inventory, true, [power_fixed, vitality])
	var preview: Dictionary = service.preview(target.id, 0)
	check(bool(preview.ok) and int(preview.cost) == 2 and str(preview.candidates).contains("power"), "重铸预览显示位置候选与 1 级魔法装备 2 材料费用")
	var materials_before: int = session.inventory.materials
	var first: Dictionary = service.reforge(target.id, 0, "same-request")
	check(bool(first.ok) and target.reforge_index == 0 and session.inventory.materials == materials_before - 2, "首次重铸成功后固定位置并只扣一次材料")
	check(target.affixes[0].id == "power" and is_equal_approx(target.affixes[0].value, 6.0), "重铸允许抽回相同词条，并写入本次真实数值")
	check(target.affixes[1].id == "vitality" and is_equal_approx(target.affixes[1].value, 10.0), "未选中的词条保持原 ID 与数值")
	check(session.modules.items.rng_seed == drop_seed and session.modules.items.rng_state == drop_state, "重铸不推进掉落随机序列")
	check(session.modules.items.reforge_rng_state != reforge_state_before, "成功重铸只推进独立重铸随机序列")
	check(ResourceFingerprint.digest(sibling) == sibling_before and ItemCatalog.affix("power").minimum == static_minimum, "兄弟实例与静态词条定义均未被修改")
	var duplicate_materials: int = session.inventory.materials
	var duplicate_state: int = session.modules.items.reforge_rng_state
	var duplicate: Dictionary = service.reforge(target.id, 0, "same-request")
	check(bool(duplicate.ok) and bool(duplicate.duplicate) and session.inventory.materials == duplicate_materials and session.modules.items.reforge_rng_state == duplicate_state, "重复 request_id 不重复扣材料或推进重铸 RNG")
	var wrong_position: Dictionary = service.reforge(target.id, 1, "wrong-position")
	check(not bool(wrong_position.ok) and target.reforge_index == 0 and target.affixes[1].id == "vitality", "固定后其他位置请求被拒绝")

	target_index = session.modules.items.bag_ids.find(target.id)
	check(session.inventory.equip(target_index), "重铸结果可重新穿戴")
	var damage_after: float = session.inventory.build().damage
	check(is_equal_approx(damage_after - damage_before, 4.0), "穿戴后的伤害立即反映 power 从 2 到 6 的重铸结果")
	check(session.inventory.unequip("weapon"), "保存前将重铸装备放回背包")

	var expected_generator: ItemGenerator = ItemGenerator.new(drop_snapshot)
	var expected_drop: ItemInstanceResource = expected_generator.generate(4, true)
	var actual_drop: ItemInstanceResource = session.generator.generate(4, true)
	check(ResourceFingerprint.digest(actual_drop) == ResourceFingerprint.digest(expected_drop), "重铸后下一件掉落与未重铸的同 RNG 快照完全一致")

	var zero_service: ReforgeService = ReforgeService.new(session.inventory, true, [vitality, high_level])
	var zero_before: String = ResourceFingerprint.digest(sibling)
	var zero_materials: int = session.inventory.materials
	var zero_state: int = session.modules.items.reforge_rng_state
	check(not bool(zero_service.reforge(sibling.id, 0, "zero").ok) and ResourceFingerprint.digest(sibling) == zero_before and session.inventory.materials == zero_materials and session.modules.items.reforge_rng_state == zero_state, "零候选失败保持装备、材料与重铸 RNG 原值")

	session.inventory.materials = 0
	var insufficient_service: ReforgeService = ReforgeService.new(session.inventory, true, [power_fixed, vitality])
	var insufficient_before: String = ResourceFingerprint.digest(sibling)
	var insufficient_state: int = session.modules.items.reforge_rng_state
	check(not bool(insufficient_service.reforge(sibling.id, 0, "poor").ok) and ResourceFingerprint.digest(sibling) == insufficient_before and session.modules.items.reforge_rng_state == insufficient_state, "材料不足不会修改词条或推进重铸 RNG")
	session.inventory.materials = 30
	sibling.locked = true
	var locked_before: int = session.inventory.materials
	check(not bool(service.reforge(sibling.id, 0, "locked").ok) and session.inventory.materials == locked_before, "锁定装备拒绝重铸且余额不变")
	sibling.locked = false
	var sibling_index: int = session.modules.items.bag_ids.find(sibling.id)
	check(session.inventory.transfer(sibling_index, true), "失败边界用装备可存入仓库")
	check(not bool(service.reforge(sibling.id, 0, "stash").ok), "仓库装备必须移回背包才能重铸")
	var stash_index: int = session.modules.items.stash_ids.find(sibling.id)
	check(session.inventory.transfer(stash_index, false), "仓库失败边界装备取回背包")
	var expedition_service: ReforgeService = ReforgeService.new(session.inventory, false, [power_fixed, vitality])
	check(not bool(expedition_service.reforge(sibling.id, 0, "expedition").ok), "探险地点明确拒绝重铸")
	var unique: ItemInstanceResource = session.generator.generate(1, true, "thunder_ring")
	check(session.inventory.pickup(unique), "独特装备进入背包用于品质限制验证")
	check(not bool(service.preview(unique.id, 0).ok), "独特装备固定机制和浮动词条均不进入重铸")

	var store: SaveStore = SaveStore.new()
	store.root = "user://reforge_tests"
	check(store.write_checkpoint(session.capture("reforge"), "manual_01").ok, "重铸后的完整状态写入真实 Resource 检查点")
	var loaded_a: SaveResult = store.load_session(session.group_id, "manual_01")
	var loaded_b: SaveResult = store.load_session(session.group_id, "manual_01")
	check(loaded_a.ok and loaded_b.ok, "同一重铸检查点可以独立读取两次")
	if loaded_a.ok and loaded_b.ok:
		var item_a: ItemInstanceResource = loaded_a.value.modules.items.instances[target.id]
		check(item_a.reforge_index == 0 and item_a.affixes[0].id == target.affixes[0].id and is_equal_approx(item_a.affixes[0].value, target.affixes[0].value) and loaded_a.value.inventory.materials == session.inventory.materials, "保存重开保留固定位置、新词条与材料余额")
		var service_a: ReforgeService = ReforgeService.new(loaded_a.value.inventory, true, [power_fixed, vitality])
		var service_b: ReforgeService = ReforgeService.new(loaded_b.value.inventory, true, [power_fixed, vitality])
		var next_a: Dictionary = service_a.reforge(target.id, 0, "next-a")
		var next_b: Dictionary = service_b.reforge(target.id, 0, "next-b")
		check(bool(next_a.ok) and bool(next_b.ok) and str(next_a.result) == str(next_b.result) and loaded_a.value.modules.items.reforge_rng_state == loaded_b.value.modules.items.reforge_rng_state, "读档后下一次重铸结果与 RNG 状态可复现")

	var migration_session: GameSession = GameSession.new()
	var old_item: ItemInstanceResource = magic_weapon(migration_session)
	var old_save: SaveGameResource = migration_session.capture("v1_fixture")
	var old_items_module: ItemsResource = null
	for module: SaveModule in old_save.modules:
		if module.module_id == "items":
			old_items_module = module as ItemsResource
			break
	var old_drop_seed: int = old_items_module.rng_seed
	var old_drop_state: int = old_items_module.rng_state
	old_items_module.module_version = 1
	old_items_module.reforge_rng_seed = 0
	old_items_module.reforge_rng_state = 0
	old_items_module.instances[old_item.id].reforge_index = -1
	var old_path: String = store.slot_path(migration_session.group_id, "manual_02")
	DirAccess.make_dir_recursive_absolute(old_path.get_base_dir())
	check(ResourceSaver.save(old_save, old_path) == OK, "构造真实 items v1 Resource 旧档")
	var migrated_first: SaveResult = store.load_session(migration_session.group_id, "manual_02")
	var migrated_second: SaveResult = store.load_session(migration_session.group_id, "manual_02")
	check(migrated_first.ok and migrated_second.ok, "items v1 旧档可通过注册表升级到 v2")
	if migrated_first.ok and migrated_second.ok:
		var migrated: ItemsResource = migrated_first.value.modules.items
		check(migrated.module_version == 2 and migrated.rng_seed == old_drop_seed and migrated.rng_state == old_drop_state and migrated.instances[old_item.id].reforge_index == -1, "迁移保留原掉落序列并初始化未选重铸位置")
		check(migrated.reforge_rng_seed != 0 and migrated.reforge_rng_state != 0 and migrated.reforge_rng_seed == migrated_second.value.modules.items.reforge_rng_seed and migrated.reforge_rng_state == migrated_second.value.modules.items.reforge_rng_state, "同一 v1 旧档重复加载得到确定的重铸初始序列")

	print("P1_REFORGE_RESULT: %d failures; %d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
