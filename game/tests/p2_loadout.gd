extends Node
## D2 正式 Hub 装配、十被动取舍、Resource 文件往返、真实输入与离场清理。
var failures: int = 0
var checks: int = 0

## 测试驱动在场景切换和暂停时保持有效。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

## 输出规则断言和定位信息。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 等待场景路由初始化完成。
func frames() -> void:
	for index: int in range(5):
		await get_tree().process_frame

## 发送正式物理键输入，保持到下一物理帧。
func key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().process_frame

## 发送真实左键输入，沿正式基础槽读取路径触发。
func mouse(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().physics_frame
	await get_tree().process_frame

## 从正常 Hub 页面接入新内容，再重新加载正式检查点验证无动作残留。
func _run() -> void:
	SceneRouter.start_session()
	await frames()
	var hub: Control = get_tree().current_scene
	hub.hud.show_page("loadout")
	check(LoadoutState.SKILLS.size() == 6 and LoadoutState.PASSIVES.size() == 10, "内容达到六主动技能和十被动")
	check(hub.hud.loadout_page.passive_buttons.size() == 10, "正式 Hub 生成十个可选择被动按钮")
	for slot: String in ["basic", "main", "auxiliary"]:
		check(hub.hud.loadout_page.skill_choices[slot].item_count == 3, "技能槽各有空槽和两个合法技能：" + slot)
	var old_version: int = hub.game_session.modules.character.module_version
	hub.loadout_action("skill", "sweep", "main")
	hub.loadout_action("passive", "might")
	check(SaveManager.save_game(hub.game_session, hub, 1).ok, "已有 D1 装配建立真实检查点")
	var group: String = hub.game_session.group_id
	var old: SaveResult = SaveManager.load_game(group, "manual_01")
	check(old.ok and old.value.inventory.loadout.slots.main == "sweep" and old.value.inventory.loadout.passives.has("might"), "既有技能和被动文件往返保留")
	hub.loadout_action("reset")
	hub.hud.loadout_page.skill_requested.emit("basic", "heavy")
	hub.hud.loadout_page.skill_requested.emit("auxiliary", "charge")
	hub.hud.loadout_page.passive_requested.emit("momentum")
	hub.hud.loadout_page.passive_requested.emit("heavy_hand")
	hub.hud.loadout_page.passive_requested.emit("bulwark")
	check(is_equal_approx(hub.inventory.build().charge_damage_multiplier, 1.5) and is_equal_approx(hub.inventory.build().heavy_damage_multiplier, 1.35), "两个专属被动只影响各自技能倍率")
	check(hub.inventory.defense("armor") == 35.0 and hub.inventory.build().move_speed_mps == 6.0, "重甲同时增加护甲并降低移动速度")
	hub.hud.loadout_page.passive_requested.emit("breath")
	check(hub.inventory.loadout.passives.size() == 3 and not hub.inventory.loadout.passives.has("breath"), "十被动仍保持最多同时选择三项")
	hub.hud.loadout_page.passive_requested.emit("bulwark")
	hub.hud.loadout_page.passive_requested.emit("breath")
	check(hub.inventory.defense("armor") == 15.0 and hub.inventory.build().move_speed_mps == 7.0, "取消重甲同时移除收益和代价")
	check(hub.inventory.defense("max_health") == 260.0 and hub.inventory.build().idle_energy_regen == 26.0, "换息用生命上限换取闲置回能")
	for id: String in ["momentum", "heavy_hand", "bulwark", "breath"]:
		check(not LoadoutState.passive(id).describe().is_empty(), "新被动说明从真实参数生成：" + id)
	check(LoadoutState.skill("heavy").describe(hub.inventory.build()).contains("前摇") and LoadoutState.skill("charge").describe(hub.inventory.build()).contains("撞地形"), "技能说明包含动作规则与碰撞边界")
	check(SaveManager.save_game(hub.game_session, hub, 2).ok, "冲锋重击与新被动写入真实 Hub 检查点")
	var loaded: SaveResult = SaveManager.load_game(group, "manual_02")
	check(loaded.ok and loaded.value.inventory.loadout.slots.basic == "heavy" and loaded.value.inventory.loadout.slots.auxiliary == "charge" and loaded.value.inventory.loadout.passives.has("breath"), "新装配读取恢复全部稳定 ID")
	check(loaded.value.modules.character.module_version == old_version, "持久结构未变化，character 模块版本保持")
	hub.request_transition("depart")
	await frames()
	var arena: Node3D = get_tree().current_scene
	arena.encounters.clear()
	arena.player.set_physics_process(false)
	arena.player.restore_position(Vector3(0, 0.05, 0))
	arena.player.visual_root.rotation = Vector3.ZERO
	await frames()
	check(arena.skills.loadout.slots.basic == "heavy" and arena.player.max_health == 260.0, "正式出发重建重击装配与生存取舍")
	await mouse(true)
	await mouse(false)
	check(arena.skills.heavy.phase == HeavyAttack.Phase.WINDUP, "真实左键启动重击前摇")
	var before: float = arena.skills.heavy.remaining_sec
	arena.show_inventory()
	for index: int in range(8):
		await get_tree().physics_frame
	check(arena.skills.heavy.remaining_sec == before, "打开背包暂停保留重击前摇")
	arena.toggle_inventory()
	arena.player.set_physics_process(true)
	await key(KEY_SPACE, true)
	await key(KEY_SPACE, false)
	check(arena.skills.heavy.phase == HeavyAttack.Phase.IDLE, "真实空格输入取消重击并闪避")
	arena.player.set_physics_process(false)
	arena.player.restore_position(Vector3(0, 0.05, 0))
	await key(KEY_F, true)
	await key(KEY_F, false)
	check(arena.player.charge_remaining_m > 0.0 and arena.skills.charge.cooldown_sec > 0.0, "真实 F 输入启动已装配冲锋")
	check(arena.get_node("Interface/Hud/Rows/Keys").text.contains("冲锋"), "探险 HUD 展示实际技能名称")
	arena.return_to_town()
	await frames()
	hub = get_tree().current_scene
	check(hub.is_hub() and hub.inventory.loadout.slots.basic == "heavy", "冲锋中撤离进入真实 Hub 并保留长期装配")
	check(SceneRouter.load_game(group, "manual_02").ok, "从手动文件重新加载角色")
	await frames()
	hub = get_tree().current_scene
	hub.request_transition("depart")
	await frames()
	arena = get_tree().current_scene
	check(arena.player.charge_remaining_m == 0.0 and arena.skills.charge.cooldown_sec == 0.0 and arena.skills.charge.combo_remaining_sec == 0.0 and arena.skills.heavy.phase == HeavyAttack.Phase.IDLE and not arena.player.attack_locked, "重启后新探险没有冲锋、前摇、恢复期或增益残留")
	arena.queue_free()
	await frames()
	get_tree().paused = false
	print("P2_LOADOUT_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
