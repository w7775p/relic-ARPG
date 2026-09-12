extends Node
## 装配集成回归：Hub 服务、属性重建、Resource 往返和战斗只读规则。
var failures: int = 0
var checks: int = 0

## 测试驱动独立于被路由切换的实际场景。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

## 记录规则断言。
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

## 等待路由与场景初始化完成。
func frames() -> void:
	for index: int in range(4):
		await get_tree().process_frame

## 在正式 Hub 调整，再进入真实探险验证施放与属性。
func _run() -> void:
	SceneRouter.start_session()
	await frames()
	var hub: Control = get_tree().current_scene
	var inventory: InventoryState = hub.inventory
	var damage: float = inventory.build().damage
	for id: String in ["might", "precision", "reach"]:
		hub.loadout_action("passive", id)
	check(is_equal_approx(inventory.build().damage, damage + 6) and is_equal_approx(inventory.build().critical_chance, 0.15) and is_equal_approx(inventory.build().whirlwind_radius_m, 3.1), "被动与装备叠加伤害、暴击与范围")
	hub.panel._on_tab(3)
	hub.panel._on_loadout("passive", "vitality")
	check(inventory.loadout.passives.size() == 3 and hub.panel.hint.text.contains("最多"), "第四项被动拒绝且界面说明原因")
	hub.loadout_action("reset")
	check(is_equal_approx(inventory.build().damage, damage) and is_equal_approx(inventory.build().critical_chance, 0.1), "重置被动恢复基础属性")
	for id: String in ["vitality", "guard", "recovery"]:
		hub.loadout_action("passive", id)
	check(inventory.defense("max_health") == 360 and inventory.defense("armor") == 30 and inventory.build().idle_energy_regen == 24, "生命、护甲与回复三个被动正确汇总")
	check(hub.loadout_action("skill", "whirlwind", "basic").contains("不匹配"), "技能拒绝装入错误槽位")
	hub.loadout_action("skill", "", "basic")
	hub.loadout_action("skill", "", "main")
	check(SaveManager.save_game(hub.game_session, hub, 1).ok, "非默认装配写入 Resource 手动槽")
	var group: String = hub.game_session.group_id
	var loaded: SaveResult = SaveManager.load_game(group, "manual_01")
	check(loaded.ok and loaded.value.inventory.loadout.slots.main == "" and loaded.value.inventory.loadout.passives.has("vitality"), "文件往返保持空槽与被动")
	var registry: SaveModuleRegistry = SaveModuleRegistry.standard()
	for kind: String in ["duplicate", "unknown", "slot"]:
		var bad: SaveGameResource = hub.game_session.capture("test")
		var character: CharacterResource = bad.modules[0]
		match kind:
			"duplicate": character.loadout.passives.assign(["might", "might"])
			"unknown": character.loadout.passives.assign(["missing"])
			"slot": character.loadout.slots.auxiliary = "primary"
		check(not registry.prepare(bad).ok, "损坏装配拒绝：" + kind)
	hub.request_transition("depart")
	await frames()
	var arena: Node3D = get_tree().current_scene
	get_tree().paused = true
	check(arena.player.max_health == 360 and arena.player.armor == 30 and arena.skills.build.idle_energy_regen == 24, "进入探险从长期角色数据重建真实属性")
	arena.skills.primary_requested = true
	arena.skills.channel_requested = true
	var before: int = arena.combat._next_attack_id
	arena.skills.advance(0.5)
	check(arena.combat._next_attack_id == before and not arena.skills.is_channeling, "空槽不会产生普攻或旋风")
	check(arena.loadout_action("passive", "might").contains("据点") and arena.loadout_action("reset").contains("据点"), "探险业务入口拒绝装配修改")
	arena.player.health = 100
	arena.skills.energy = 21
	arena.skills._attack_remaining = 0.19
	arena._on_inventory_changed()
	check(arena.player.health == 100 and arena.skills.energy == 21 and arena.skills._attack_remaining == 0.19, "战斗属性重算保留当前生命、能量与技能间隔")
	arena.skills.energy = 101
	arena._on_inventory_changed()
	check(arena.skills.energy == 100, "属性重算钳制能量上限")
	arena.return_to_town()
	await frames()
	hub = get_tree().current_scene
	hub.loadout_action("skill", "primary", "basic")
	hub.request_transition("depart")
	await frames()
	arena = get_tree().current_scene
	get_tree().paused = true
	arena.skills.primary_requested = true
	before = arena.combat._next_attack_id
	arena.skills.advance(0.5)
	check(arena.combat._next_attack_id > before, "Hub 重新装配普攻后恢复真实施放")
	arena.queue_free()
	await frames()
	get_tree().paused = false
	print("P1_LOADOUT_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
