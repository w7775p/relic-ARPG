extends Node
## M2 集成回归：随机装备、容量归属、换装、掉落成长、连续探险与检查点收益。
const ARENA: PackedScene = preload("res://world/maps/expedition_runtime.tscn")
var failures: int = 0
var checks: int = 0

## 延迟启动，确保自动加载服务已准备。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

## 记录失败并保持全部检查可见。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 等待延迟回收，无论当前世界是否暂停。
func frames(count: int = 2) -> void:
	for index: int in range(count):
		await get_tree().process_frame

## 测试真实输入、持有事务和真实场景切换后的收益。
func _run() -> void:
	var generator: ItemGenerator = ItemGenerator.new()
	generator.rng.seed = 8912
	var ids: Dictionary = {}
	var legal: bool = true
	for index: int in range(1000):
		var generated: ItemInstanceResource = generator.generate(1 + index % 6, index % 5 == 0)
		legal = generated.validate().ok and not ids.has(generated.id) and legal
		ids[generated.id] = true
		var groups: Array[String] = []
		for roll: AffixRollResource in generated.affixes:
			var affix: AffixDefinition = ItemCatalog.affix(roll.id)
			legal = legal and affix.min_level <= generated.level and affix.slots.has(ItemCatalog.base(generated.base).slot) and not groups.has(affix.group) and roll.value >= affix.minimum - 0.001 and roll.value <= affix.maximum + 0.001
			groups.append(affix.group)
	check(legal and ids.size() == 1000, "一千次抽取满足品质条数、等级、互斥和唯一实例编号")
	var item: ItemInstanceResource = generator.generate(3)
	var copy: ItemInstanceResource = item.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	copy.locked = true
	check(not item.locked, "实例修改不会污染其他装备")
	var state: int = generator.rng.state
	var counter: int = generator.next_id
	var expected: ItemInstanceResource = generator.generate(3, true)
	generator.rng.state = state
	generator.next_id = counter
	check(ResourceFingerprint.digest(generator.generate(3, true)) == ResourceFingerprint.digest(expected), "独立随机状态与实例计数能复现下一次掉落")
	var inv: InventoryState = InventoryState.new()
	var original: float = inv.build().damage
	for index: int in range(3):
		inv.pickup(generator.generate(3, true, ["thunder_ring", "ember_mail", "energy_grips"][index]))
		inv.equip(inv.bag.size() - 1)
	check(inv.build().chain_count == 5 and inv.build().death_explosion and inv.build().hit_energy >= 3.0, "三件独特装备组成雷霆旋风循环")
	inv.unequip("ring")
	check(inv.build().chain_count == 0 and inv.build().death_explosion, "卸下戒指只移除连锁机制")
	inv.unequip("body")
	inv.unequip("hands")
	check(is_equal_approx(inv.build().damage, original) and not inv.build().death_explosion and is_zero_approx(inv.build().hit_energy), "全部卸下恢复基础属性与触发")
	inv.toggle_lock(0)
	check(not inv.sell(0) and inv.discard(0) == null, "锁定物品阻止出售与丢弃")
	inv.toggle_lock(0)
	var price: int = ItemGenerator.price(inv.bag[0])
	check(inv.sell(0) and inv.gold == price, "出售删除实例并按显示价格入账")
	check(inv.transfer(0, true) and inv.stash.size() == 1 and inv.transfer(0, false), "仓库转移与取回保持唯一归属")
	while inv.bag.size() < 40:
		inv.pickup(generator.generate(1))
	check(not inv.pickup(generator.generate(1)), "满包拒绝拾取")
	inv.equip(0)
	inv.pickup(generator.generate(1))
	var slot: String = inv.equipment.keys()[0]
	check(not inv.unequip(slot), "满包拒绝卸下且保留已装备实例")
	var arena: Node3D = ARENA.instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await frames()
	get_tree().paused = true
	check(arena.combat.enemies.size() == 48 and not arena.is_hub(), "新探险生成三类怪群和一名精英")
	var gold: int = arena.inventory.gold
	arena.add_drop("gold", arena.player.position, null, 17)
	get_tree().paused = false
	arena._process(0.01)
	get_tree().paused = true
	check(arena.inventory.gold == gold + 17, "金币接近自动拾取")
	var unique: ItemInstanceResource = arena.generator.generate(3, true, "thunder_ring")
	arena.add_drop("item", arena.player.position, unique)
	check(arena.pickup_selected(), "地面真实装备进入背包")
	var health: float = arena.player.health - 40
	arena.player.health = health
	arena.skills.energy = 21
	arena.inventory.equip(0)
	check(arena.skills.build.chain_count == 5 and arena.player.health == health and arena.skills.energy == 21, "换装立即启用连锁且保留生命能量")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_I
	key.pressed = true
	arena._unhandled_input(key)
	check(arena.panel.visible and get_tree().paused, "I 键打开背包并暂停世界")
	arena.panel._on_tab(1)
	arena.panel._on_selected(0)
	check(arena.panel.left_text.text.contains("选中物品") and arena.panel.right_text.text.contains("当前穿戴"), "背包显示选中物品和同部位装备对照")
	arena._unhandled_input(key)
	check(not arena.panel.visible and not get_tree().paused, "I 键关闭背包并恢复世界")
	get_tree().paused = true
	arena.show_inventory()
	arena.panel.items.grab_focus()
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	await frames()
	check(not arena.panel.visible and not get_tree().paused, "列表拥有焦点时真实 I 按键仍可关闭背包")
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	arena._set_paused(true)
	arena.get_node("Interface/Settings").show()
	var escape: InputEventKey = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape.duplicate())
	Input.flush_buffered_events()
	await frames()
	check(not arena.get_node("Interface/Settings").visible and get_tree().paused, "设置界面按 Esc 只关闭设置并保持暂停")
	escape.pressed = false
	Input.parse_input_event(escape.duplicate())
	var rejected: String = arena.inventory_action("sell", 0, 0)
	check(rejected.begins_with("操作失败"), "探险期间服务层拒绝出售")
	var hidden_item: ItemInstanceResource = arena.generator.generate(1)
	hidden_item.quality = 0
	hidden_item.affixes = []
	hidden_item.unique_id = ""
	var hidden_drop: Dictionary = arena.add_drop("item", arena.player.position, hidden_item)
	arena.inventory_action("filter", 0, -1)
	check(not arena.ground_nodes[hidden_drop.id].visible and arena.nearby_items().is_empty(), "过滤隐藏普通装备并移出拾取候选")
	arena.inventory_action("filter", 0, -1)
	arena.inventory_action("filter", 0, -1)
	while arena.inventory.bag.size() < 40:
		arena.inventory.pickup(arena.generator.generate(1))
	check(not arena.pickup_selected() and arena.ground.has(hidden_drop), "满包拾取失败时地面物品完整保留")
	while not arena.inventory.bag.is_empty():
		arena.inventory.discard(0)
	var target: EnemyController = arena.combat.enemies[0]
	var count: int = arena.ground.size()
	arena.combat.hit(target, 100000, &"primary", 10, arena.skills.build)
	var after: int = arena.ground.size()
	arena.combat.hit(target, 100000, &"primary", 10, arena.skills.build)
	check(after > count and arena.ground.size() == after and arena.inventory.experience == 6, "真实击杀产出经验与掉落，重复击杀不再奖励")
	arena.effects.drain(1000000)
	check(arena._request_save() == ERR_UNAVAILABLE, "战斗 F5 提示撤离保存")
	var game: GameSession = arena.game_session
	arena.return_to_town()
	await frames(4)
	var hub: Control = get_tree().current_scene
	check(hub.is_hub() and hub.inventory.equipment.has("ring") and hub.game_session == game, "真实撤离到 Hub 并保留已拾取角色对象")
	for run: int in range(3):
		hub.request_transition("depart")
		await frames(4)
		arena = get_tree().current_scene
		get_tree().paused = true
		for victim: CombatActor in arena.combat.enemies.duplicate():
			arena.combat.hit(victim, 100000, &"primary", 100 + run, arena.skills.build)
		arena.effects.drain(1000000)
		check(arena.wave_completed and arena.inventory.completed == run + 1, "第 %d 趟清场只记一次通关" % (run + 1))
		var found: bool = false
		for drop: Dictionary in arena.ground:
			if drop.kind == "item" and drop.item.unique_id == ["thunder_ring", "ember_mail", "energy_grips"][run]:
				found = true
		check(found, "第 %d 次通关获得对应稳定 ID 独特奖励" % (run + 1))
		arena.return_to_town()
		arena.return_to_town()
		await frames(4)
		hub = get_tree().current_scene
	check(hub.inventory.difficulty == 4 and hub.inventory.level > 1, "连续三趟推进难度与等级，重复撤离不会重复结算")
	hub.request_transition("depart")
	await frames(4)
	arena = get_tree().current_scene
	var owned: String = ResourceFingerprint.digest(arena.game_session.capture("test").modules)
	arena.player.receive_damage(100000)
	await frames(5)
	hub = get_tree().current_scene
	check(hub.is_hub() and ResourceFingerprint.digest(hub.game_session.capture("test").modules) == owned, "死亡真实回据点，已持有装备和成长保持")
	check(SaveManager.save_game(hub.game_session, hub, 1).ok, "据点可以手动保存完整角色检查点")
	hub.queue_free()
	await frames()
	get_tree().paused = false
	print("M2_LOOP_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
