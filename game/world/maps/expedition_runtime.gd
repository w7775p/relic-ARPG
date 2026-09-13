extends "res://world/maps/combat_arena.gd"
## 正式探险运行场景；长期收益写入会话模块，本趟世界随真实离场回收。
const PANEL: Script = preload("res://ui/inventory/inventory_panel.gd")
const FIRST_CLEAR_REWARDS: Array[String] = ["thunder_ring", "ember_mail", "energy_grips"]
const PICKUP_RADIUS_M: float = 2.5
var game_session: GameSession
var inventory: InventoryState
var generator: ItemGenerator
var minimum_quality: int:
	get: return game_session.modules.character.minimum_quality
	set(value):
		game_session.modules.character.minimum_quality = value
		game_session.modules.character.touch()
var wave_completed: bool = false
var ground: Array = []
var ground_nodes: Dictionary = {}
var next_drop_id: int = 1
var pickup_index: int = 0
var panel: InventoryPanel
var _initializing: bool = true
var _ending: bool = false
var _settled: bool = false
var _notice: String = ""
var _notice_remaining: float = 0.0

## 领取唯一会话，重建属性并创建新遭遇，不生成临时兼容角色。
func _ready() -> void:
	game_session = SceneRouter.take_session()
	if game_session == null:
		game_session = GameSession.new_character()
	inventory = game_session.inventory
	generator = game_session.generator
	auto_spawn = false
	super._ready()
	inventory.changed.connect(_on_inventory_changed)
	combat.hit_resolved.connect(_on_loot_event)
	panel = PANEL.new()
	panel.session = self
	$Interface.add_child(panel)
	panel.hide()
	$Interface/CombatInfo/Rows/Controls.text = "I 背包 / E 拾取 / Tab 切换 / F 战吼 / Q 药剂 / T 撤离回据点保存"
	_on_inventory_changed()
	player.reset_health()
	skills.reset()
	for index: int in range(48):
		var original: EnemyDefinition = EncounterDirector.ELITE if index == 47 else EncounterDirector.DEFINITIONS[index % 3]
		var definition: EnemyDefinition = original.duplicate()
		definition.health *= 1.0 + (inventory.difficulty - 1) * 0.25
		definition.damage *= 1.0 + (inventory.difficulty - 1) * 0.15
		encounters.spawn_enemy(definition, encounters._spawn_position(index))
	_initializing = false
	_set_paused(false)
	if OS.get_cmdline_user_args().has("--smoke-combat"):
		print("M2_EXPEDITION_BOOT_READY")

## 正式探险不提供据点服务。
func is_hub() -> bool:
	return false

## 探险世界不可保存检查点，统一能力接口给出地点边界。
func can_save_checkpoint() -> bool:
	return false

## 刷新真实成长 HUD，附近金币材料自动入账，装备掉落保留手动选择。
func _process(delta: float) -> void:
	if _initializing or get_tree().paused:
		return
	super._process(delta)
	if _ending:
		return
	for drop: Dictionary in ground.duplicate():
		if drop.kind != "item" and player.global_position.distance_to(drop.position) < 2.0:
			if drop.kind == "gold":
				inventory.gold += int(drop.amount)
			else:
				inventory.materials += int(drop.amount)
			_remove_drop(drop)
	var nearby: Array = nearby_items()
	pickup_index = posmod(pickup_index, maxi(nearby.size(), 1))
	var text: String = "难度 %d · 等级 %d · 金币 %d · 材料 %d · 背包 %d/40" % [inventory.difficulty, inventory.level, inventory.gold, inventory.materials, inventory.bag.size()]
	if not nearby.is_empty():
		text += "\nE 拾取：" + ItemGenerator.title(nearby[pickup_index].item) + "（Tab 切换）"
	elif wave_completed:
		text += "\n已清场，拾取战利品后按 T 撤离，提高下一趟难度"
	_notice_remaining = maxf(0.0, _notice_remaining - delta)
	status.text = text + "\n" + _notice if _notice_remaining > 0.0 else text

## M2 键位只控制真实流程，测试预设继续留在独立调试资源。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_I:
				toggle_inventory()
				get_viewport().set_input_as_handled()
				return
			KEY_E:
				if not get_tree().paused:
					pickup_selected()
				return
			KEY_TAB:
				if not get_tree().paused:
					pickup_index += 1
				return
			KEY_T:
				if not get_tree().paused:
					return_to_town()
				return
	if event.is_action_pressed("pause"):
		if $Interface/Settings.visible:
			$Interface/Settings.hide()
		elif panel.visible:
			toggle_inventory()
		else:
			_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save"):
		_request_save()
		get_viewport().set_input_as_handled()

## 打开背包时停止世界与持续施法，输入释放后重新操作。
func show_inventory() -> void:
	_set_paused(false)
	get_tree().paused = true
	skills.channel_requested = false
	skills.primary_requested = false
	skills.auxiliary_requested = false
	skills.potion_requested = false
	skills.is_channeling = false
	panel.show()
	panel.refresh()
	$Interface/CombatInfo.hide()

## 关闭背包恢复探险；据点保持世界暂停。
func toggle_inventory() -> void:
	if panel.visible:
		panel.hide()
		_set_paused(false)
	else:
		show_inventory()

## 穿脱与升级重新生成属性快照；战吼生效时保留其单层临时护甲。
func _on_inventory_changed() -> void:
	if not is_instance_valid(skills.actor):
		return
	skills.loadout = inventory.loadout
	skills.equip(inventory.build())
	player.max_health = inventory.defense("max_health")
	player.armor = inventory.defense("armor") + (SkillRunner.WARCRY.armor_bonus if skills._warcry_applied else 0.0)
	player.health = minf(player.health, player.max_health)
	if panel != null:
		panel.refresh()

## 每个真实死亡事件结算一次经验、金币、材料和装备，精英独立权重。
func _on_loot_event(event: DamageEvent) -> void:
	if not event.killed or _settled:
		return
	var elite: bool = event.target is EnemyController and event.target.definition.is_elite
	inventory.grant_experience(35 if elite else 6)
	add_drop("gold", event.origin, null, generator.rng.randi_range(3, 8) * inventory.difficulty)
	if elite or generator.rng.randf() < 0.2:
		add_drop("material", event.origin + Vector3(0.3, 0, 0), null, 3 if elite else 1)
	if elite or generator.rng.randf() < 0.28:
		add_drop("item", event.origin + Vector3(-0.4, 0, 0.2), generator.generate(inventory.level, elite))
	if combat.enemies.is_empty() and not wave_completed:
		wave_completed = true
		inventory.completed += 1
		if inventory.completed <= 3:
			add_drop("item", event.origin + Vector3(0.5, 0, 0.4), generator.generate(inventory.level, true, FIRST_CLEAR_REWARDS[inventory.completed - 1]))

## 地面实例与视觉分开存储；金币材料使用数量，装备持有完整实例。
func add_drop(kind: String, at: Vector3, item: ItemInstanceResource = null, amount: int = 1) -> Dictionary:
	at.x = clampf(at.x, -18.5, 18.5)
	at.z = clampf(at.z, -18.5, 18.5)
	at.y = 0.15
	var drop: Dictionary = {"id":str(next_drop_id), "kind":kind, "position":at, "item":item, "amount":amount}
	next_drop_id += 1
	ground.append(drop)
	_render_drop(drop)
	return drop

## 原生几何体与名称标签按品质着色；仍使用占位美术。
func _render_drop(drop: Dictionary) -> void:
	var node: Node3D = Node3D.new()
	$Loot.add_child(node)
	node.position = drop.position
	var color: Color = Color.GOLD if drop.kind == "gold" else Color(0.4, 0.9, 0.6)
	if drop.kind == "item":
		color = [Color.WHITE, Color.CORNFLOWER_BLUE, Color.GOLD, Color.CORAL][int(drop.item.quality)]
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = Vector3(0.3, 0.18, 0.5)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shape.material = material
	mesh.mesh = shape
	node.add_child(mesh)
	if drop.kind == "item":
		var label: Label3D = Label3D.new()
		label.text = ItemGenerator.title(drop.item)
		label.font_size = 28
		label.pixel_size = 0.009
		label.position.y = 0.55 + float(int(drop.id) % 3) * 0.25
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = color
		node.add_child(label)
		if int(drop.item.quality) >= 2:
			feedback.ring(node.position, 0.5, color, 0.8)
	ground_nodes[drop.id] = node
	node.visible = drop.kind != "item" or int(drop.item.quality) >= minimum_quality

## 按掉落顺序返回可见且在拾取距离内的物品。
func nearby_items() -> Array:
	var result: Array = []
	for drop: Dictionary in ground:
		if drop.kind == "item" and int(drop.item.quality) >= minimum_quality and player.global_position.distance_to(drop.position) <= PICKUP_RADIUS_M:
			if combat.has_line_of_sight(player.global_position, drop.position):
				result.append(drop)
	return result

## 保留失败掉落并提示原因；只有物品入包成功才回收地面视觉。
func pickup_selected() -> bool:
	if _ending:
		return false
	var nearby: Array = nearby_items()
	if nearby.is_empty():
		_show_notice("附近没有可拾取装备（需在 %.1f 米内，且无遮挡、未被过滤）" % PICKUP_RADIUS_M)
		return false
	var drop: Dictionary = nearby[posmod(pickup_index, nearby.size())]
	if not inventory.pickup(drop.item):
		if inventory.data.bag_ids.size() >= inventory.data.bag_capacity:
			_show_notice("背包已满，请按 I 整理后再拾取")
		else:
			_show_notice("物品状态异常，未拾取；按 F3 查看日志")
			SceneRouter.debug_log("WARN", "拾取失败 item_id=%s duplicate=%s %s" % [drop.item.id, inventory.data.instances.has(drop.item.id), drop.item.validate().diagnostic()])
		return false
	_remove_drop(drop)
	_show_notice("已拾取：" + ItemGenerator.title(drop.item), 2.0)
	AudioManager.play_cue()
	return true

## 操作反馈保留指定秒数，逐帧 HUD 刷新时与常规状态一起显示。
func _show_notice(message: String, duration_sec: float = 4.0) -> void:
	_notice = message
	_notice_remaining = duration_sec
	status.text = message

## 数据移除立即生效，视觉延迟回收不会重复拾取。
func _remove_drop(drop: Dictionary) -> void:
	ground.erase(drop)
	if ground_nodes.has(drop.id):
		ground_nodes[drop.id].queue_free()
		ground_nodes.erase(drop.id)

## 离开探险时回收未拾取物品。
func _clear_ground() -> void:
	for drop: Dictionary in ground.duplicate():
		_remove_drop(drop)

## 操作入口重复校验地点和来源，防止界面状态失效后执行错误服务。
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
		"discard":
			if source == 0:
				var item: ItemInstanceResource = inventory.discard(index)
				if item != null:
					add_drop("item", player.global_position, item)
					success = true
		"return":
			return_to_town()
			return "已撤离；未拾取物品留在本次探险"
		"filter":
			minimum_quality = (minimum_quality + 1) % 3
			for drop: Dictionary in ground:
				ground_nodes[drop.id].visible = drop.kind != "item" or int(drop.item.quality) >= minimum_quality
			success = true
	return "操作完成" if success else "操作失败：请检查地点、选中物品、锁定状态和容量"

## 排空当前有限触发链并只结算一次，随后把整个会话交给真实 Hub。
func return_to_town(action: String = "") -> void:
	if _ending:
		return
	_ending = true
	effects.drain(1000000)
	if wave_completed:
		inventory.difficulty += 1
	wave_completed = false
	_settled = true
	effects.reset()
	skills.reset()
	generator.synchronize()
	game_session.pending_settlement = true
	game_session.return_action = action
	SceneRouter.stage_session(game_session)
	var error: Error = SceneRouter.open_hub()
	if error != OK:
		_ending = false
		status.text = "据点加载失败，请再次撤离"

## 死亡后的离场延迟到伤害调用栈结束，收益沿用统一结算。
func _on_player_died() -> void:
	return_to_town.call_deferred()

## 战斗快捷保存说明实际边界，并保留几秒供玩家阅读。
func _request_save() -> Error:
	var result: SaveResult = SaveManager.save_game(game_session, self)
	_show_notice(result.message)
	$Interface/Pause/Center/Rows/Status.text = result.message
	return result.code as Error

## 暂停菜单的保存入口直接回据点，结算后由 Hub 保存。
func _on_save_pressed() -> void:
	return_to_town()

## 正常返回菜单经过撤离、据点结算和成功保存。
func _on_menu_pressed() -> void:
	return_to_town("menu")

## 正常退出经过撤离、据点结算和成功保存。
func _on_quit_pressed() -> void:
	return_to_town("quit")

## 原生关闭请求沿同一个正常退出流程。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		return_to_town.call_deferred("quit")

## 列表获得焦点时仍接收 I、Esc 和 F5 全局输入。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I or event.is_action_pressed("pause") or event.is_action_pressed("quick_save"):
			_unhandled_input(event)
			get_viewport().set_input_as_handled()

## 暂停菜单与背包保持互斥。
func _set_paused(value: bool) -> void:
	if value and panel != null:
		panel.hide()
	super._set_paused(value)

## 探险中装配只读，业务入口也校验地点。
func loadout_action(_action: String, _id: String = "", _slot: String = "") -> String:
	return "只能在据点调整技能与被动"
