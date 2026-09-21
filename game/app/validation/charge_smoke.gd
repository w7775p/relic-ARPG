extends RefCounted
## 源码和成品共用第三构筑验证；只从 --smoke-loot 调用，不进入正常玩家流程。

## 正式 Hub 装配、真实 F/左键攻击、死亡掉落、E 拾取和保存恢复串联。
static func run(probe: Node, hub: Node) -> void:
	probe.check(LoadoutState.SKILLS.size() == 6 and LoadoutState.PASSIVES.size() == 10, "成品六技能十被动目录完整")
	hub.loadout_action("skill", "heavy", "basic")
	hub.loadout_action("skill", "charge", "auxiliary")
	hub.loadout_action("reset")
	for id: String in ["momentum", "heavy_hand", "breath"]:
		hub.loadout_action("passive", id)
	# 留出精英实际掉落的拾取位置；测试准备同样经正式丢弃入口。
	while hub.inventory.bag.size() > 35:
		hub.inventory.discard(0)
	hub.request_transition("depart")
	await probe.frames(8)
	var arena: Node3D = probe.get_tree().current_scene
	arena.encounters.clear()
	arena.player.set_physics_process(false)
	arena.player.restore_position(Vector3(0, 0.05, 0))
	arena.player.visual_root.rotation = Vector3.ZERO
	await probe.frames()
	var definition: EnemyDefinition = EncounterDirector.ELITE.duplicate()
	definition.health = 150.0
	definition.armor = 0.0
	definition.speed_mps = 0.0
	definition.damage = 0.0
	var target: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(0, 0.05, -2.0))
	target.set_physics_process(false)
	await probe.get_tree().physics_frame
	await _key(probe, KEY_F, true)
	await _key(probe, KEY_F, false)
	probe.check(arena.player.charge_remaining_m > 0.0, "成品真实 F 触发冲锋")
	for index: int in range(30):
		arena.player.advance_charge(1.0 / 60.0)
		await probe.get_tree().physics_frame
	probe.check(not target.is_dead and target.health < 150.0 and arena.skills.charge.combo_remaining_sec > 0.0, "成品冲锋命中并获得一次组合增益")
	await _mouse(probe, true)
	await _mouse(probe, false)
	probe.check(arena.skills.heavy.phase == HeavyAttack.Phase.WINDUP, "成品真实左键进入重击前摇")
	for index: int in range(55):
		await probe.get_tree().physics_frame
	probe.check(arena.combat.enemies.is_empty(), "成品组合重击经过前摇击杀精英")
	var reward_id: String = ""
	for drop: Dictionary in arena.ground:
		if drop.kind == "item":
			reward_id = drop.item.id
			break
	probe.check(not reward_id.is_empty(), "成品新技能击杀走统一掉落管线")
	probe.press_key(KEY_E, 101)
	await probe.frames()
	probe.check(arena.inventory.data.instances.has(reward_id), "成品 E 拾取新技能造成的精英掉落")
	arena.return_to_town()
	await probe.frames(8)
	hub = probe.get_tree().current_scene
	probe.check(SaveManager.save_game(hub.game_session, hub, 1, "charge_smoke").ok, "成品冲锋重击返回 Hub 后保存")
	var loaded: SaveResult = SaveManager.load_game(hub.game_session.group_id, "manual_01")
	probe.check(loaded.ok and loaded.value.inventory.loadout.slots.basic == "heavy" and loaded.value.inventory.loadout.slots.auxiliary == "charge" and loaded.value.inventory.loadout.passives.has("breath") and loaded.value.inventory.data.instances.has(reward_id), "成品检查点同时恢复新技能、被动与实际拾取物品")

## 独立按下与释放跨物理帧，保证 just_pressed 输入得到处理。
static func _key(probe: Node, code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await probe.get_tree().physics_frame
	await probe.frames(1)

## 实际左键输入由 SkillRunner 读取当前基础槽。
static func _mouse(probe: Node, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await probe.get_tree().physics_frame
	await probe.frames(1)
