extends Control
## 独立据点场景：持有角色长期状态，提供整备服务，并在出发时把状态交给探险场景。

const PANEL: Script = preload("res://ui/inventory/inventory_panel.gd")

const SLOTS: PackedScene = preload("res://ui/saves/save_slots.tscn")
var game_session: GameSession
var inventory: InventoryState
var generator: ItemGenerator
var minimum_quality: int:
	get: return game_session.modules.character.minimum_quality
	set(value):
		game_session.modules.character.minimum_quality = value
		game_session.modules.character.touch()
var panel: InventoryPanel
var slots: Control
var _timer: Timer
var _transitioning: bool = false
var _pending_action: String = ""


## 领取会话并装配据点 UI；保存触发放到场景就绪后。
func _ready() -> void:
	game_session = SceneRouter.take_session()
	if game_session == null:
		game_session = GameSession.new_character()
	inventory = game_session.inventory
	generator = game_session.generator
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
	slots = SLOTS.instantiate()
	add_child(slots)
	slots.closed.connect(_on_slots_closed)
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
			return "已出发"
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


## 长期状态变化只刷新据点 UI；战斗属性由进入探险后重新构建。
func _on_inventory_changed() -> void:
	if panel != null:
		panel.refresh()


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
