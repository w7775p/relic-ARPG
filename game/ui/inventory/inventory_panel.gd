class_name InventoryPanel
extends PanelContainer
## 暂停式整备面板：列表选择、并排比较、穿脱和仓库操作。
var session: Node
var source: int = 0
var selected: int = -1
var items: ItemList
var left_text: Label
var right_text: Label
var summary: Label
var hint: Label
var tabs: OptionButton
var action_buttons: Dictionary = {}
var loadout_view: VBoxContainer
var inventory_columns: HBoxContainer
var inventory_actions: HFlowContainer
var passive_buttons: Dictionary = {}
var skill_choices: Dictionary = {}
var attributes: Label

## 使用原生容器适配窗口，所有操作通过会话规则提交。
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 35
	offset_top = 30
	offset_right = -35
	offset_bottom = -30
	var rows: VBoxContainer = VBoxContainer.new()
	add_child(rows)
	summary = Label.new()
	rows.add_child(summary)
	var top: HBoxContainer = HBoxContainer.new()
	rows.add_child(top)
	tabs = OptionButton.new()
	for title: String in ["背包", "已装备", "仓库（整备时）", "技能与被动"]:
		tabs.add_item(title)
	tabs.item_selected.connect(_on_tab)
	top.add_child(tabs)
	var close: Button = Button.new()
	close.text = "关闭（I / Esc）"
	close.pressed.connect(session.toggle_inventory)
	top.add_child(close)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(columns)
	inventory_columns = columns
	items = ItemList.new()
	items.custom_minimum_size.x = 300
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.item_selected.connect(_on_selected)
	columns.add_child(items)
	left_text = _description_column(columns)
	right_text = _description_column(columns)
	var actions: HFlowContainer = HFlowContainer.new()
	rows.add_child(actions)
	inventory_actions = actions
	for key: String in ["equip", "unequip", "lock", "discard", "store", "retrieve", "sell", "depart", "return", "filter"]:
		var button: Button = Button.new()
		button.text = {"equip":"穿戴", "unequip":"卸下", "lock":"锁定 / 解锁", "discard":"丢弃", "store":"存入仓库", "retrieve":"取回背包", "sell":"出售", "depart":"出发", "return":"撤离整备", "filter":"切换掉落过滤"}[key]
		button.pressed.connect(_on_action.bind(key))
		actions.add_child(button)
		action_buttons[key] = button
	_create_loadout(rows)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	refresh()

## 每个说明列独立滚动，低分辨率下仍可访问全部词条。
func _description_column(parent: Control) -> Label:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(label)
	return label

## 获得当前页的物品引用，穿戴页使用固定槽位顺序。
func entries() -> Array:
	if source == 0:
		return session.inventory.bag
	if source == 2:
		return session.inventory.stash
	var result: Array = []
	for slot: String in ItemCatalog.SLOTS:
		if session.inventory.equipment.has(slot):
			result.append(session.inventory.equipment[slot])
	return result

## 操作后重建列表并保留合法选择，显示可用服务。
func refresh() -> void:
	if items == null:
		return
	inventory_columns.visible = source != 3
	inventory_actions.visible = source != 3
	loadout_view.visible = source == 3
	_refresh_loadout()
	var inventory: InventoryState = session.inventory
	summary.text = "%s · 等级 %d · 经验 %d/%d · 金币 %d · 材料 %d\n背包 %d/40 · 仓库 %d/120 · 难度 %d · 通关 %d 次" % ["据点整备" if session.in_town else "探险中", inventory.level, inventory.experience, inventory.level * 60, inventory.gold, inventory.materials, inventory.bag.size(), inventory.stash.size(), inventory.difficulty, inventory.completed]
	items.clear()
	var values: Array = entries()
	for item: Dictionary in values:
		items.add_item(("[锁] " if item.locked else "") + ItemGenerator.title(item))
	selected = mini(selected, values.size() - 1)
	if selected >= 0:
		items.select(selected)
	_show_comparison()
	for key: String in action_buttons:
		var enabled: bool = selected >= 0
		match key:
			"equip", "lock", "discard": enabled = enabled and source == 0
			"unequip": enabled = enabled and source == 1
			"store", "sell": enabled = enabled and source == 0 and session.in_town
			"retrieve": enabled = enabled and source == 2 and session.in_town
			"depart": enabled = session.in_town
			"return": enabled = not session.in_town
			"filter": enabled = true
		action_buttons[key].disabled = not enabled
	hint.text = "金币材料靠近自动拾取；装备靠近按 E，重叠物品按 Tab 切换。锁定物品可穿戴，禁止出售或丢弃。\n掉落过滤：%s；通关后撤离提高难度，前三次通关依次奖励核心独特装备。" % ["全部", "魔法及以上", "稀有及以上"][session.minimum_quality]

## 切换物品容器。
func _on_tab(index: int) -> void:
	source = index
	selected = -1
	refresh()

## 选择物品后刷新可操作状态。
func _on_selected(index: int) -> void:
	selected = index
	refresh()

## 并排展示选中物品与同部位装备。
func _show_comparison() -> void:
	left_text.text = "选择一件物品查看实际词条。"
	right_text.text = "当前穿戴：无"
	if selected < 0:
		return
	var item: Dictionary = entries()[selected]
	left_text.text = "选中物品\n" + ItemGenerator.describe(item)
	var slot: String = ItemCatalog.base(item.base).slot
	if session.inventory.equipment.has(slot):
		right_text.text = "当前穿戴\n" + ItemGenerator.describe(session.inventory.equipment[slot])

## 会话判断服务地点与索引，界面只显示操作结果。
func _on_action(key: String) -> void:
	var message: String = session.inventory_action(key, source, selected)
	refresh()
	hint.text = message + "\n" + hint.text

## 原生容器承载技能槽和六个被动，与物品页共用顶部入口。
func _create_loadout(rows: VBoxContainer) -> void:
	loadout_view = VBoxContainer.new()
	loadout_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(loadout_view)
	for slot: String in ["basic", "main", "auxiliary"]:
		var row: HBoxContainer = HBoxContainer.new()
		loadout_view.add_child(row)
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
		choice.item_selected.connect(_on_skill.bind(slot))
		row.add_child(choice)
		skill_choices[slot] = choice
	for definition: PassiveDefinition in LoadoutState.PASSIVES:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.text = definition.display_name + "：" + definition.description
		button.pressed.connect(_on_loadout.bind("passive", definition.id))
		loadout_view.add_child(button)
		passive_buttons[definition.id] = button
	var reset: Button = Button.new()
	reset.text = "免费重置被动（最多同时选择三个）"
	reset.pressed.connect(_on_loadout.bind("reset", ""))
	loadout_view.add_child(reset)
	attributes = Label.new()
	attributes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_view.add_child(attributes)

## 根据真实构筑显示合计、选择数与据点限制。
func _refresh_loadout() -> void:
	var state: LoadoutState = session.inventory.loadout
	var build: BuildDefinition = session.inventory.build()
	for slot: String in skill_choices:
		var choice: OptionButton = skill_choices[slot]
		choice.disabled = not session.in_town
		for index: int in range(choice.item_count):
			var id: String = choice.get_item_metadata(index)
			if not id.is_empty():
				choice.set_item_text(index, LoadoutState.skill(id).describe(build))
			if id == state.slots[slot]:
				choice.select(index)
	for id: String in passive_buttons:
		passive_buttons[id].set_pressed_no_signal(state.passives.has(id))
		passive_buttons[id].disabled = not session.in_town
	attributes.text = "已选 %d/3｜%s\n装备＋被动合计：伤害 %.1f｜暴击 %.0f%%｜旋风半径 %.1f 米\n生命上限 %.0f｜护甲 %.0f｜停止施放回能 %.1f/秒\n右键可选旋风或流血横扫；F 可装战吼；Q 恢复药剂独立于装备。" % [state.passives.size(), "据点可免费调整" if session.in_town else "探险中只能查看", build.damage, build.critical_chance * 100, build.whirlwind_radius_m, session.inventory.defense("max_health"), session.inventory.defense("armor"), build.idle_energy_regen]

## 失败原因写入共用提示，包括第四项选择被拒绝。
func _on_loadout(action: String, id: String) -> void:
	var message: String = session.loadout_action(action, id)
	refresh()
	hint.text = message

## 下拉框提交稳定技能 ID，状态修改交由会话校验。
func _on_skill(index: int, slot: String) -> void:
	var message: String = session.loadout_action("skill", skill_choices[slot].get_item_metadata(index), slot)
	refresh()
	hint.text = message
