extends Node
## P1_Task6 业务集成回归：装配、过滤、锁定、拆解→重铸与 Resource 检查点串联。
var failures: int = 0
var checks: int = 0

## 等自动加载服务完成初始化后执行业务链。
func _ready() -> void:
	_run.call_deferred()

## 测试节点模拟 Hub 的保存能力，只用于调用正式 SaveManager 入口。
func can_save_checkpoint() -> bool:
	return true

## 记录断言并继续执行剩余用例。
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 从正式掉落生成器寻找指定品质，不手写装备词条。
func generated_quality(generator: ItemGenerator, quality: int, level: int = 4) -> ItemInstanceResource:
	for _attempt: int in range(512):
		var item: ItemInstanceResource = generator.generate(level, false)
		if item.quality == quality:
			return item
	return null

## 在正常掉落池里准备可用拆解材料重铸的魔法/稀有装备。
func prepare_reforge_target(session: GameSession) -> ItemInstanceResource:
	for _attempt: int in range(128):
		var item: ItemInstanceResource = session.generator.generate(4, false)
		if item.quality != 1 and item.quality != 2:
			continue
		if not session.inventory.pickup(item):
			continue
		var preview: Dictionary = ReforgeService.new(session.inventory, true).preview(item.id, 0)
		if bool(preview.get("ok", false)):
			return item
		var index: int = session.inventory.data.bag_ids.find(item.id)
		if index >= 0:
			session.inventory.sell(index)
	return null

## 串起不依赖场景生命周期的 D1 事务；真实路由与 E/Tab 继续由既有 HubFlow、M2、PickupInput 覆盖。
func _run() -> void:
	check(["primary", "whirlwind", "sweep", "warcry"].all(func(id: String) -> bool: return LoadoutState.skill(id) != null) and ["might", "precision", "reach", "vitality", "guard", "recovery"].all(func(id: String) -> bool: return LoadoutState.passive(id) != null), "D1 原有四技能与六被动稳定 ID 保持")
	check(ItemCatalog.BASES.size() == 14 and ItemCatalog.AFFIXES.size() == 18 and ItemCatalog.UNIQUES.size() == 4, "D1 装备额度保持 14/18/4")
	check(EncounterDirector.ELITE_MODIFIERS.size() == 2 and EncounterDirector.VARIANT_IDS.size() == 2, "D1 保持两个精英修饰与两种固定场地变体")

	var session: GameSession = GameSession.new_character()
	session.generator.rng.seed = 160917
	var inventory: InventoryState = session.inventory
	check(inventory.loadout.set_skill("main", "sweep") and inventory.loadout.set_skill("auxiliary", "warcry"), "角色可装配横扫与战吼")
	check(inventory.loadout.toggle("might").is_empty() and inventory.loadout.toggle("precision").is_empty(), "角色可选择两项被动")
	inventory.loadout.reset_passives()
	check(inventory.loadout.passives.is_empty(), "据点免费重置被动保持同一角色状态")
	inventory.loadout.toggle("might")
	inventory.loadout.toggle("precision")

	session.modules.character.minimum_quality = 2
	session.modules.character.touch()
	check(session.modules.character.minimum_quality == 2, "稀有及以上过滤偏好写入角色模块")

	var locked: ItemInstanceResource = generated_quality(session.generator, 1)
	check(locked != null and inventory.pickup(locked), "正常魔法掉落进入背包作为锁定目标")
	var locked_index: int = inventory.data.bag_ids.find(locked.id)
	inventory.toggle_lock(locked_index)
	var locked_digest: String = ResourceFingerprint.digest(locked)
	var locked_gold: int = inventory.gold
	var locked_materials: int = inventory.materials
	check(not inventory.sell(locked_index) and inventory.gold == locked_gold, "锁定装备拒绝出售")
	check(not bool(SalvageService.new(inventory, true).salvage(locked.id).get("ok", false)) and inventory.materials == locked_materials, "锁定装备拒绝拆解")
	check(not bool(ReforgeService.new(inventory, true).reforge(locked.id, 0, "p1-task6-locked").get("ok", false)), "锁定装备拒绝重铸")
	check(locked.locked and ResourceFingerprint.digest(locked) == locked_digest, "锁定装备经过三种失败操作后实例保持原值")

	inventory.materials = 0
	var salvage_source: ItemInstanceResource = generated_quality(session.generator, 2)
	check(salvage_source != null and inventory.pickup(salvage_source), "正常稀有掉落进入背包作为拆解来源")
	var salvage_result: Dictionary = SalvageService.new(inventory, true).salvage(salvage_source.id)
	check(bool(salvage_result.get("ok", false)) and inventory.materials > 0, "拆解稀有装备获得重铸材料")

	var reforge_target: ItemInstanceResource = prepare_reforge_target(session)
	check(reforge_target != null, "正常掉落池准备到合法重铸目标")
	if reforge_target != null:
		var service: ReforgeService = ReforgeService.new(inventory, true)
		var preview: Dictionary = service.preview(reforge_target.id, 0)
		var materials_before: int = inventory.materials
		var reforge_result: Dictionary = service.reforge(reforge_target.id, 0, "p1-task6-reforge")
		check(bool(reforge_result.get("ok", false)) and reforge_target.reforge_index == 0, "拆解所得材料完成真实重铸并固定位置")
		check(inventory.materials == materials_before - int(preview.get("cost", 0)), "重铸只扣除预览中的材料费用")

	var save_result: SaveResult = SaveManager.save_game(session, self, 1, "p1_task6_integration")
	check(save_result.ok, "正式 SaveManager 入口写入 D1 集成检查点")
	var loaded: SaveResult = SaveManager.load_game(session.group_id, "manual_01")
	check(loaded.ok and loaded.value.modules.character.minimum_quality == 2, "检查点读回保留过滤偏好")
	if loaded.ok:
		check(loaded.value.inventory.loadout.slots.main == "sweep" and loaded.value.inventory.loadout.slots.auxiliary == "warcry", "检查点读回保留技能装配")
		check(loaded.value.inventory.loadout.passives.has("might") and loaded.value.inventory.loadout.passives.has("precision"), "检查点读回保留被动选择")
		var restored_locked: ItemInstanceResource = loaded.value.inventory.data.instances.get(locked.id)
		check(restored_locked != null and restored_locked.locked, "检查点读回保留锁定状态")
		if reforge_target != null:
			var restored_reforge: ItemInstanceResource = loaded.value.inventory.data.instances.get(reforge_target.id)
			check(restored_reforge != null and restored_reforge.reforge_index == 0, "检查点读回保留固定重铸位置")

	print("P1_D1_INTEGRATION_RESULT: %d failures; %d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
