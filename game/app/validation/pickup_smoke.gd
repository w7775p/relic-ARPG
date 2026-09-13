extends Node
## 源码与成品包共用拾取回归：内容配置、真实击杀、E 输入和完整检查点。
var checks: int = 0
var failures: int = 0

## 保留跨场景测试节点，在正式服务就绪后开始。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	SaveManager.store = SaveStore.new()
	SaveManager.store.root = "user://pickup_smoke"
	_run.call_deferred()

## 记录断言并保留失败后的其余检查。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 等待输入、HUD 和场景释放完成。
func frames(count: int = 4) -> void:
	for index: int in range(count):
		await get_tree().process_frame

## 经引擎完整派发物理键和字符，覆盖 GUI 焦点与未处理输入阶段。
func press_key(code: Key, unicode: int = 0) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode
	event.pressed = true
	Input.parse_input_event(event.duplicate())
	event.pressed = false
	Input.parse_input_event(event.duplicate())
	Input.flush_buffered_events()

## 投递真实右键状态，保持按住时检查 E 是否仍可拾取。
func right_mouse(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = Vector2(900, 500)
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## 用横扫杀死精英产生必掉装备；距离单位为米，流血使用真实技能快照。
func sweep_drops(arena: Node3D, health: float, distance_m: float, bleed: bool) -> Array:
	arena._clear_ground()
	arena.wave_completed = false
	arena.player.restore_position(Vector3.ZERO)
	arena.player.visual_root.rotation.y = 0.0
	arena.skills.reset()
	var definition: EnemyDefinition = EncounterDirector.ELITE.duplicate()
	definition.health = health
	definition.damage = 0.0
	definition.speed_mps = 0.0
	var target: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(0, 0.05, -distance_m))
	target.set_physics_process(false)
	right_mouse(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if bleed:
		check(is_instance_valid(target) and not target.is_dead and target.bleeds.size() == 1, "右键横扫命中后目标存活并携带真实流血")
		arena.effects.advance_bleeds(1.0)
		arena.effects.drain()
	check(arena.combat.enemies.is_empty(), "横扫流血击杀目标" if bleed else "右键横扫直接击杀目标")
	var drops: Array = []
	for drop: Dictionary in arena.ground:
		if drop.kind == "item":
			drops.append(drop)
	check(not drops.is_empty(), "实际击杀事件生成可追踪的装备掉落")
	return drops

## 按 E 将真实死亡掉落逐件转入背包，确认物品身份和地面归属。
func pick_drops(arena: Node3D, drops: Array) -> void:
	for drop: Dictionary in drops:
		var count: int = arena.inventory.bag.size()
		press_key(KEY_E, 101)
		await frames()
		check(arena.inventory.bag.size() == count + 1 and arena.inventory.data.instances.get(drop.item.id) == drop.item and not arena.ground.has(drop), "按住横扫右键时 E 将同一装备实例从地面放入背包")
	right_mouse(false)
	await frames()

## 覆盖玩家切换横扫后的拾取流程以及两种已复现的无反馈情况。
func _run() -> void:
	if not _check_loot_content():
		_finish()
		return
	SceneRouter.start_session()
	await frames()
	var hub: Node = get_tree().current_scene
	hub.loadout_action("skill", "sweep", "main")
	hub.request_transition("depart")
	await frames(8)
	var arena: Node3D = get_tree().current_scene
	check(arena.skills.loadout.slots.main == "sweep", "通过 Hub 装配入口将横扫带入正式探险")
	print("PACKAGE_LOOT_BOOT_READY")
	arena.encounters.clear()
	arena.player.set_physics_process(false)
	await frames()
	var direct: Array = await sweep_drops(arena, 1.0, 2.0, false)
	await pick_drops(arena, direct)
	var bleed: Array = await sweep_drops(arena, 35.0, 6.0, true)
	var before: int = arena.inventory.bag.size()
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.bag.size() == before and arena.ground.has(bleed[0]), "远处流血掉落超出拾取距离时保持地面归属")
	check(arena.status.text.contains("2.5 米"), "远处按 E 后 HUD 明确提示拾取距离，后续帧仍可见")
	arena.player.restore_position(bleed[0].position)
	await pick_drops(arena, bleed)
	check(arena.status.text.contains("已拾取"), "拾取成功后能看到装备反馈")
	before = arena.inventory.bag.size()
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.bag.size() == before, "重复 E 不会复制已经拾取的装备")

	var focused: ItemInstanceResource = arena.generator.generate(1, true, "energy_grips")
	var focused_drop: Dictionary = arena.add_drop("item", arena.player.global_position, focused)
	press_key(KEY_I)
	await frames()
	arena.panel.items.grab_focus()
	press_key(KEY_E, 101)
	await frames()
	check(get_tree().paused and arena.ground.has(focused_drop), "背包打开并聚焦列表时 E 不会在暂停世界中拾取")
	press_key(KEY_I)
	await frames()
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.data.instances.get(focused.id) == focused and not arena.ground.has(focused_drop), "列表聚焦后关闭背包，真实 E 仍可拾取")
	var duplicate_drop: Dictionary = arena.add_drop("item", arena.player.global_position, focused)
	before = arena.inventory.bag.size()
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.bag.size() == before and arena.ground.has(duplicate_drop) and arena.status.text.contains("物品状态异常") and not arena.status.text.contains("背包已满"), "重复身份被拒绝时保留地面物品，并区分物品异常与满包")
	arena._remove_drop(duplicate_drop)

	while arena.inventory.bag.size() < arena.inventory.data.bag_capacity:
		arena.inventory.pickup(arena.generator.generate(1))
	var overflow: ItemInstanceResource = arena.generator.generate(1, true, "energy_grips")
	var overflow_drop: Dictionary = arena.add_drop("item", arena.player.global_position, overflow)
	press_key(KEY_E, 101)
	await frames()
	check(arena.ground.has(overflow_drop) and not arena.inventory.data.instances.has(overflow.id), "满包按 E 时不删除装备、不写入角色实例表")
	check(arena.status.text.contains("背包已满"), "满包提示不会被下一帧 HUD 覆盖")
	arena._process(1.0)
	check(arena.status.text.contains("背包已满") and arena.status.text.contains("E 拾取"), "满包反馈持续数秒，同时保留当前拾取候选")
	arena.inventory.discard(0)
	press_key(KEY_E, 101)
	await frames()
	check(arena.inventory.data.instances.get(overflow.id) == overflow and not arena.ground.has(overflow_drop) and arena.status.text.contains("已拾取"), "空出背包格后 E 成功拾取，并清除过时的满包反馈")
	arena._process(5.0)
	check(not arena.status.text.contains("已拾取") and arena.status.text.contains("背包"), "反馈到期后回到常规 HUD")

	arena.return_to_town()
	await frames(8)
	hub = get_tree().current_scene
	var slot_id: String = ""
	for entry: SaveSlotResource in SaveManager.store.catalog().slots:
		if entry.group_id == hub.game_session.group_id and entry.checkpoint_id == hub.game_session.saved_checkpoint_id:
			slot_id = entry.slot_id
	var result: SaveResult = SaveManager.load_game(hub.game_session.group_id, slot_id)
	check(result.ok and result.value.inventory.data.instances.has(overflow.id) and result.value.inventory.loadout.slots.main == "sweep", "横扫掉落拾取后撤离，装备身份和技能装配一起进入 Hub 检查点")
	if result.ok:
		check(ResourceFingerprint.digest(result.value.modules.items) == ResourceFingerprint.digest(hub.game_session.modules.items), "成品包检查点完整保留装备、词条实值、归属与随机状态")
		check(ResourceFingerprint.digest(result.value.generator.generate(4, true)) == ResourceFingerprint.digest(hub.game_session.generator.generate(4, true)), "成品包读档后下一件装备编号和词条序列一致")
	hub.queue_free()
	await frames()
	_finish()

## 导出后仍须保留适用部位，并能生成所有品质的合法实例。
func _check_loot_content() -> bool:
	var definitions_ok: bool = true
	for affix: AffixDefinition in ItemCatalog.AFFIXES:
		definitions_ok = definitions_ok and not affix.slots.is_empty()
		for slot: String in affix.slots:
			definitions_ok = definitions_ok and ItemCatalog.SLOTS.has(slot)
	check(definitions_ok, "打包后词条适用部位完整且引用有效装备槽")
	var generator: ItemGenerator = ItemGenerator.new()
	generator.rng.seed = 8912
	var generation_ok: bool = true
	var quality_counts: Array[int] = [0, 0, 0, 0]
	for index: int in range(1000):
		var item: ItemInstanceResource = generator.generate(1 + index % 6, index % 5 == 0)
		generation_ok = item.validate().ok and generation_ok
		quality_counts[item.quality] += 1
	check(generation_ok and not quality_counts.has(0), "打包后跨等级生成一千件装备，覆盖四种品质且全部通过实例校验")
	return failures == 0

## 输出成品包与源码验证共用的完成标记，失败以非零退出码返回。
func _finish() -> void:
	print("PICKUP_INPUT_RESULT: %d failures / %d checks" % [failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
