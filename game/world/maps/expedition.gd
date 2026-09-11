extends "res://world/maps/combat_arena.gd"
## M2/D1 刷宝会话：真实装备、技能状态、地面战利品、整备、成长与探险恢复。
const PANEL: Script = preload("res://ui/inventory/inventory_panel.gd")
var inventory: InventoryState = InventoryState.new()
var generator: ItemGenerator = ItemGenerator.new()
var in_town: bool = true
var wave_completed: bool = false
var minimum_quality: int = 0
var ground: Array = []
var ground_nodes: Dictionary = {}
var next_drop_id: int = 1
var pickup_index: int = 0
var panel: InventoryPanel
var _initializing: bool = true

## M1 保持为独立回归场景；正式入口使用当前会话完成装配。
func _ready() -> void:
	var restore_requested: bool = SceneRouter.should_restore_session
	var saved: Dictionary = SaveManager.load_session() if restore_requested else {}
	SceneRouter.should_restore_session = false
	auto_spawn = false
	super._ready()
	inventory.changed.connect(_on_inventory_changed)
	combat.hit_resolved.connect(_on_loot_event)
	panel = PANEL.new()
	panel.session = self
	$Interface.add_child(panel)
	panel.hide()
	$Interface/CombatInfo/Rows/Controls.text = "I 背包装备 / E 拾取 / Tab 切换物品 / F 战吼 / Q 药剂 / T 撤离 / F5 完整保存"
	if saved.get("version", 0) == 4:
		restore_expedition(saved.expedition)
	else:
		var starter: Dictionary = generator.generate(1)
		starter.base = "rust_sword"
		starter.quality = 0
		starter.unique = -1
		starter.affixes = []
		inventory.bag.append(starter)
		inventory.equip(0)
		if not saved.is_empty():
			status.text = "旧位置存档已升级；从据点开始新探险"
	_initializing = false
	_on_inventory_changed()
	if in_town:
		show_inventory()
	if OS.get_cmdline_user_args().has("--smoke-combat"):
		depart()
		print("M2_EXPEDITION_BOOT_READY")

## 刷新真实成长 HUD，附近金币材料自动入账，装备掉落保留手动选择。
func _process(delta: float) -> void:
	if _initializing or get_tree().paused:
		return
	super._process(delta)
	if in_town:
		return
	for drop: Dictionary in ground.duplicate():
		if drop.kind != "item" and player.global_position.distance_to(SessionSnapshot.unvector(drop.position)) < 2.0:
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
	status.text = text

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
		_save_position()
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
		_set_paused(in_town)
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
	if not event.killed or in_town:
		return
	var elite: bool = event.target is EnemyController and event.target.definition.is_elite
	inventory.grant_experience(35 if elite else 6)
	add_drop("gold", event.origin, {}, generator.rng.randi_range(3, 8) * inventory.difficulty)
	if elite or generator.rng.randf() < 0.2:
		add_drop("material", event.origin + Vector3(0.3, 0, 0), {}, 3 if elite else 1)
	if elite or generator.rng.randf() < 0.28:
		add_drop("item", event.origin + Vector3(-0.4, 0, 0.2), generator.generate(inventory.level, elite))
	if combat.enemies.is_empty() and not wave_completed:
		wave_completed = true
		inventory.completed += 1
		if inventory.completed <= 3:
			add_drop("item", event.origin + Vector3(0.5, 0, 0.4), generator.generate(inventory.level, true, inventory.completed - 1))

## 地面实例与视觉分开存储；金币材料使用数量，装备持有完整实例。
func add_drop(kind: String, at: Vector3, item: Dictionary = {}, amount: int = 1) -> Dictionary:
	at.x = clampf(at.x, -18.5, 18.5)
	at.z = clampf(at.z, -18.5, 18.5)
	at.y = 0.15
	var drop: Dictionary = {"id":str(next_drop_id), "kind":kind, "position":SessionSnapshot.vector(at), "item":item, "amount":amount}
	next_drop_id += 1
	ground.append(drop)
	_render_drop(drop)
	return drop

## 原生几何体与名称标签按品质着色；仍使用占位美术。
func _render_drop(drop: Dictionary) -> void:
	var node: Node3D = Node3D.new()
	$Loot.add_child(node)
	node.position = SessionSnapshot.unvector(drop.position)
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
		if drop.kind == "item" and int(drop.item.quality) >= minimum_quality and player.global_position.distance_to(SessionSnapshot.unvector(drop.position)) <= 2.5:
			if combat.has_line_of_sight(player.global_position, SessionSnapshot.unvector(drop.position)):
				result.append(drop)
	return result

## 背包满时保留掉落；成功后同步回收视觉。
func pickup_selected() -> bool:
	var nearby: Array = nearby_items()
	if nearby.is_empty() or in_town:
		return false
	var drop: Dictionary = nearby[posmod(pickup_index, nearby.size())]
	if not inventory.pickup(drop.item):
		status.text = "背包已满，请先整理"
		return false
	_remove_drop(drop)
	AudioManager.play_cue()
	return true

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

## 据点出发恢复生命、能量和药剂，难度同时增加怪物生命、伤害与金币。
func depart() -> void:
	if not in_town:
		return
	in_town = false
	wave_completed = false
	panel.hide()
	_set_paused(false)
	effects.reset()
	combat.kills = 0
	combat.damage_dealt = 0.0
	player.restore_position(Vector3.ZERO)
	player.reset_health()
	skills.reset()
	_clear_ground()
	encounters.clear()
	for index: int in range(48):
		var original: EnemyDefinition = EncounterDirector.ELITE if index == 47 else EncounterDirector.DEFINITIONS[index % 3]
		var definition: EnemyDefinition = original.duplicate()
		definition.health *= 1.0 + (inventory.difficulty - 1) * 0.25
		definition.damage *= 1.0 + (inventory.difficulty - 1) * 0.15
		var enemy: EnemyController = encounters.spawn_enemy(definition, encounters._spawn_position(index))
		enemy.set_meta("definition_path", original.resource_path)
	$FollowCamera.snap_to_target()
	_save_position()

## 撤离消耗本次探险；通关提高下一趟难度，已拾取物品与成长保留。
func return_to_town() -> void:
	if in_town:
		return
	effects.drain(1000000)
	in_town = true
	if wave_completed:
		inventory.difficulty += 1
	wave_completed = false
	effects.reset()
	encounters.clear()
	_clear_ground()
	player.restore_position(Vector3.ZERO)
	player.reset_health()
	skills.reset()
	show_inventory()
	_save_position()

## 死亡回据点延迟执行，避免在伤害调用栈中删除敌人。
func _on_player_died() -> void:
	effects.reset()
	return_to_town.call_deferred()

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
		"sell": success = in_town and source == 0 and inventory.sell(index)
		"store": success = in_town and source == 0 and inventory.transfer(index, true)
		"retrieve": success = in_town and source == 2 and inventory.transfer(index, false)
		"discard":
			if source == 0 and not in_town:
				var item: Dictionary = inventory.discard(index)
				if not item.is_empty():
					add_drop("item", player.global_position, item)
					success = true
		"depart":
			depart()
			return "已出发"
		"return":
			return_to_town()
			return "已撤离；未拾取物品留在本次探险"
		"filter":
			minimum_quality = (minimum_quality + 1) % 3
			for drop: Dictionary in ground:
				ground_nodes[drop.id].visible = drop.kind != "item" or int(drop.item.quality) >= minimum_quality
			success = true
	return "操作完成" if success else "操作失败：请检查地点、选中物品、锁定状态和容量"

## 保存前完成当前有限触发链；保留敌人持续状态、动作、弹体、技能冷却及独立随机序列。
func snapshot_expedition() -> Dictionary:
	effects.drain(1000000)
	var enemies: Array = []
	for enemy: EnemyController in combat.enemies:
		var data: Dictionary = SessionSnapshot.fields(enemy, SessionSnapshot.ACTOR + SessionSnapshot.ENEMY)
		data.position = SessionSnapshot.vector(enemy.position)
		data.definition = enemy.get_meta("definition_path", enemy.definition.resource_path)
		data.damage = enemy.definition.damage
		data.bleeds = enemy.bleeds.duplicate(true)
		enemies.append(data)
	var projectiles: Array = []
	for projectile: EnemyProjectile in $Projectiles.get_children():
		if projectile.is_queued_for_deletion():
			continue
		var data: Dictionary = SessionSnapshot.fields(projectile, SessionSnapshot.PROJECTILE)
		data.position = SessionSnapshot.vector(projectile.position)
		projectiles.append(data)
	return {"loadout":SessionSnapshot.loadout(inventory.loadout), "inventory":inventory.snapshot(), "in_town":in_town, "wave_completed":wave_completed, "minimum_quality":minimum_quality, "ground":ground.duplicate(true), "next_drop_id":next_drop_id, "next_item_id":generator.next_id, "loot_rng":str(generator.rng.state), "combat_rng":str(combat.rng.state), "enemies":enemies, "projectiles":projectiles, "player":SessionSnapshot.fields(player, SessionSnapshot.ACTOR + SessionSnapshot.PLAYER), "position":SessionSnapshot.vector(player.position), "facing":player.visual_root.rotation.y, "skills":SessionSnapshot.fields(skills, SessionSnapshot.SKILL), "clock":combat.clock_sec, "attack_id":combat._next_attack_id, "kills":combat.kills, "damage":combat.damage_dealt, "lightning_ready":effects._next_lightning_sec, "lightning_count":effects.lightning_count, "explosion_count":effects.explosion_count}

## 依次恢复持有、属性、世界和瞬态；输入意图由玩家重新按键产生。
func restore_expedition(data: Dictionary) -> void:
	inventory.loadout.restore(data.loadout)
	inventory.restore(data.inventory)
	in_town = data.in_town
	wave_completed = data.wave_completed
	minimum_quality = int(data.minimum_quality)
	generator.next_id = int(data.next_item_id)
	generator.rng.state = int(data.loot_rng)
	next_drop_id = int(data.next_drop_id)
	combat.rng.state = int(data.combat_rng)
	combat.clock_sec = data.clock
	combat._next_attack_id = int(data.attack_id)
	combat.kills = int(data.kills)
	combat.damage_dealt = data.damage
	effects.reset()
	effects._next_lightning_sec = data.lightning_ready
	effects.lightning_count = int(data.lightning_count)
	effects.explosion_count = int(data.explosion_count)
	encounters.clear()
	for entry: Dictionary in data.enemies:
		var definition: EnemyDefinition = load(entry.definition).duplicate()
		definition.health = entry.max_health
		definition.damage = entry.damage
		var enemy: EnemyController = encounters.spawn_enemy(definition, SessionSnapshot.unvector(entry.position))
		enemy.set_meta("definition_path", entry.definition)
		var fields: Dictionary = entry.duplicate()
		var saved_bleeds: Array = fields.bleeds.duplicate(true)
		for key: String in ["definition", "damage", "position", "bleeds"]:
			fields.erase(key)
		SessionSnapshot.apply(enemy, fields)
		enemy.bleeds = saved_bleeds
		enemy._on_health_changed(enemy.health, enemy.max_health)
		if not enemy.bleeds.is_empty():
			feedback.ring(enemy.position, 0.35, Color(0.8, 0.06, 0.06), 0.5)
		if enemy.state == EnemyController.State.WINDUP:
			feedback.ring(enemy.position, 1.8, Color.RED, maxf(enemy.state_remaining, 0.01))
			if definition.kind == EnemyDefinition.Kind.CHARGER:
				feedback.beam(enemy.position, enemy.position + enemy._locked_direction * 8.0, Color.RED, maxf(enemy.state_remaining, 0.01), 0.12)
	for entry: Dictionary in data.projectiles:
		var projectile: EnemyProjectile = EnemyController.PROJECTILE.instantiate()
		projectile.combat = combat
		$Projectiles.add_child(projectile)
		projectile.position = SessionSnapshot.unvector(entry.position)
		var fields: Dictionary = entry.duplicate()
		fields.erase("position")
		SessionSnapshot.apply(projectile, fields)
	_clear_ground()
	ground = data.ground.duplicate(true)
	for drop: Dictionary in ground:
		_render_drop(drop)
	skills.reset()
	player.restore_position(SessionSnapshot.unvector(data.position))
	SessionSnapshot.apply(player, data.player)
	player.visual_root.rotation.y = data.facing
	SessionSnapshot.apply(skills, data.skills)
	if skills._warcry_applied:
		feedback.ring(player.position, 2.2, Color(0.95, 0.72, 0.18), maxf(skills._warcry_remaining, 0.01))
	$FollowCamera.snap_to_target()

## 完整存档入口沿用暂停菜单按钮，文件错误反馈到界面。
func _save_position() -> Error:
	if _initializing:
		return OK
	var data: Dictionary = snapshot_expedition()
	var error: Error = SaveManager.save_expedition(data)
	var message: String = "已保存角色、装备和当前探险" if error == OK else "保存失败：%s" % error
	status.text = message
	$Interface/Pause/Center/Rows/Status.text = message
	return error


## 据点暂停菜单的继续按钮回到整备服务。
func _on_resume_pressed() -> void:
	if in_town:
		show_inventory()
	else:
		_set_paused(false)


## 背包列表拥有键盘焦点时仍允许全局菜单与保存快捷键。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I or event.is_action_pressed("pause") or event.is_action_pressed("quick_save"):
			_unhandled_input(event)
			get_viewport().set_input_as_handled()


## 原生关闭请求和暂停入口保持面板互斥。
func _set_paused(value: bool) -> void:
	if value and panel != null:
		panel.hide()
	super._set_paused(value)

## 据点独占装配入口；成功只重算属性，保留资源和所有冷却。
func loadout_action(action: String, id: String = "", slot: String = "") -> String:
	if not in_town:
		return "只能在据点调整技能与被动"
	var error: String = ""
	match action:
		"passive": error = inventory.loadout.toggle(id)
		"reset": inventory.loadout.passives.clear()
		"skill":
			if not LoadoutState.fits(slot, id):
				return "技能与槽位不匹配"
			inventory.loadout.slots[slot] = id
		_: return "未知装配操作"
	if not error.is_empty():
		return error
	inventory.changed.emit()
	return "装配已更新"
