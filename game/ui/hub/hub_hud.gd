class_name HubHUD
extends Control
## 据点 UI 总控：组合整备页面并协调页面切换，业务规则由各服务和 InventoryState 负责。

signal reforge_opened(item_id: String)
signal reforge_closed
signal reforged(item_id: String)

var controller: Node
var inventory: InventoryState
var salvage_service: SalvageService
var reforge_service: ReforgeService
var inventory_panel: InventoryPanel
var salvage_button: Button
var salvage_info: Label
var reforge_entry_button: Button
var reforge_button: Button
var reforge_info: Label
var reforge_selector: OptionButton
var _return_item_id: String = ""

@onready var page_host: Control = $PageHost
@onready var reforge_page: ReforgePage = $PageHost/ReforgePage

## 绑定据点控制器与业务服务，并挂载当前遗留整备面板。
func setup(owner: Node, state: InventoryState, salvage: SalvageService, reforge: ReforgeService) -> void:
	controller = owner
	inventory = state
	salvage_service = salvage
	reforge_service = reforge
	inventory_panel = InventoryPanel.new()
	inventory_panel.session = controller
	page_host.add_child(inventory_panel)
	page_host.move_child(inventory_panel, 0)
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.offset_left = 0
	inventory_panel.offset_top = 0
	inventory_panel.offset_right = 0
	inventory_panel.offset_bottom = 0
	inventory_panel.show()
	inventory_panel.refresh()
	_setup_inventory_actions()
	reforge_page.setup(inventory, reforge_service)
	reforge_page.closed.connect(_on_reforge_closed)
	reforge_page.reforged.connect(_on_reforged)
	reforge_page.hide()
	reforge_button = reforge_page.action_button
	reforge_info = reforge_page.preview_label
	reforge_selector = reforge_page.position_selector

## 给背包页追加轻量处置操作；复杂重铸详情留在独立页面。
func _setup_inventory_actions() -> void:
	salvage_button = Button.new()
	salvage_button.text = "拆解"
	salvage_button.pressed.connect(_on_salvage_pressed)
	inventory_panel.inventory_actions.add_child(salvage_button)
	reforge_entry_button = Button.new()
	reforge_entry_button.text = "重铸"
	reforge_entry_button.pressed.connect(_on_reforge_entry_pressed)
	inventory_panel.inventory_actions.add_child(reforge_entry_button)
	salvage_info = Label.new()
	salvage_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rows: Node = inventory_panel.hint.get_parent()
	rows.add_child(salvage_info)
	rows.move_child(salvage_info, inventory_panel.hint.get_index())
	inventory_panel.items.item_selected.connect(_on_inventory_selection_changed)
	inventory_panel.tabs.item_selected.connect(_on_inventory_tab_changed)
	refresh_inventory_actions()

## 主页面刷新后同步拆解收益与重铸入口可用性。
func refresh_inventory_actions() -> void:
	if inventory_panel == null or salvage_button == null or reforge_entry_button == null:
		return
	var values: Array = inventory_panel.entries()
	var valid: bool = inventory_panel.source == 0 and inventory_panel.selected >= 0 and inventory_panel.selected < values.size()
	salvage_button.disabled = not valid
	reforge_entry_button.disabled = true
	if not valid:
		salvage_info.text = "据点处置：在背包选择装备后，可比较出售金币与拆解材料收益。"
		return
	var item: ItemInstanceResource = values[inventory_panel.selected]
	var materials: int = SalvageService.RULES.materials_for(item)
	var restriction: String = "｜当前锁定，需先解锁" if item.locked else ""
	salvage_info.text = "据点处置收益：出售 %d 金｜拆解 %d 材料%s" % [ItemGenerator.price(item), materials, restriction]
	reforge_entry_button.disabled = item.locked or item.affixes.is_empty() or (item.quality != 1 and item.quality != 2)

## 选中物品改变后只刷新当前模块入口，不向背包页注入复杂子页面。
func _on_inventory_selection_changed(_index: int) -> void:
	refresh_inventory_actions()

## 切换背包/装备/仓库/装配页后延迟读取刷新后的选择状态。
func _on_inventory_tab_changed(_index: int) -> void:
	refresh_inventory_actions.call_deferred()

## 按稳定实例 ID 执行拆解，并保持背包页为当前页面。
func _on_salvage_pressed() -> void:
	var item_id: String = selected_item_id()
	if item_id.is_empty():
		inventory_panel.hint.text = "拆解失败：请先在背包选择装备"
		refresh_inventory_actions()
		return
	var result: Dictionary = salvage_service.salvage(item_id)
	inventory_panel.refresh()
	refresh_inventory_actions()
	inventory_panel.hint.text = str(result.get("message", "拆解未完成")) + "\n" + inventory_panel.hint.text

## 重铸入口只传递稳定实例 ID，再切换到独立重铸页面。
func _on_reforge_entry_pressed() -> void:
	open_selected_reforge()

## 打开当前背包选中装备的独立重铸页面。
func open_selected_reforge() -> void:
	var item_id: String = selected_item_id()
	if item_id.is_empty():
		inventory_panel.hint.text = "重铸失败：请先在背包选择魔法或稀有装备"
		return
	open_reforge(item_id)

## 以稳定实例 ID 打开重铸页，并记住返回背包后的选中项。
func open_reforge(item_id: String) -> void:
	_return_item_id = item_id
	inventory_panel.hide()
	reforge_page.open_item(item_id)
	reforge_opened.emit(item_id)

## 隐藏页也可准备预览，兼容现有自动回归而不影响实际页面切换。
func prime_reforge_from_selection() -> void:
	var item_id: String = selected_item_id()
	if item_id.is_empty():
		return
	reforge_page.prepare_item(item_id)

## 重铸页关闭后恢复背包页，并按稳定 ID 恢复选中项。
func _on_reforge_closed() -> void:
	inventory_panel.show()
	inventory_panel.source = 0
	inventory_panel.selected = inventory.data.bag_ids.find(_return_item_id)
	inventory_panel.refresh()
	refresh_inventory_actions()
	reforge_closed.emit()

## 重铸成功后刷新背包缓存视图，页面仍停留在重铸页。
func _on_reforged(item_id: String) -> void:
	_return_item_id = item_id
	inventory_panel.source = 0
	inventory_panel.selected = inventory.data.bag_ids.find(item_id)
	inventory_panel.refresh()
	refresh_inventory_actions()
	reforged.emit(item_id)

## 返回当前背包选中物品的稳定实例 ID。
func selected_item_id() -> String:
	if inventory_panel == null or inventory_panel.source != 0:
		return ""
	var values: Array = inventory_panel.entries()
	if inventory_panel.selected < 0 or inventory_panel.selected >= values.size():
		return ""
	return values[inventory_panel.selected].id

## 刷新当前据点 UI；独立重铸页打开时同步刷新其持久状态。
func refresh() -> void:
	if inventory_panel == null:
		return
	inventory_panel.refresh()
	refresh_inventory_actions()
	if reforge_page.visible:
		reforge_page.refresh()

## I 键处理据点整备显隐；重铸页中先返回背包。
func toggle_inventory() -> void:
	if reforge_page.visible:
		reforge_page.close_page()
		return
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		inventory_panel.refresh()
		refresh_inventory_actions()

## Esc 优先关闭子页面，再关闭当前整备主页面。
func handle_back() -> bool:
	if reforge_page.visible:
		reforge_page.close_page()
		return true
	if inventory_panel != null and inventory_panel.visible:
		inventory_panel.hide()
		return true
	return false

## 判断当前是否有据点整备页面占用输入。
func content_visible() -> bool:
	return reforge_page.visible or (inventory_panel != null and inventory_panel.visible)
