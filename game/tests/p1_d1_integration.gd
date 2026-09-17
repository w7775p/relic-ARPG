extends Node
## P1_Task6 集成回归：过滤、锁定、拆解→重铸、装配、持续伤害与 Hub 检查点串联。
var failures: int = 0
var checks: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

## 记录断言并继续执行剩余场景。
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 等待场景路由、输入与延迟回收完成。
func frames(count: int = 4) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

## 经引擎输入系统派发真实键盘事件。
func press_key(code: Key, unicode: int = 0) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	Input.flush_buffered_events()

## 从正式掉落生成器寻找指定品质，不手写装备属性。
func generated_quality(generator: ItemGenerator, quality: int, level: int = 4) -> ItemInstanceResource:
	for _attempt: int in range(512):
		var item: ItemInstanceResource = generator.generate(level, false)
		if item.quality == quality:
			return item
	return null

## 在真实 Hub 背包里准备有合法候选的魔法/稀有重铸目标。
func prepare_reforge_target(hub: Node) -> ItemInstanceResource:
	for _attempt: int in range(96):
		if hub.inventory.bag.size() >= hub.inventory.data.bag_capacity:
			return null
		var item: ItemInstanceResource = hub.generator.generate(4, false)
		if item.quality != 1 and item.quality != 2:
			continue
		if not hub.inventory.pickup(item):
			continue
		var preview: Dictionary = hub.reforge_preview(item.id, 0)
		if bool(preview.get("ok", false)):
			return item
		var index: int = hub.inventory.data.bag_ids.find(item.id)
		if index >= 0:
			hub.inventory.sell(index)
	return null

## 串起 D1 关键用例，防止单系统各自通过却在正式流程断链。
func _run() -> void:
	check(LoadoutState.SKILLS.size() == 4 and LoadoutState.PASSIVES.size() == 6, "D1 保持四个主动技能与六个被动")
	check(ItemCatalog.BASES.size() == 14 and ItemCatalog.AFFIXES.size() == 18 and ItemCatalog.UNIQUES.size() == 4, "D1 装备额度保持 14/18/4")
	check(EncounterDirector.ELITE_MODIFIERS.size() == 2 and EncounterDirector.VARIANT_IDS.size() == 2, "D1 保持两个精英修饰与两种固定场地变体")

	SceneRouter.start_session()
	await frames(6)
	var hub: Node = get_tree().current_scene
	check(hub != null and hub.is_hub(), "正式入口进入 Hub")
	hub.loadout_action("skill", "sweep", "main")
	hub.loadout_action("skill", "warcry", "auxiliary")
	hub.loadout_action("passive", "might")
	hub.loadout_action("passive", "precision")
	check(hub.inventory.loadout.passives.size() == 2, "据点可选择被动")
	hub.loadout_action("reset")
	check(hub.inventory.loadout.passives.is_empty(), "据点免费重置被动进入同一角色状态")

	var locked: ItemInstanceResource = generated_quality(hub.generator, 1)
	check(locked != null and hub.inventory.pickup(locked), "正常生成的魔法装备进入背包作为锁定目标")
	var locked_index: int = hub.inventory.data.bag_ids.find(locked.id)
	check(hub.inventory_action("lock", 0, locked_index).contains("完成") and locked.locked, "据点入口锁定装备")
	var locked_digest: String = ResourceFingerprint.digest(locked)
	var gold_before_lock: int = hub.inventory.gold
	var materials_before_lock: int = hub.inventory.materials
	check(hub.inventory_action("sell", 0, locked_index).contains("失败") and hub.inventory.gold == gold_before_lock, "锁定装备拒绝出售")
	check(not bool(hub.salvage_item(locked.id).get("ok", false)) and hub.inventory.materials == materials_before_lock, "锁定装备拒绝拆解")
	check(not bool(hub.reforge_item(locked.id, 0, "p1-task6-locked").get("ok", false)), "锁定装备拒绝重铸")
	check(locked.locked and ResourceFingerprint.digest(locked) == locked_digest, "三种失败操作后锁定装备实例保持原值")

	hub.inventory.materials = 0
	var salvage_source: ItemInstanceResource = generated_quality(hub.generator, 2)
	check(salvage_source != null and hub.inventory.pickup(salvage_source), "正常生成的稀有装备进入背包作为拆解来源")
	var salvage_result: Dictionary = hub.salvage_item(salvage_source.id)
	check(bool(salvage_result.get("ok", false)) and hub.inventory.materials > 0, "拆解真实稀有装备获得重铸材料")
	var reforge_target: ItemInstanceResource = prepare_reforge_target(hub)
	check(reforge_target != null, "正常掉落池准备到合法重铸目标")
	if reforge_target != null:
		var preview: Dictionary = hub.reforge_preview(reforge_target.id, 0)
		var material_before_reforge: int = hub.inventory.materials
		var reforge_result: Dictionary = hub.reforge_item(reforge_target.id, 0, "p1-task6-reforge")
		check(bool(reforge_result.get("ok", false)) and reforge_target.reforge_index == 0, "拆解所得材料可完成一次真实重铸并固定位置")
		check(hub.inventory.materials == material_before_reforge - int(preview.get("cost", 0)), "重铸只扣除预览中的材料费用")

	check(hub.inventory_action("filter", 0, -1).contains("完成") and hub.inventory_action("filter", 0, -1).contains("完成") and hub.minimum_quality == 2, "据点过滤入口切到稀有及以上并写入角色模块")
	hub.request_transition("depart")
	await frames(8)
	var arena: Node3D = get_tree().current_scene
	check(arena != null and not arena.is_hub() and arena.minimum_quality == 2, "进入正式探险继承持久过滤偏好")
	arena.encounters.clear()
	arena.player.set_physics_process(false)
	await frames()

	var normal_item: ItemInstanceResource = generated_quality(arena.generator, 0)
	var unique_item: ItemInstanceResource = arena.generator.generate(4, true, "energy_grips")
	var normal_digest: String = ResourceFingerprint.digest(normal_item)
	var normal_drop: Dictionary = arena.add_drop("item", arena.player.global_position, normal_item)
	var unique_drop: Dictionary = arena.add_drop("item", arena.player.global_position + Vector3(0.2, 0, 0), unique_item)
	check(arena.ground.has(normal_drop) and not arena.ground_nodes[normal_drop.id].visible, "稀有过滤隐藏普通装备但保留完整地面条目")
	check(arena.ground.has(unique_drop) and arena.ground_nodes[unique_drop.id].visible and arena.nearby_items().has(unique_drop), "独特装备在最高基础过滤下仍可发现和拾取")

	press_key(KEY_I)
	await frames()
	check(get_tree().paused and arena.panel.visible and arena.panel.hint.text.contains("稀有及以上"), "I 键面板显示当前过滤状态")
	arena.panel.action_buttons["filter"].pressed.emit()
	await frames()
	check(arena.minimum_quality == 0 and arena.ground_nodes[normal_drop.id].visible, "过滤按钮循环回全部后原普通装备重新显示")
	check(ResourceFingerprint.digest(normal_drop.item) == normal_digest and normal_drop.item == normal_item, "重新显示的是同一实例和同一组词条")
	press_key(KEY_I)
	await frames()
	press_key(KEY_TAB)
	await frames()
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.data.instances.get(unique_item.id) == unique_item and not arena.ground.has(unique_drop), "Tab 切换后真实 E 拾取独特装备")
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.data.instances.get(normal_item.id) == normal_item and not arena.ground.has(normal_drop), "真实 E 拾取恢复显示后的同一普通装备")

	arena.inventory_action("filter", 0, -1)
	arena.inventory_action("filter", 0, -1)
	check(arena.minimum_quality == 2, "撤离前过滤偏好恢复为稀有及以上")
	arena.return_to_town()
	await frames(8)
	hub = get_tree().current_scene
	check(hub != null and hub.is_hub() and hub.minimum_quality == 2, "撤离回 Hub 后过滤偏好仍在角色模块")
	var save_result: SaveResult = hub._save_auto("p1_task6_integration")
	check(save_result.ok, "Hub 通过正式自动保存入口写入 D1 集成检查点")
	var slot_id: String = ""
	for entry: SaveSlotResource in SaveManager.store.catalog().slots:
		if entry.group_id == hub.game_session.group_id and entry.checkpoint_id == hub.game_session.saved_checkpoint_id:
			slot_id = entry.slot_id
	var loaded: SaveResult = SaveManager.load_game(hub.game_session.group_id, slot_id)
	check(loaded.ok and loaded.value.modules.character.minimum_quality == 2, "重启式读档保留过滤偏好")
	if loaded.ok:
		check(loaded.value.inventory.data.instances.has(normal_item.id) and loaded.value.inventory.data.instances.has(unique_item.id), "检查点保留本趟真实 E 拾取的装备实例")
		var restored_locked: ItemInstanceResource = loaded.value.inventory.data.instances.get(locked.id)
		check(restored_locked != null and restored_locked.locked, "检查点保留锁定状态")
		if reforge_target != null:
			var restored_reforge: ItemInstanceResource = loaded.value.inventory.data.instances.get(reforge_target.id)
			check(restored_reforge != null and restored_reforge.reforge_index == 0, "检查点保留固定重铸位置")

	hub.request_transition("depart")
	await frames(8)
	arena = get_tree().current_scene
	check(arena.minimum_quality == 2 and arena.ground.is_empty(), "下一趟继承过滤偏好，上一趟未拾取地面状态不会跨探险保留")
	arena.encounters.clear()
	arena.player.set_physics_process(false)
	arena.player.restore_position(Vector3.ZERO)
	arena.player.visual_root.rotation.y = 0.0
	await frames()
	var enemy_definition: EnemyDefinition = EncounterDirector.ELITE.duplicate()
	enemy_definition.health = 500.0
	enemy_definition.damage = 0.0
	enemy_definition.speed_mps = 0.0
	var target: EnemyController = arena.encounters.spawn_enemy(enemy_definition, Vector3(0.0, 0.05, -2.0))
	target.set_physics_process(false)
	arena.skills.energy = 10.0
	var energy_before: float = arena.skills.energy
	check(arena.skills.cast_warcry() and arena.skills.energy > energy_before, "单精英场景战吼真实恢复能量")
	arena.player.health = arena.player.max_health * 0.4
	var health_before: float = arena.player.health
	check(arena.skills.use_potion() and arena.player.health > health_before, "单精英场景药剂按最大生命真实恢复")
	var target_health: float = target.health
	arena.skills.cast_sweep()
	arena.effects.drain(1000)
	check(target.health < target_health and target.bleeds.size() == 1, "流血横扫直接命中并施加一层持续伤害")
	var health_after_hit: float = target.health
	arena.effects.advance_bleeds(SkillRunner.SWEEP.bleed_tick_sec)
	arena.effects.drain(1000)
	check(target.health < health_after_hit and arena.effects.bleed_tick_count > 0, "持续伤害按真实跳伤间隔独立结算")

	arena.queue_free()
	await frames()
	get_tree().paused = false
	print("P1_D1_INTEGRATION_RESULT: %d failures; %d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
