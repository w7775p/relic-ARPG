extends Control
## 独立据点场景控制器：持有角色长期状态、保存与场景切换；具体 UI 由 HubHUD 子模块负责。

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

@onready var hud: HubHUD = $HubHUD
var panel: BackpackPage
var salvage_button: Button
var salvage_info: Label
var reforge_selector: OptionButton
var reforge_button: Button
var reforge_info: Label
var slots: Control
var _timer: Timer
var _transitioning: bool = false
var _pending_action: String = ""

## 领取会话并把业务服务交给 HUD；保存触发放到场景就绪后。
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
	hud.setup(self, inventory, salvage_service, reforge_service)
	# 兼容现有自动回归入口；玩法代码不再直接搭建这些控件。
	panel = hud.inventory_panel
	salvage_button = hud.salvage_button
	salvage_info = hud.salvage_info
	reforge_selector = hud.reforge_selector
	reforge_button = hud.reforge_button
	reforge_info = hud.reforge_info
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

## Hub 没有战斗世界；具体页面显隐交给 HUD 总控。
func toggle_inventory() -> void:
	hud.toggle_inventory()

## 兼容现有回归入口，实际拆解 UI 刷新由 HubHUD 负责。
func _refresh_salvage_ui() -> void:
	hud.refresh_inventory_actions()

## 兼容现有回归入口；只准备隐藏重铸页预览，不向背包布局注入控件。
func _refresh_reforge_ui() -> void:
	hud.prime_reforge_from_selection()

## 兼容旧入口，实际点击行为交给 HubHUD 当前模块。
func _on_salvage_pressed() -> void:
	hud._on_salvage_requested(hud.selected_item_id())

## 兼容旧入口，打开当前选中装备的独立重铸页面。
func _on_reforge_pressed() -> void:
	hud.open_selected_reforge()

## 提供给测试和后续据点 UI 的稳定 ID 拆解预览。
func salvage_preview(item_id: String) -> Dictionary:
	return salvage_service.preview(item_id)

## 提供给测试和后续入口的稳定 ID 拆解提交。
func salvage_item(item_id: String) -> Dictionary:
	return salvage_service.salvage(item_id)

## 提供给测试的稳定 ID 重铸预览。
func reforge_preview(item_id: String, affix_index: int) -> Dictionary:
	return reforge_service.preview(item_id, affix_index)

## 提供给测试的稳定 ID 重铸提交，可传请求 ID 验证重复提交保护。
func reforge_item(item_id: String, affix_index: int, request_id: String = "") -> Dictionary:
	return reforge_service.reforge(item_id, affix_index, request_id)

## 返回指定来源的物品视图，业务控制器不依赖页面内部节点结构。
func _entries_for_source(source: int) -> Array:
	if source == 0:
		return inventory.bag
	if source == 2:
		return inventory.stash
	var result: Array = []
	if source == 1:
		for slot: String in ItemCatalog.SLOTS:
			if inventory.equipment.has(slot):
				result.append(inventory.equipment[slot])
	return result

## 据点物品服务只处理长期角色状态；丢弃与撤离由探险场景负责。
func inventory_action(action: String, source: int, index: int) -> String:
	var success: bool = false
	match action:
		"equip": success = source == 0 and inventory.equip(index)
		"unequip":
			var values: Array = _entries_for_source(source)
			if source == 1 and index >= 0 and index < values.size():
				success = inventory.unequip(ItemCatalog.base(values[index].base).slot)
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

## 长期状态变化只通知 HUD 总控刷新当前页面。
func _on_inventory_changed() -> void:
	if hud != null:
		hud.refresh()

## 据点场景处理整备开关、子页面返回与主菜单请求。
func _input(event: InputEvent) -> void:
	if slots == null or slots.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("quick_save"):
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_I:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			if not hud.handle_back():
				request_transition("menu")
			get_viewport().set_input_as_handled()

## 接管原生窗口关闭，按正常离场规则保存。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		request_transition("quit")

## 场景释放后恢复默认窗口关闭行为。
func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
