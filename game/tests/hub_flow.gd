extends Node
## 正式路由集成：自动保存边界、据点拆解、一次性交接、读取回退和新探险初始化。
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

## 从主入口建立会话，连续执行据点整备、探险、回退与多角色流程。
func _run() -> void:
	SceneRouter.start_session()
	await frames()
	var hub: Control = get_tree().current_scene
	var session: GameSession = hub.game_session
	var group: String = session.group_id
	check(hub.is_hub() and hub.panel.visible and hub.inventory.equipment.weapon.base == "rust_sword", "新角色进入真实 Hub 并只生成一次起装")
	check(hub.panel.get_global_rect().end.y <= hub.hud.toolbar.get_global_rect().position.y, "据点整备内容与 HUD 底部存档操作区保持分离")
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
	hub.panel.source = 0
	hub.panel.selected = hub.inventory.data.bag_ids.find(generated.id)
	hub.panel.refresh()
	hub._refresh_salvage_ui()
	check(hub.salvage_info.text.contains("出售") and hub.salvage_info.text.contains("拆解") and not hub.salvage_button.disabled, "Hub 背包选中装备并列显示出售与拆解收益")

	var salvage_target: ItemInstanceResource = hub.generator.generate(4, true)
	hub.inventory.pickup(salvage_target)
	var salvage_id: String = salvage_target.id
	var salvage_before: int = hub.inventory.materials
	var salvage_preview: Dictionary = hub.salvage_preview(salvage_id)
	check(bool(salvage_preview.ok) and int(salvage_preview.materials) == SalvageService.RULES.materials_for(salvage_target), "真实 Hub 拆解预览与集中规则一致")
	check(bool(hub.salvage_item(salvage_id).ok) and hub.inventory.materials == salvage_before + int(salvage_preview.materials) and not hub.inventory.data.instances.has(salvage_id), "真实 Hub 拆解删除目标实例并增加一次材料")

	var sell_target: ItemInstanceResource = hub.generator.generate(3, false)
	hub.inventory.pickup(sell_target)
	var sell_id: String = sell_target.id
	var sell_value: int = ItemGenerator.price(sell_target)
	var gold_before_sale: int = hub.inventory.gold
	check(hub.inventory_action("sell", 0, hub.inventory.data.bag_ids.find(sell_id)) == "操作完成" and hub.inventory.gold == gold_before_sale + sell_value and not hub.inventory.data.instances.has(sell_id), "出售继续作为独立金币来源")

	var stash_target: ItemInstanceResource = hub.generator.generate(3, false)
	hub.inventory.pickup(stash_target)
	var stash_id: String = stash_target.id
	check(hub.inventory_action("store", 0, hub.inventory.data.bag_ids.find(stash_id)) == "操作完成" and hub.inventory.data.stash_ids.has(stash_id), "拆解与出售后仍可把指定实例移入仓库")
	var saved_gold: int = hub.inventory.gold
	var saved_materials: int = hub.inventory.materials

	hub._on_save_pressed()
	check(hub.slots.visible and hub.slots.saving, "Hub 手动保存打开明确槽位选择")
	await frames(2)
	check(hub.slots.get_global_rect().size == hub.get_viewport_rect().size and hub.slots.get_node("Rows/Slots").size.y > 100, "槽位面板覆盖底层输入区域并为存档列表保留可用高度")
	hub.slots._on_cancel_pressed()
	check(SaveManager.save_game(session, hub, 1).ok, "选定手动槽保存拆解、出售和仓库后的完整状态")
	var saved: SaveResult = SaveManager.load_game(group, "manual_01")
	check(saved.ok and saved.value.inventory.gold == saved_gold and saved.value.inventory.materials == saved_materials, "文件读回保持出售金币与拆解材料")
	check(not saved.value.inventory.data.instances.has(salvage_id) and not saved.value.inventory.data.instances.has(sell_id) and saved.value.inventory.data.stash_ids.has(stash_id), "文件读回保持已拆解、已出售和仓库实例归属")

	var manual_sequence: int = sequence(group)
	hub.request_transition("depart")
	await frames()
	var arena: Node3D = get_tree().current_scene
	check(arena.game_session == session and arena.inventory == session.inventory and arena.generator == session.generator, "探险领取同一完整会话与业务入口")
	check(not arena.is_hub() and arena.combat.enemies.size() == 48 and not get_tree().paused and not arena.panel.visible, "正式探险创建完整遭遇并开始运行")
	check(arena.minimum_quality == 2 and arena.skills.loadout.slots.main == "sweep" and arena.inventory.bag[0].id == generated.id, "装配、过滤和物品身份跨场景保持")
	check(arena.inventory_action("sell", 0, 0).begins_with("操作失败"), "探险拒绝据点出售服务")
	var combat_salvage: SalvageService = SalvageService.new(arena.inventory, arena.is_hub())
	var combat_materials: int = arena.inventory.materials
	check(not bool(combat_salvage.salvage(generated.id).ok) and arena.inventory.materials == combat_materials and arena.inventory.data.instances.has(generated.id), "探险拒绝拆解且物品与材料保持")
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
	check(hub.inventory.gold == saved_gold and hub.inventory.materials == saved_materials and sequence(group) == before and hub.game_session != session, "整档回退恢复拆解后的经济状态且加载本身不覆盖较新自动档")
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
