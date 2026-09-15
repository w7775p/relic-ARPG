class_name HubHUD
extends Control
## 据点 UI 总控：组合独立页面、处理页面切换和跨模块协调；业务事务仍由 HubController 与服务层负责。

signal reforge_opened(item_id: String)
signal reforge_closed
signal reforged(item_id: String)

var controller: Node
var inventory: InventoryState
var salvage_service: SalvageService
var reforge_service: ReforgeService
var inventory_panel: BackpackPage
var salvage_button: Button
var salvage_info: Label
var reforge_entry_button: Button
var reforge_button: Button
var reforge_info: Label
var reforge_selector: OptionButton
var _return_item_id: String = ""
var _current_page: String = "backpack"

@onready var navigation: HBoxContainer = $Content/Navigation
@onready var pages: Control = $Content/Pages
@onready var backpack_page: BackpackPage = $Content/Pages/BackpackPage
@onready var equipment_page: EquipmentPage = $Content/Pages/EquipmentPage
@onready var stash_page: StashPage = $Content/Pages/StashPage
@onready var loadout_page: LoadoutPage = $Content/Pages/LoadoutPage
@onready var reforge_page: ReforgePage = $Content/Pages/ReforgePage

## 绑定业务对象并初始化各独立页面；HubHUD 只负责集成和协调。
func setup(owner: Node, state: InventoryState, salvage: SalvageService, reforge: ReforgeService) -> void:
	controller = owner
	inventory = state
	salvage_service = salvage
	reforge_service = reforge
	backpack_page.setup(inventory)
	equipment_page.setup(inventory)
	stash_page.setup(inventory)
	loadout_page.setup(inventory)
	reforge_page.setup(inventory, reforge_service)
	backpack_page.action_requested.connect(_on_backpack_action_requested)
	backpack_page.salvage_requested.connect(_on_salvage_requested)
	backpack_page.reforge_requested.connect(open_reforge)
	backpack_page.selection_changed.connect(_on_backpack_selection_changed)
	backpack_page.close_requested.connect(toggle_inventory)
	equipment_page.unequip_requested.connect(_on_unequip_requested)
	stash_page.retrieve_requested.connect(_on_retrieve_requested)
	loadout_page.skill_requested.connect(_on_skill_requested)
	loadout_page.passive_requested.connect(_on_passive_requested)
	loadout_page.reset_requested.connect(_on_reset_requested)
	reforge_page.closed.connect(_on_reforge_closed)
	reforge_page.reforged.connect(_on_reforged)
	# 保留少量兼容别名供现有回归使用；新功能只依赖公开页面接口。
	inventory_panel = backpack_page
	salvage_button = backpack_page.salvage_button
	salvage_info = backpack_page.salvage_info
	reforge_entry_button = backpack_page.reforge_button
	reforge_button = reforge_page.action_button
	reforge_info = reforge_page.preview_label
	reforge_selector = reforge_page.position_selector
	_show_page("backpack")
	refresh()

## 切换四个据点主页面；同一时刻只展示一个模块。
func _show_page(page_id: String) -> void:
	_current_page = page_id
	navigation.show()
	backpack_page.visible = page_id == "backpack"
	equipment_page.visible = page_id == "equipment"
	stash_page.visible = page_id == "stash"
	loadout_page.visible = page_id == "loadout"
	reforge_page.hide()
	match page_id:
		"backpack": backpack_page.refresh()
		"equipment": equipment_page.refresh()
		"stash": stash_page.refresh()
		"loadout": loadout_page.refresh()
	_refresh_backpack_services()

## 背包页服务状态由总控根据业务服务统一刷新。
func _refresh_backpack_services() -> void:
	if backpack_page == null:
		return
	var item_id: String = backpack_page.selected_item_id()
	if item_id.is_empty() or not inventory.data.instances.has(item_id):
		backpack_page.set_service_state(0, false, false)
		return
	var item: ItemInstanceResource = inventory.data.instances[item_id]
	var materials: int = SalvageService.RULES.materials_for(item)
	var salvage_preview: Dictionary = salvage_service.preview(item_id)
	var reforge_enabled: bool = not item.locked and not item.affixes.is_empty() and (item.quality == 1 or item.quality == 2)
	var restriction: String = "｜当前锁定，需先解锁" if item.locked else ""
	backpack_page.set_service_state(materials, bool(salvage_preview.get("ok", false)), reforge_enabled, restriction)

## 常规背包操作交给 HubController 的公开业务入口。
func _on_backpack_action_requested(action: String, index: int) -> void:
	var message: String = controller.inventory_action(action, 0, index)
	if action == "depart":
		return
	refresh()
	backpack_page.set_message(message)

## 装备页只提交卸下索引。
func _on_unequip_requested(index: int) -> void:
	var message: String = controller.inventory_action("unequip", 1, index)
	refresh()
	equipment_page.set_message(message)

## 仓库页只提交取回索引。
func _on_retrieve_requested(index: int) -> void:
	var message: String = controller.inventory_action("retrieve", 2, index)
	refresh()
	stash_page.set_message(message)

## 技能页把稳定技能 ID 交给 HubController 校验。
func _on_skill_requested(slot: String, skill_id: String) -> void:
	var message: String = controller.loadout_action("skill", skill_id, slot)
	refresh()
	loadout_page.set_message(message)

## 被动页只提交稳定被动 ID。
func _on_passive_requested(passive_id: String) -> void:
	var message: String = controller.loadout_action("passive", passive_id)
	refresh()
	loadout_page.set_message(message)

## 免费重置由 HubController 统一提交。
func _on_reset_requested() -> void:
	var message: String = controller.loadout_action("reset")
	refresh()
	loadout_page.set_message(message)

## 拆解按稳定实例 ID 提交给服务层。
func _on_salvage_requested(item_id: String) -> void:
	var result: Dictionary = salvage_service.salvage(item_id)
	refresh()
	backpack_page.set_message(str(result.get("message", "拆解未完成")))

## 背包选择变化后只更新本页服务按钮。
func _on_backpack_selection_changed(_item_id: String) -> void:
	_refresh_backpack_services()

## 返回当前背包选中物品的稳定实例 ID。
func selected_item_id() -> String:
	return backpack_page.selected_item_id()

## 打开当前背包选中装备的独立重铸页面。
func open_selected_reforge() -> void:
	var item_id: String = selected_item_id()
	if item_id.is_empty():
		backpack_page.set_message("重铸失败：请先在背包选择魔法或稀有装备")
		return
	open_reforge(item_id)

## 以稳定实例 ID 切换到独立重铸页面。
func open_reforge(item_id: String) -> void:
	_return_item_id = item_id
	navigation.hide()
	backpack_page.hide()
	equipment_page.hide()
	stash_page.hide()
	loadout_page.hide()
	reforge_page.open_item(item_id)
	reforge_opened.emit(item_id)

## 隐藏页也可准备预览，兼容现有自动回归而不影响实际页面切换。
func prime_reforge_from_selection() -> void:
	var item_id: String = selected_item_id()
	if not item_id.is_empty():
		reforge_page.prepare_item(item_id)

## 重铸页关闭后返回背包，并按稳定 ID 恢复选择。
func _on_reforge_closed() -> void:
	backpack_page.selected = inventory.data.bag_ids.find(_return_item_id)
	_show_page("backpack")
	reforge_closed.emit()

## 重铸成功后刷新所有可能受属性影响的页面。
func _on_reforged(item_id: String) -> void:
	_return_item_id = item_id
	backpack_page.selected = inventory.data.bag_ids.find(item_id)
	backpack_page.refresh()
	equipment_page.refresh()
	loadout_page.refresh()
	_refresh_backpack_services()
	reforged.emit(item_id)

## 兼容现有回归入口：刷新背包服务按钮。
func refresh_inventory_actions() -> void:
	backpack_page.refresh()
	_refresh_backpack_services()

## 刷新全部据点模块；每个页面自行维护内部布局。
func refresh() -> void:
	if inventory == null:
		return
	backpack_page.refresh()
	equipment_page.refresh()
	stash_page.refresh()
	loadout_page.refresh()
	_refresh_backpack_services()
	if reforge_page.visible:
		reforge_page.refresh()

## I 键处理整备显隐；重铸页中先返回背包。
func toggle_inventory() -> void:
	if reforge_page.visible:
		reforge_page.close_page()
		return
	var next_visible: bool = not pages.visible
	pages.visible = next_visible
	navigation.visible = next_visible
	if next_visible:
		_show_page(_current_page)

## Esc 优先关闭子页面，再关闭整备主页面。
func handle_back() -> bool:
	if reforge_page.visible:
		reforge_page.close_page()
		return true
	if pages.visible:
		pages.hide()
		navigation.hide()
		return true
	return false

## 判断当前是否有据点整备页面占用输入。
func content_visible() -> bool:
	return pages.visible

## 导航按钮只调用总控页面切换。
func _on_backpack_nav_pressed() -> void:
	_show_page("backpack")

func _on_equipment_nav_pressed() -> void:
	_show_page("equipment")

func _on_stash_nav_pressed() -> void:
	_show_page("stash")

func _on_loadout_nav_pressed() -> void:
	_show_page("loadout")
