extends Node
## D1 装配回归：实际会话属性、据点限制、版本迁移和状态往返。
const ARENA: PackedScene = preload("res://world/maps/expedition.tscn")
var failures: int = 0
var checks: int = 0

## 服务就绪后启动测试。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

## 记录验收断言。
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

## 使用 JSON 归一数字类型后比较完整数据。
func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

## 从 v4 快照提取 v2 时代字段，用于验证完整迁移链。
func legacy_v2(original: Dictionary) -> Dictionary:
	var old: Dictionary = {"version":2, "map_id":"map_m2_arena", "expedition":original.duplicate(true)}
	old.expedition.erase("loadout")
	var legacy_skills: Dictionary = {}
	for key: String in SessionSnapshot.SKILL_V3:
		legacy_skills[key] = old.expedition.skills[key]
	old.expedition.skills = legacy_skills
	for enemy: Dictionary in old.expedition.enemies:
		enemy.erase("bleeds")
	return old

## 场景操作覆盖合计、迁移以及恢复后的行为。
func _run() -> void:
	var arena: Node3D = ARENA.instantiate()
	add_child(arena)
	var base_damage: float = arena.skills.build.damage
	arena.player.health = 100
	arena.skills.energy = 21
	arena.skills._attack_remaining = 0.19
	arena.skills._whirlwind_remaining = 0.13
	arena.loadout_action("passive", "might")
	arena.loadout_action("passive", "precision")
	arena.loadout_action("passive", "reach")
	check(is_equal_approx(arena.skills.build.damage, base_damage + 6) and is_equal_approx(arena.skills.build.critical_chance, 0.15) and is_equal_approx(arena.skills.build.whirlwind_radius_m, 3.1), "装备叠加伤害＋6、暴击＋5百分点、半径＋0.5米")
	arena.panel._on_tab(3)
	arena.panel._on_loadout("passive", "vitality")
	check(arena.inventory.loadout.passives.size() == 3 and arena.panel.hint.text.contains("最多"), "第四项被拒绝且界面显示原因")
	arena.loadout_action("reset")
	check(arena.skills.build.damage == base_damage and is_equal_approx(arena.skills.build.critical_chance, 0.1) and is_equal_approx(arena.skills.build.whirlwind_radius_m, 2.6), "取消被动恢复原属性")
	for id: String in ["vitality", "guard", "recovery"]:
		arena.loadout_action("passive", id)
	check(arena.player.max_health == 360 and arena.player.armor == 30 and arena.skills.build.idle_energy_regen == 24, "生命＋60、护甲＋15、回能＋6真实生效")
	check(arena.player.health == 100 and arena.skills.energy == 21 and arena.skills._attack_remaining == 0.19 and arena.skills._whirlwind_remaining == 0.13, "选择与重置保留受损生命、能量和两种冷却")
	arena.skills.advance(0.5)
	check(arena.skills.energy == 33, "调息半秒实际回复12能量")
	arena.player.health = 350
	arena.loadout_action("passive", "vitality")
	check(arena.player.health == 300 and arena.player.max_health == 300, "生命上限降低时钳制当前值")
	arena.loadout_action("passive", "vitality")
	check(arena.player.health == 300, "重新选择生命被动没有免费治疗")
	arena.skills.energy = 101
	arena._on_inventory_changed()
	check(arena.skills.energy == 100, "重算时能量钳制到上限")
	check(arena.loadout_action("skill", "whirlwind", "basic").contains("不匹配"), "技能槽规则拒绝错配")
	arena.loadout_action("skill", "", "basic")
	arena.skills.primary_requested = true
	var attack_id: int = arena.combat._next_attack_id
	arena.skills.advance(0.5)
	check(arena.combat._next_attack_id == attack_id, "基础槽卸下后普攻意图不产生攻击")
	arena.loadout_action("skill", "primary", "basic")
	arena.skills.advance(0.5)
	check(arena.combat._next_attack_id > attack_id, "重新装配普攻恢复施放")
	arena.skills.primary_requested = false
	check(arena._save_position() == OK and SaveManager.load_session().version == 4, "新装配保存为v4")
	var saved: Dictionary = SaveManager.load_session()
	arena.restore_expedition(saved.expedition)
	check(normalized(arena.snapshot_expedition()) == saved.expedition, "v4据点完整快照往返一致")
	for kind: String in ["duplicate", "unknown", "extra", "slot"]:
		var bad: Dictionary = saved.duplicate(true)
		match kind:
			"duplicate": bad.expedition.loadout.passives = ["might", "might"]
			"unknown": bad.expedition.loadout.passives = ["missing"]
			"extra": bad.expedition.loadout.extra = 1
			"slot": bad.expedition.loadout.slots.auxiliary = "primary"
		check(not SaveManager.is_valid_session(bad), "损坏装配拒绝：" + kind)
	arena.loadout_action("reset")
	for in_town: bool in [true, false]:
		if not in_town:
			arena.depart()
			get_tree().paused = true
		arena.player.health = 123
		arena.skills.energy = 37
		arena.skills._attack_remaining = 0.17
		arena.skills._whirlwind_remaining = 0.09
		var original: Dictionary = arena.snapshot_expedition()
		var old: Dictionary = legacy_v2(original)
		check(SaveManager.is_valid_session(old), "M2旧档合法，据点=" + str(in_town))
		check(SaveManager._write(old) == OK, "写入v2迁移样例")
		var migrated: Dictionary = SaveManager.load_session()
		check(migrated.version == 4 and normalized(migrated.expedition) == normalized(original), "v2依次迁移到v4且完整状态保持")
		var next_item: Dictionary = arena.generator.generate(2, true)
		var next_roll: int = arena.combat.rng.randi()
		arena.queue_free()
		await get_tree().process_frame
		SceneRouter.should_restore_session = true
		arena = ARENA.instantiate()
		add_child(arena)
		get_tree().paused = true
		check(normalized(arena.snapshot_expedition()) == normalized(original), "重建场景恢复旧档生命、能量、冷却与世界")
		check(arena.generator.generate(2, true) == next_item and arena.combat.rng.randi() == next_roll, "迁移后下一件物品和战斗随机数一致")
	check(arena.loadout_action("passive", "might").contains("据点") and arena.loadout_action("reset").contains("据点") and arena.loadout_action("skill", "", "main").contains("据点"), "探险中会话拒绝全部装配操作")
	arena.return_to_town()
	arena.loadout_action("passive", "might")
	arena.loadout_action("skill", "", "main")
	arena.depart()
	get_tree().paused = true
	arena._save_position()
	var battle: Dictionary = SaveManager.load_session()
	arena.restore_expedition(battle.expedition)
	check(arena.skills.loadout.slots.main == "" and arena.skills.loadout.passives.has("might"), "v4战斗存档保留非默认技能槽与被动")
	arena.skills.channel_requested = true
	arena.skills.advance(0.1)
	check(not arena.skills.is_channeling, "空主要槽恢复后禁止旋风")
	arena.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	print("P1_LOADOUT_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
