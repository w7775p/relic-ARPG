class_name EquipmentPage
extends PanelContainer
## 据点装备页：展示六个穿戴槽和详情；卸下请求交由 HubController 提交。

signal unequip_requested(index: int)

var inventory: InventoryState
var selected: int = -1

@onready var items: ItemList = $Margin/Rows/Columns/Items
@onready var detail: Label = $Margin/Rows/Columns/Detail/DetailText
@onready var unequip_button: Button = $Margin/Rows/Actions/Unequip
@onready var hint: Label = $Margin/Rows/Hint

## 绑定库存并刷新当前穿戴。
func setup(state: InventoryState) -> void:
	inventory = state
	refresh()

## 按固定槽位顺序返回已装备实例。
func entries() -> Array:
	var result: Array = []
	if inventory == null:
		return result
	for slot: String in ItemCatalog.SLOTS:
		if inventory.equipment.has(slot):
			result.append(inventory.equipment[slot])
	return result

## 重建装备列表并显示当前详情。
func refresh() -> void:
	if inventory == null or not is_node_ready():
		return
	items.clear()
	var values: Array = entries()
	for item: ItemInstanceResource in values:
		var base: ItemBase = ItemCatalog.base(item.base)
		items.add_item("%s｜%s" % [base.slot if base != null else "?", ItemGenerator.title(item)])
	selected = mini(selected, values.size() - 1)
	if selected >= 0:
		items.select(selected)
	_show_detail()
	unequip_button.disabled = selected < 0 or selected >= values.size()
	hint.text = "卸下后装备进入背包；背包满时保持原穿戴状态。"

## 选择变化后刷新详情。
func _on_items_item_selected(index: int) -> void:
	selected = index
	refresh()

## 只发出卸下请求，父级负责真正事务。
func _on_unequip_pressed() -> void:
	if selected >= 0:
		unequip_requested.emit(selected)

## 显示选中装备完整词条。
func _show_detail() -> void:
	var values: Array = entries()
	if selected < 0 or selected >= values.size():
		detail.text = "选择一个已装备槽查看详情。"
		return
	detail.text = ItemGenerator.describe(values[selected])

## 写入父级业务操作结果。
func set_message(message: String) -> void:
	hint.text = message + "\n" + hint.text
