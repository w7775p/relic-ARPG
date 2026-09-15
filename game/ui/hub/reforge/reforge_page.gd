class_name ReforgePage
extends PanelContainer
## 独立重铸页面；只负责展示与交互，业务规则和事务交由 ReforgeService / InventoryState。

signal closed
signal reforged(item_id: String)

var inventory: InventoryState
var service: ReforgeService
var item_id: String = ""
var _refreshing: bool = false

@onready var title_label: Label = $Margin/Rows/Header/Title
@onready var back_button: Button = $Margin/Rows/Header/Back
@onready var item_summary: Label = $Margin/Rows/Scroll/Content/ItemSummary
@onready var position_selector: OptionButton = $Margin/Rows/Scroll/Content/Position
@onready var preview_label: Label = $Margin/Rows/Scroll/Content/Preview
@onready var action_button: Button = $Margin/Rows/Scroll/Content/Reforge
@onready var result_label: Label = $Margin/Rows/Scroll/Content/Result

## 绑定当前角色库存与重铸服务；页面不持有业务状态副本。
func setup(state: InventoryState, reforge_service: ReforgeService) -> void:
	inventory = state
	service = reforge_service

## 只准备指定装备的数据，供隐藏页面的自动回归读取预览。
func prepare_item(target_id: String) -> void:
	item_id = target_id
	result_label.text = ""
	refresh()

## 打开独立页面，并按稳定实例 ID 重新解析装备。
func open_item(target_id: String) -> void:
	prepare_item(target_id)
	show()

## 关闭页面；父级决定返回哪个页面。
func close_page() -> void:
	hide()
	closed.emit()

## 根据持久实例刷新词条位置、候选、费用和固定位置状态。
func refresh() -> void:
	if inventory == null or service == null or not is_node_ready():
		return
	var item: ItemInstanceResource = _item()
	_refreshing = true
	position_selector.clear()
	if item == null:
		title_label.text = "词条重铸"
		item_summary.text = "目标装备已不存在。"
		preview_label.text = "请返回背包重新选择。"
		position_selector.disabled = true
		action_button.disabled = true
		_refreshing = false
		return
	title_label.text = "词条重铸 · %s" % ItemGenerator.title(item)
	item_summary.text = ItemGenerator.describe(item)
	if item.quality != 1 and item.quality != 2:
		preview_label.text = "当前装备品质不可重铸，仅支持魔法与稀有装备。"
		position_selector.disabled = true
		action_button.disabled = true
		_refreshing = false
		return
	for index: int in range(item.affixes.size()):
		var roll: AffixRollResource = item.affixes[index]
		var definition: AffixDefinition = ItemCatalog.affix(roll.id)
		position_selector.add_item("位置 %d · %s" % [index + 1, definition.display_name if definition != null else roll.id])
	var selected_index: int = item.reforge_index if item.reforge_index >= 0 else 0
	if position_selector.item_count > 0:
		position_selector.select(clampi(selected_index, 0, position_selector.item_count - 1))
	position_selector.disabled = item.reforge_index >= 0 or position_selector.item_count == 0
	_refreshing = false
	_refresh_preview()

## 位置改变时只刷新只读预览，不直接修改装备。
func _on_position_item_selected(_index: int) -> void:
	if not _refreshing:
		_refresh_preview()

## 提交一次重铸；每次点击生成独立请求 ID，重复提交保护仍由服务层负责。
func _on_reforge_pressed() -> void:
	var item: ItemInstanceResource = _item()
	if item == null or position_selector.item_count == 0:
		result_label.text = "重铸失败：目标装备无效"
		return
	var index: int = item.reforge_index if item.reforge_index >= 0 else position_selector.selected
	var request_id: String = "ui:%s:%d:%d" % [item.id, index, Time.get_ticks_usec()]
	var result: Dictionary = service.reforge(item.id, index, request_id)
	refresh()
	result_label.text = str(result.get("message", "重铸未完成"))
	if bool(result.get("ok", false)):
		reforged.emit(item.id)

## 返回按钮只发关闭事件，不直接操纵兄弟页面。
func _on_back_pressed() -> void:
	close_page()

## 读取当前稳定实例；页面不缓存装备 Resource 副本。
func _item() -> ItemInstanceResource:
	if inventory == null or item_id.is_empty():
		return null
	return inventory.data.instances.get(item_id) as ItemInstanceResource

## 显示当前词条、候选范围、材料费用和服务层限制原因。
func _refresh_preview() -> void:
	var item: ItemInstanceResource = _item()
	if item == null or position_selector.item_count == 0:
		action_button.disabled = true
		return
	var index: int = item.reforge_index if item.reforge_index >= 0 else position_selector.selected
	var preview: Dictionary = service.preview(item.id, index)
	var current_text: String = str(preview.get("current", ""))
	if current_text.is_empty() and index >= 0 and index < item.affixes.size():
		current_text = _roll_text(item.affixes[index])
	var candidates: String = str(preview.get("candidates", ""))
	if candidates.is_empty():
		candidates = "当前状态不可计算候选"
	var cost: int = int(preview.get("cost", 0))
	if cost <= 0:
		cost = ReforgeService.RULES.materials_for(item)
	var fixed_text: String = "已固定位置 %d" % (item.reforge_index + 1) if item.reforge_index >= 0 else "首次成功后固定当前位置"
	preview_label.text = "当前：%s\n候选：%s\n费用：%d 材料（当前 %d）\n%s\n%s\n允许再次抽到相同词条或相同数值。" % [current_text, candidates, cost, inventory.materials, fixed_text, str(preview.get("message", ""))]
	action_button.disabled = not bool(preview.get("ok", false))

## 用真实定义把词条显示为玩家当前数值。
func _roll_text(roll: AffixRollResource) -> String:
	if roll == null:
		return "无"
	var definition: AffixDefinition = ItemCatalog.affix(roll.id)
	return "%s %.3f" % [definition.display_name, roll.value] if definition != null else "%s %.3f" % [roll.id, roll.value]
