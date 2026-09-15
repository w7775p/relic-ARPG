class_name BackpackPage
extends PanelContainer
## 据点背包页：展示背包、装备对比与轻量操作入口；业务提交交由 HubHUD / HubController。

signal action_requested(action: String, index: int)
signal salvage_requested(item_id: String)
signal reforge_requested(item_id: String)
signal selection_changed(item_id: String)
signal close_requested

var inventory: InventoryState
var source: int = 0
var selected: int = -1

@onready var summary: Label = $Margin/Rows/Summary
@onready var items: ItemList = $Margin/Rows/Columns/Items
@onready var left_text: Label = $Margin/Rows/Columns/Left/LeftText
@onready var right_text: Label = $Margin/Rows/Columns/Right/RightText
@onready var inventory_actions: HFlowContainer = $Margin/Rows/Actions
@onready var salvage_info: Label = $Margin/Rows/Disposition
@onready var hint: Label = $Margin/Rows/Hint
@onready var equip_button: Button = $Margin/Rows/Actions/Equip
@onready var lock_button: Button = $Margin/Rows/Actions/Lock
@onready var store_button: Button = $Margin/Rows/Actions/Store
@onready var sell_button: Button = $Margin/Rows/Actions/Sell
@onready var salvage_button: Button = $Margin/Rows/Actions/Salvage
@onready var reforge_button: Button = $Margin/Rows/Actions/Reforge

## 绑定角色库存；页面仅持有显示所需引用。
func setup(state: InventoryState) -> void:
	inventory = state
	refresh()

## 返回背包视图，保留与历史测试入口一致的接口。
func entries() -> Array:
	return inventory.bag if inventory != null else []

## 返回当前选中装备的稳定实例 ID。
func selected_item_id() -> String:
	var values: Array = entries()
	if selected < 0 or selected >= values.size():
		return ""
	return values[selected].id

## 刷新背包、属性对比和基础按钮状态。
func refresh() -> void:
	if inventory == null or not is_node_ready():
		return
	source = 0
	summary.text = "据点整备 · 等级 %d · 经验 %d/%d · 金币 %d · 材料 %d\n背包 %d/%d · 仓库 %d/%d · 难度 %d · 通关 %d 次" % [inventory.level, inventory.experience, inventory.level * 60, inventory.gold, inventory.materials, inventory.bag.size(), inventory.data.bag_capacity, inventory.stash.size(), inventory.data.stash_capacity, inventory.difficulty, inventory.completed]
	items.clear()
	for item: ItemInstanceResource in inventory.bag:
		items.add_item(("[锁] " if item.locked else "") + ItemGenerator.title(item))
	selected = mini(selected, inventory.bag.size() - 1)
	if selected >= 0:
		items.select(selected)
	_show_comparison()
	var has_item: bool = selected >= 0 and selected < inventory.bag.size()
	equip_button.disabled = not has_item
	lock_button.disabled = not has_item
	store_button.disabled = not has_item
	sell_button.disabled = not has_item
	if not has_item:
		salvage_button.disabled = true
		reforge_button.disabled = true
	hint.text = "锁定物品可穿戴，禁止出售或拆解。重铸会打开独立页面；复杂操作不会挤入背包布局。"

## 展示选中物品与同部位当前穿戴。
func _show_comparison() -> void:
	left_text.text = "选择一件物品查看实际词条。"
	right_text.text = "当前穿戴：无"
	if selected < 0 or selected >= inventory.bag.size():
		return
	var item: ItemInstanceResource = inventory.bag[selected]
	left_text.text = "选中物品\n" + ItemGenerator.describe(item)
	var base: ItemBase = ItemCatalog.base(item.base)
	if base != null and inventory.equipment.has(base.slot):
		right_text.text = "当前穿戴\n" + ItemGenerator.describe(inventory.equipment[base.slot])

## 由父级传入处置收益和服务可用状态，页面不自行执行规则。
func set_service_state(materials: int, salvage_enabled: bool, reforge_enabled: bool, restriction: String = "") -> void:
	var item_id: String = selected_item_id()
	if item_id.is_empty():
		salvage_info.text = "据点处置：选择背包装备后显示出售、拆解与重铸入口。"
		salvage_button.disabled = true
		reforge_button.disabled = true
		return
	var item: ItemInstanceResource = inventory.data.instances.get(item_id)
	salvage_info.text = "据点处置收益：出售 %d 金｜拆解 %d 材料%s" % [ItemGenerator.price(item), materials, restriction]
	salvage_button.disabled = not salvage_enabled
	reforge_button.disabled = not reforge_enabled

## 写入父级业务操作结果，不改变业务状态。
func set_message(message: String) -> void:
	hint.text = message + "\n" + hint.text

## 列表选择变化后通知父级刷新服务入口。
func _on_items_item_selected(index: int) -> void:
	selected = index
	refresh()
	selection_changed.emit(selected_item_id())

## 常规背包按钮只发请求，父级负责业务提交。
func _on_action_pressed(action: String) -> void:
	action_requested.emit(action, selected)

## 拆解请求携带稳定实例 ID。
func _on_salvage_pressed() -> void:
	var item_id: String = selected_item_id()
	if not item_id.is_empty():
		salvage_requested.emit(item_id)

## 重铸请求只打开独立页面，不在当前页创建复杂控件。
func _on_reforge_pressed() -> void:
	var item_id: String = selected_item_id()
	if not item_id.is_empty():
		reforge_requested.emit(item_id)

## 关闭按钮交给 HUD 总控处理整备显隐。
func _on_close_pressed() -> void:
	close_requested.emit()
