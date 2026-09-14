extends Control
## 独立据点场景：持有角色长期状态，提供整备服务，并在出发时把状态交给探险场景。

const PANEL: Script = preload("res://ui/inventory/inventory_panel.gd")

const SLOTS: PackedScene = preload("res://ui/saves/save_slots.tscn")
var game_session: GameSession
var inventory: InventoryState
var generator: ItemGenerator
var salvage_service: SalvageService
var reforge_service: ReforgeService
var minimum_quality: int:
	get: return game_session.modules.character.minimum_quality
	set(value):
		game_session.modules.character.minimum_quality = value
		game_session.modules.character.touch()
var panel: InventoryPanel
var salvage_button: Button
var salvage_info: Label
var reforge_selector: OptionButton
var reforge_button: Button
var reforge_info: Label
var slots: Control
var _timer: Timer
var _transitioning: bool = false
var _pending_action: String = ""
var _reforge_refreshing: bool = false


## 领取会话并装配据点 UI；保存触发放到场景就绪后。
func _ready() -> void:
	game_session = SceneRouter.take_session()
	if game_session == null:
		game_session = GameSession.new_character()
	inventory = game_session.inventory
	generator = game_session.generator
	salvage_service = SalvageService.new(inventory, true)
	reforge_service = ReforgeService.new(inventory, true)
	inventory.changed.connect(_on_inventory_changed)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = true
	_timer.timeout.connect(_on_autosave_timeout)
	add_child(_timer)
	game_session.changed.connect(_on_session_changed)
	panel = PANEL.new()
	panel.session = self
	add_child(panel)
	panel.offset_top = 65
	panel.offset_bottom = -90
	panel.show()
	panel.refresh()
	_setup_salvage_ui()
	_setup_reforge_ui()
	slots = SLOTS.instantiate()
	add_child(slots)
	slots.closed.connect(_on_slots_closed)
	slots.saved.connect(_on_manual_saved)
	get_tree().auto_accept_quit = false
	_on_entered.call_deferred()


## 新角色和探险结算建立自动检查点；载入槽位只展示状态。
func _on_entered() -> void:
	if game_session.needs_initial_save or game_session.pending_settlement:
		_save_auto("new_character" if game_session.needs_initial_save else "settlement")
	else:
		$Toolbar/Rows/Status.text = "已载入据点；出发会创建新的探险"
	if not game_session.return_action.is_empty():
		var action: String = game_session.return_action
		game_session.return_action = ""
		request_transition(action)
	elif OS.get_cmdline_user_args().has("--smoke-combat"):
		request_transition("depart")


## 据点完成同步业务操作后允许保存。
func can_save_checkpoint() -> bool:
	return not _transitioning


## 角色持久模块变化后合并一秒内的连续操作。
func _on_session_changed(_module_id: String) -> void:
	if slots == null or not slots.visible:
		_timer.start()


## 去抖结束后保存最新完整状态。
func _on_autosave_timeout() -> void:
	_save_auto("hub_change")


## 保存并显示结果，失败保留会话和重试入口。
func _save_auto(reason: String) -> SaveResult:
	_timer.stop()
	var result: SaveResult = SaveManager.save_game(game_session, self, 0, reason)
	_timer.stop()
	$Toolbar/Rows/Status.text = result.message + ("；" + result.warning if not result.warning.is_empty() else "")
	$Toolbar/Rows/Buttons/Retry.visible = not result.ok
	return result


## 出发、回菜单和正常退出均等待真实检查点完成。
func request_transition(action: String) -> void:
	if _transitioning:
		return
	_pending_action = action
	var result: SaveResult = _save_auto("departure" if action == "depart" else "exit")
	if not result.ok:
		return
	_transitioning = true
	if action == "depart":
		SceneRouter.stage_session(game_session)
		var error: Error = SceneRouter.open_expedition()
		if error != OK:
			_transitioning = false
			$Toolbar/Rows/Status.text = "探险加载失败，请重试"
	elif action == "menu":
		SceneRouter.open_main_menu()
	elif action == "quit":
		get_tree().quit()


## 重试失败的保存或离场请求。
func _on_retry_pressed() -> void:
	if _pending_action.is_empty():
		_save_auto("retry")
	else:
		request_transition(_pending_action)


## 打开五个手动槽，覆盖目标由玩家明确选择。
func _on_save_pressed() -> void:
	_timer.stop()
	slots.open(self, game_session, true)


## 打开当前角色的手动和自动历史，可选择整档回退。
func _on_load_pressed() -> void:
	_timer.stop()
	slots.open(self, game_session, false)


## 关闭读取界面后恢复未保存改动的自动保存。
func _on_slots_closed() -> void:
	if game_session.revision != game_session.saved_revision:
		_timer.start()


## 同步手动保存的真实反馈，完成后清除先前失败的离场意图。
func _on_manual_saved(result: SaveResult) -> void:
	$Toolbar/Rows/Status.text = result.message + ("；" + result.warning if not result.warning.is_empty() else "")
	$Toolbar/Rows/Buttons/Retry.visible = not result.ok
	if result.ok:
		_pending_action = ""


## 返回菜单前保存最新据点状态。
func _on_menu_pressed() -> void:
	request_transition("menu")


## 正常退出前保存最新据点状态。
func _on_quit_pressed() -> void:
	request_transition("quit")


## 据点向共用背包面板声明当前位置能力。
func is_hub() -> bool:
	return true


## Hub 没有战斗世界；关闭整备只隐藏面板，再按 I 或 Esc 可重新打开。
func toggle_inventory() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		panel.refresh()
		_refresh_salvage_ui()
		_refresh_reforge_ui()


## 在现有出售操作旁追加拆解按钮和同物品收益预览。
func _setup_salvage_ui() -> void:
	salvage_button = Button.new()
	salvage_button.text = "拆解"
	salvage_button.pressed.connect(_on_salvage_pressed)
	panel.inventory_actions.add_child(salvage_button)
	salvage_info = Label.new()
	salvage_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rows: Node = panel.hint.get_parent()
	rows.add_child(salvage_info)
	rows.move_child(salvage_info, panel.hint.get_index())
	panel.items.item_selected.connect(_on_salvage_selection_changed)
	panel.tabs.item_selected.connect(_on_salvage_tab_changed)
	_refresh_salvage_ui()


## 背包选中项变化后刷新出售与拆解的并列收益。
func _on_salvage_selection_changed(_index: int) -> void:
	_refresh_salvage_ui()


## 切换容器后同步拆解按钮的地点与归属限制。
func _on_salvage_tab_changed(_index: int) -> void:
	_refresh_salvage_ui.call_deferred()


## 使用同一拆解规则显示当前选中物品的两种据点处置收益。
func _refresh_salvage_ui() -> void:
	if salvage_button == null or salvage_info == null or panel == null:
		return
	var values: Array = panel.entries()
	var valid: bool = panel.source == 0 and panel.selected >= 0 and panel.selected < values.size()
	salvage_button.disabled = not valid
	if not valid:
		salvage_info.text = "据点处置：在背包选择装备后，可比较出售金币与拆解材料收益。"
		return
	var item: ItemInstanceResource = values[panel.selected]
	var materials: int = SalvageService.RULES.materials_for(item)
	var restriction: String = "｜当前锁定，需先解锁" if item.locked else ""
	salvage_info.text = "据点处置收益：出售 %d 金｜拆解 %d 材料%s" % [ItemGenerator.price(item), materials, restriction]


## 点击时捕获稳定实例 ID；服务会再次查询当前位置，列表重排不会改变目标。
func _on_salvage_pressed() -> void:
	var values: Array = panel.entries()
	if panel.source != 0 or panel.selected < 0 or panel.selected >= values.size():
		panel.hint.text = "拆解失败：请先在背包选择装备"
		_refresh_salvage_ui()
		return
	var item_id: String = values[panel.selected].id
	var result: Dictionary = salvage_service.salvage(item_id)
	panel.refresh()
	_refresh_salvage_ui()
	_refresh_reforge_ui()
	panel.hint.text = str(result.message) + "\n" + panel.hint.text


## 提供给测试和后续据点 UI 的稳定 ID 拆解预览。
func salvage_preview(item_id: String) -> Dictionary:
	return salvage_service.preview(item_id)


## 提供给测试和后续入口的稳定 ID 拆解提交。
func salvage_item(item_id: String) -> Dictionary:
	return salvage_service.salvage(item_id)


## 在据点背包操作区加入重铸位置、按钮与规则说明。
func _setup_reforge_ui() -> void:
	reforge_selector = OptionButton.new()
	reforge_selector.tooltip_text = "首次成功后，该装备只能继续重铸同一位置"
	reforge_selector.item_selected.connect(_on_reforge_position_changed)
	panel.inventory_actions.add_child(reforge_selector)
	reforge_button = Button.new()
	reforge_button.text = "重铸词条"
	reforge_button.pressed.connect(_on_reforge_pressed)
	panel.inventory_actions.add_child(reforge_button)
	reforge_info = Label.new()
	reforge_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rows: Node = panel.hint.get_parent()
	rows.add_child(reforge_info)
	rows.move_child(reforge_info, panel.hint.get_index())
	panel.items.item_selected.connect(_on_reforge_selection_changed)
	panel.tabs.item_selected.connect(_on_reforge_tab_changed)
	_refresh_reforge_ui()


## 物品选择改变后刷新可重铸位置及当前预览。
func _on_reforge_selection_changed(_index: int) -> void:
	_refresh_reforge_ui()


## 容器切换后重算背包归属限制。
func _on_reforge_tab_changed(_index: int) -> void:
	_refresh_reforge_ui.call_deferred()


## 玩家改变首次重铸位置时刷新候选范围和费用。
func _on_reforge_position_changed(_index: int) -> void:
	if not _reforge_refreshing:
		_refresh_reforge_preview()


## 依据当前稳定实例重新填充词条位置；成功过的装备锁定选择器。
func _refresh_reforge_ui() -> void:
	if reforge_selector == null or reforge_button == null or reforge_info == null or panel == null:
		return
	var previous_index: int = reforge_selector.selected
	_reforge_refreshing = true
	reforge_selector.clear()
	var values: Array = panel.entries()
	var valid: bool = panel.source == 0 and panel.selected >= 0 and panel.selected < values.size()
	if not valid:
		reforge_selector.disabled = true
		reforge_button.disabled = true
		reforge_info.text = "词条重铸：仅据点背包内未锁定的魔法/稀有装备可用。"
		_reforge_refreshing = false
		return
	var item: ItemInstanceResource = values[panel.selected]
	if item.quality != 1 and item.quality != 2:
		reforge_selector.disabled = true
		reforge_button.disabled = true
		reforge_info.text = "词条重铸：当前装备品质不可重铸，仅支持魔法与稀有。"
		_reforge_refreshing = false
		return
	for index: int in range(item.affixes.size()):
		var roll: AffixRollResource = item.affixes[index]
		var definition: AffixDefinition = ItemCatalog.affix(roll.id)
		var label: String = "位置 %d · %s" % [index + 1, definition.display_name if definition != null else roll.id]
		reforge_selector.add_item(label)
	var selected_index: int = item.reforge_index if item.reforge_index >= 0 else clampi(previous_index, 0, maxi(item.affixes.size() - 1, 0))
	if not item.affixes.is_empty():
		reforge_selector.select(selected_index)
	reforge_selector.disabled = item.reforge_index >= 0 or item.affixes.is_empty()
	_reforge_refreshing = false
	_refresh_reforge_preview()


## 显示当前词条、合法候选区间、单次费用和相同结果可能性。
func _refresh_reforge_preview() -> void:
	if reforge_selector == null or reforge_button == null or reforge_info == null or panel == null:
		return
	var values: Array = panel.entries()
	if panel.source != 0 or panel.selected < 0 or panel.selected >= values.size() or reforge_selector.item_count == 0:
		reforge_button.disabled = true
		return
	var item: ItemInstanceResource = values[panel.selected]
	var index: int = item.reforge_index if item.reforge_index >= 0 else reforge_selector.selected
	var preview: Dictionary = reforge_service.preview(item.id, index)
	reforge_button.disabled = not bool(preview.get("ok", false))
	var current_text: String = str(preview.get("current", ""))
	var candidates: String = str(preview.get("candidates", ""))
	var cost: int = int(preview.get("cost", ReforgeService.RULES.materials_for(item)))
	var fixed_text: String = "已固定位置 %d；" % (item.reforge_index + 1) if item.reforge_index >= 0 else "首次成功后固定本位置；"
	reforge_info.text = "重铸位置 %d：%s\n候选：%s\n费用 %d 材料（当前 %d）；%s可能获得相同词条或相同数值。\n%s" % [index + 1, current_text, candidates, cost, inventory.materials, fixed_text, str(preview.get("message", ""))]


## 捕获稳定实例 ID 与位置执行一次请求；每次按钮点击生成独立请求 ID。
func _on_reforge_pressed() -> void:
	var values: Array = panel.entries()
	if panel.source != 0 or panel.selected < 0 or panel.selected >= values.size() or reforge_selector.item_count == 0:
		panel.hint.text = "重铸失败：请先在背包选择魔法或稀有装备"
		_refresh_reforge_ui()
		return
	var item: ItemInstanceResource = values[panel.selected]
	var index: int = item.reforge_index if item.reforge_index >= 0 else reforge_selector.selected
	var request_id: String = "ui:%s:%d:%d" % [item.id, index, Time.get_ticks_usec()]
	var result: Dictionary = reforge_service.reforge(item.id, index, request_id)
	panel.refresh()
	_refresh_salvage_ui()
	_refresh_reforge_ui()
	panel.hint.text = str(result.message) + "\n" + panel.hint.text


## 提供给测试的稳定 ID 重铸预览。
func reforge_preview(item_id: String, affix_index: int) -> Dictionary:
	return reforge_service.preview(item_id, affix_index)


## 提供给测试的稳定 ID 重铸提交，可传请求 ID 验证重复提交保护。
func reforge_item(item_id: String, affix_index: int, request_id: String = "") -> Dictionary:
	return reforge_service.reforge(item_id, affix_index, request_id)


## 据点物品服务只处理长期角色状态；丢弃与撤离由探险场景负责。
func inventory_action(action: String, source: int, index: int) -> String:
	var success: bool = false
	match action:
		"equip": success = source == 0 and inventory.equip(index)
		"unequip":
			if source == 1 and index >= 0 and index < panel.entries().size():
				success = inventory.unequip(ItemCatalog.base(panel.entries()[index].base).slot)
		"lock":
			if source == 0 and index >= 0 and index < inventory.bag.size():
				inventory.toggle_lock(index)
				success = true
		"sell": success = source == 0 and inventory.sell(index)
		"store": success = source == 0 and inventory.transfer(index, true)
		"retrieve": success = source == 2 and inventory.transfer(index, false)
		"depart":
			request_transition("depart")
			return "已出发" if _transitioning else $Toolbar/Rows/Status.text
		"filter":
			minimum_quality = (minimum_quality + 1) % 3
			success = true
	return "操作完成" if success else "操作失败：请检查选中物品、锁定状态和容量"


## 据点允许免费调整技能与被动；修改后刷新整备信息。
func loadout_action(action: String, id: String = "", slot: String = "") -> String:
	var error: String = ""
	match action:
		"passive": error = inventory.loadout.toggle(id)
		"reset": inventory.loadout.reset_passives()
		"skill":
			if not LoadoutState.fits(slot, id):
				return "技能与槽位不匹配"
			inventory.loadout.set_skill(slot, id)
		_: return "未知装配操作"
	if not error.is_empty():
		return error
	return "装配已更新"


## 长期状态变化刷新据点 UI、处置收益与重铸预览；战斗属性由进入探险后重新构建。
func _on_inventory_changed() -> void:
	if panel != null:
		panel.refresh()
		_refresh_salvage_ui()
		_refresh_reforge_ui()


## 据点场景只处理整备开关与返回主菜单。
func _input(event: InputEvent) -> void:
	if slots.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("quick_save"):
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_I:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			if panel.visible:
				toggle_inventory()
			else:
				request_transition("menu")
			get_viewport().set_input_as_handled()

## 接管原生窗口关闭，按正常离场规则保存。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		request_transition("quit")

## 场景释放后恢复默认窗口关闭行为。
func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
