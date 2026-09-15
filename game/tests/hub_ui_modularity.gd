extends Node
## Hub UI 模块化回归：主页面互斥、重铸独立页和返回时稳定实例选择。
var failures: int = 0
var checks: int = 0

## 测试节点保持场景切换期间存活。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

## 等待路由与容器布局完成。
func frames(count: int = 4) -> void:
	for index: int in range(count):
		await get_tree().process_frame

## 记录结构断言。
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 创建固定魔法武器，避免测试依赖随机品质。
func magic_weapon(session: GameSession) -> ItemInstanceResource:
	var item: ItemInstanceResource = ItemInstanceResource.new()
	item.id = str(session.modules.items.next_id)
	item.base = "rust_sword"
	item.level = 1
	item.quality = 1
	item.affixes = [AffixRollResource.create("power", 2.0), AffixRollResource.create("vitality", 10.0)]
	return item

## 从真实 Hub 验证页面边界和重铸跳转。
func _run() -> void:
	SceneRouter.start_session()
	await frames()
	var hub: Control = get_tree().current_scene
	var hud: HubHUD = hub.hud
	var backpack: BackpackPage = hud.backpack_page
	check(backpack.visible and not hud.equipment_page.visible and not hud.stash_page.visible and not hud.loadout_page.visible and not hud.reforge_page.visible, "Hub 默认只展示背包模块")
	var baseline_size: Vector2 = backpack.get_global_rect().size
	var target: ItemInstanceResource = magic_weapon(hub.game_session)
	check(hub.inventory.pickup(target), "可重铸魔法武器进入背包")
	hub.inventory.materials = 20
	backpack.selected = hub.inventory.data.bag_ids.find(target.id)
	backpack.refresh()
	hud.refresh_inventory_actions()
	await frames(2)
	check(backpack.get_global_rect().size == baseline_size and not hud.reforge_page.visible, "选中可重铸装备不会改变背包页面尺寸或注入重铸详情")
	check(not backpack.reforge_button.disabled, "可重铸装备只在背包页开放重铸入口")

	hud.open_selected_reforge()
	await frames(2)
	check(hud.reforge_page.visible and not backpack.visible and not hud.navigation.visible, "点击重铸后独占显示 ReforgePage 并隐藏背包与主导航")
	check(hud.reforge_page.position_selector.item_count == target.affixes.size() and not hud.reforge_page.action_button.disabled, "独立重铸页显示词条位置与可用提交按钮")
	check(hud.reforge_page.get_global_rect().size == hud.pages.get_global_rect().size, "独立重铸页占用固定 PageHost，不挤压其他模块")

	hud.reforge_page.close_page()
	await frames(2)
	check(backpack.visible and hud.navigation.visible and backpack.selected_item_id() == target.id and not hud.reforge_page.visible, "返回重铸页后恢复背包与原稳定实例选择")

	hud.show_page("equipment")
	check(hud.equipment_page.visible and not backpack.visible and not hud.stash_page.visible and not hud.loadout_page.visible, "装备页与其他主页面互斥")
	hud.show_page("stash")
	check(hud.stash_page.visible and not hud.equipment_page.visible, "仓库页独立切换")
	hud.show_page("loadout")
	check(hud.loadout_page.visible and not hud.stash_page.visible, "技能与被动页独立切换")
	hud.show_page("backpack")
	check(backpack.visible and not hud.loadout_page.visible, "背包页可通过总控恢复")

	hub.queue_free()
	await frames()
	print("HUB_UI_MODULARITY_RESULT: %d failures; %d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)