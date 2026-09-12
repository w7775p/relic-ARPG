extends Node
## 正式路由集成：自动保存边界、一次性交接、读取回退和新探险初始化。
var failures: int = 0
var checks: int = 0

## 保留测试驱动节点，让真实主场景由路由替换。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

## 等待延迟切换和保存完成。
func frames(count: int = 4) -> void:
	for index: int in range(count):
		await get_tree().process_frame

## 记录集成断言。
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

## 查询当前角色最新成功序号，判断自动保存是否新增。
func sequence(group: String) -> int:
	var latest: int = 0
	for entry: SaveSlotResource in SaveManager.store.catalog().slots:
		if entry.group_id == group:
			latest = maxi(latest, entry.sequence)
	return latest

## 从主入口建立会话，连续执行据点、探险、回退与多角色流程。
func _run() -> void:
	SceneRouter.start_session()
	await frames()
	var hub: Control = get_tree().current_scene
	var session: GameSession = hub.game_session
	var group: String = session.group_id
	check(hub.is_hub() and hub.panel.visible and hub.inventory.equipment.weapon.base == "rust_sword", "新角色进入真实 Hub 并只生成一次起装")
	check(sequence(group) == 1 and not SceneRouter.has_session_transition(), "新角色自动检查点完成，路由领取后清空会话引用")
	for amount: int in range(1, 6):
		hub.inventory.gold = amount
	check(sequence(group) == 1, "连续据点编辑合并，不在每次点击时写盘")
	await get_tree().create_timer(1.2).timeout
	check(sequence(group) == 2, "一秒去抖后自动保存最终完整状态")
	hub._on_autosave_timeout()
	check(sequence(group) == 2, "无变化保存不占用自动历史")
	hub.loadout_action("skill", "sweep", "main")
	hub.loadout_action("skill", "warcry", "auxiliary")
	hub.minimum_quality = 2
	var generated: ItemInstanceResource = hub.generator.generate(2, true)
	hub.inventory.pickup(generated)
	hub._on_save_pressed()
	check(hub.slots.visible and hub.slots.saving, "Hub 手动保存打开明确槽位选择")
	hub.slots._on_cancel_pressed()
	check(SaveManager.save_game(session, hub, 1).ok, "选定手动槽保存最新整备状态")
	var manual_sequence: int = sequence(group)
	hub.request_transition("depart")
	await frames()
	var arena: Node3D = get_tree().current_scene
	check(arena.game_session == session and arena.inventory == session.inventory and arena.generator == session.generator, "探险领取同一完整会话与业务入口")
	check(not arena.is_hub() and arena.combat.enemies.size() == 48 and not get_tree().paused and not arena.panel.visible, "正式探险创建完整遭遇并开始运行")
	check(arena.minimum_quality == 2 and arena.skills.loadout.slots.main == "sweep" and arena.inventory.bag[0].id == generated.id, "装配、过滤和物品身份跨场景保持")
	check(arena.inventory_action("sell", 0, 0).begins_with("操作失败"), "探险拒绝据点出售服务")
	arena.inventory.gold = 55
	check(arena._request_save() == ERR_UNAVAILABLE and sequence(group) == manual_sequence, "战斗保存请求不产生文件")
	arena.return_to_town()
	arena.return_to_town()
	await frames()
	hub = get_tree().current_scene
	check(hub.game_session == session and hub.inventory.gold == 55 and sequence(group) == manual_sequence + 1, "真实撤离结算后自动保存一次")
	var before: int = sequence(group)
	var failed: SaveResult = SceneRouter.load_game(group, "manual_05")
	check(not failed.ok and get_tree().current_scene == hub and hub.inventory.gold == 55, "缺失槽位加载失败保持当前场景和会话")
	check(SceneRouter.load_game(group, "manual_01").ok, "可以明确选择旧手动槽回退")
	await frames()
	hub = get_tree().current_scene
	await get_tree().create_timer(1.2).timeout
	check(hub.inventory.gold == 5 and sequence(group) == before and hub.game_session != session, "整档回退建立独立会话，加载本身不会覆盖较新自动档")
	var expected: ItemInstanceResource = hub.generator.generate(4, true)
	var loaded: SaveResult = SaveManager.load_game(group, "manual_01")
	check(loaded.ok and ResourceFingerprint.digest(loaded.value.generator.generate(4, true)) == ResourceFingerprint.digest(expected), "Resource 往返保持掉落下一次结果与实例编号")
	hub.request_transition("depart")
	await frames()
	arena = get_tree().current_scene
	arena.inventory.gold = 81
	arena._on_menu_pressed()
	await frames(8)
	check(get_tree().current_scene.scene_file_path == SceneRouter.MAIN_MENU, "正常菜单退出经撤离、Hub 和成功保存后完成")
	var auto: String = ""
	for entry: SaveSlotResource in SaveManager.store.catalog().slots:
		if entry.group_id == group and entry.slot_id.begins_with("auto_"):
			auto = entry.slot_id
			break
	check(SaveManager.load_game(group, auto).value.inventory.gold == 81, "正常退出保留本趟已拾取收益")
	SceneRouter.start_session()
	await frames()
	hub = get_tree().current_scene
	check(hub.game_session.group_id != group and hub.inventory.gold == 0 and hub.inventory.stash.is_empty(), "新角色拥有独立槽位组、余额和仓库")
	hub.queue_free()
	await frames()
	print("HUB_FLOW_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
