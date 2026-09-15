class_name LoadoutPage
extends PanelContainer
## 据点技能与被动页：独立展示装配选项，具体修改由 HubController 校验提交。

signal skill_requested(slot: String, skill_id: String)
signal passive_requested(passive_id: String)
signal reset_requested

var inventory: InventoryState
var skill_choices: Dictionary = {}
var passive_buttons: Dictionary = {}
var _built: bool = false
var _refreshing: bool = false

@onready var content: VBoxContainer = $Margin/Rows/Scroll/Content
@onready var attributes: Label = $Margin/Rows/Scroll/Content/Attributes
@onready var hint: Label = $Margin/Rows/Hint

## 绑定库存并按静态定义建立一次控件。
func setup(state: InventoryState) -> void:
	inventory = state
	if not _built:
		_build_controls()
	refresh()

## 动态建立技能槽和被动按钮；模块内部布局对外不可见。
func _build_controls() -> void:
	_built = true
	var insert_index: int = attributes.get_index()
	for slot: String in ["basic", "main", "auxiliary"]:
		var row: HBoxContainer = HBoxContainer.new()
		content.add_child(row)
		content.move_child(row, insert_index)
		insert_index += 1
		var title: Label = Label.new()
		title.text = {"basic":"左键 · 基础攻击", "main":"右键 · 主要技能", "auxiliary":"F · 辅助技能"}[slot]
		title.custom_minimum_size.x = 180
		row.add_child(title)
		var choice: OptionButton = OptionButton.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_item("空槽")
		choice.set_item_metadata(0, "")
		for definition: SkillDefinition in LoadoutState.SKILLS:
			if definition.slot == slot:
				choice.add_item(definition.display_name)
				choice.set_item_metadata(choice.item_count - 1, definition.id)
		choice.item_selected.connect(_on_skill_selected.bind(slot))
		row.add_child(choice)
		skill_choices[slot] = choice
	for definition: PassiveDefinition in LoadoutState.PASSIVES:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.text = definition.display_name + "：" + definition.description
		button.pressed.connect(_on_passive_pressed.bind(definition.id))
		content.add_child(button)
		content.move_child(button, insert_index)
		insert_index += 1
		passive_buttons[definition.id] = button
	var reset: Button = Button.new()
	reset.text = "免费重置被动（最多同时选择三个）"
	reset.pressed.connect(_on_reset_pressed)
	content.add_child(reset)
	content.move_child(reset, insert_index)

## 根据当前持久装配和装备属性刷新显示。
func refresh() -> void:
	if inventory == null or not is_node_ready() or not _built:
		return
	_refreshing = true
	var state: LoadoutState = inventory.loadout
	var build: BuildDefinition = inventory.build()
	for slot: String in skill_choices:
		var choice: OptionButton = skill_choices[slot]
		for index: int in range(choice.item_count):
			var id: String = str(choice.get_item_metadata(index))
			if not id.is_empty():
				choice.set_item_text(index, LoadoutState.skill(id).describe(build))
			if id == state.slots[slot]:
				choice.select(index)
	for id: String in passive_buttons:
		passive_buttons[id].set_pressed_no_signal(state.passives.has(id))
	attributes.text = "已选 %d/3｜据点可免费调整\n装备＋被动合计：伤害 %.1f｜暴击 %.0f%%｜旋风半径 %.1f 米\n生命上限 %.0f｜护甲 %.0f｜停止施放回能 %.1f/秒\n右键可选旋风或流血横扫；F 可装战吼；Q 恢复药剂独立于装备。" % [state.passives.size(), build.damage, build.critical_chance * 100, build.whirlwind_radius_m, inventory.defense("max_health"), inventory.defense("armor"), build.idle_energy_regen]
	hint.text = "技能和被动修改只在据点开放；页面仅提交稳定技能/被动 ID。"
	_refreshing = false

## 技能下拉框只向父级发送稳定 ID。
func _on_skill_selected(index: int, slot: String) -> void:
	if _refreshing:
		return
	var choice: OptionButton = skill_choices[slot]
	skill_requested.emit(slot, str(choice.get_item_metadata(index)))

## 被动按钮只发切换请求。
func _on_passive_pressed(passive_id: String) -> void:
	if not _refreshing:
		passive_requested.emit(passive_id)

## 重置按钮只发请求。
func _on_reset_pressed() -> void:
	reset_requested.emit()

## 写入父级业务结果。
func set_message(message: String) -> void:
	hint.text = message + "\n" + hint.text
