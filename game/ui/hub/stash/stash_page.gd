class_name StashPage
extends PanelContainer
## 据点仓库页：展示仓库内容与取回入口；归属事务由 HubController 提交。

signal retrieve_requested(index: int)

var inventory: InventoryState
var selected: int = -1

@onready var summary: Label = $Margin/Rows/Summary
@onready var items: ItemList = $Margin/Rows/Columns/Items
@onready var detail: Label = $Margin/Rows/Columns/Detail/DetailText
@onready var retrieve_button: Button = $Margin/Rows/Actions/Retrieve
@onready var hint: Label = $Margin/Rows/Hint

## 绑定库存并刷新仓库内容。
func setup(state: InventoryState) -> void:
	inventory = state
	refresh()

## 返回仓库实例视图。
func entries() -> Array:
	return inventory.stash if inventory != null else []

## 重建仓库列表和容量摘要。
func refresh() -> void:
	if inventory == null or not is_node_ready():
		return
	summary.text = "仓库 %d/%d｜背包 %d/%d" % [inventory.stash.size(), inventory.data.stash_capacity, inventory.bag.size(), inventory.data.bag_capacity]
	items.clear()
	for item: ItemInstanceResource in inventory.stash:
		items.add_item(("[锁] " if item.locked else "") + ItemGenerator.title(item))
	selected = mini(selected, inventory.stash.size() - 1)
	if selected >= 0:
		items.select(selected)
	_show_detail()
	retrieve_button.disabled = selected < 0 or selected >= inventory.stash.size()
	hint.text = "取回会把指定实例移动到背包；背包满时保持仓库归属。"

## 选择变化后刷新详情。
func _on_items_item_selected(index: int) -> void:
	selected = index
	refresh()

## 只发取回请求，父级负责实际归属事务。
func _on_retrieve_pressed() -> void:
	if selected >= 0:
		retrieve_requested.emit(selected)

## 展示仓库选中物品的真实词条。
func _show_detail() -> void:
	if selected < 0 or selected >= inventory.stash.size():
		detail.text = "选择仓库装备查看详情。"
		return
	detail.text = ItemGenerator.describe(inventory.stash[selected])

## 写入父级业务操作结果。
func set_message(message: String) -> void:
	hint.text = message + "\n" + hint.text
