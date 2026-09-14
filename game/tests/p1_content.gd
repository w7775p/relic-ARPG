extends Node
## P1_Task3 回归：装备额度、稳定 ID、生成合法性、构筑击杀与有限流血传播。
const ARENA: PackedScene = preload("res://world/maps/combat_arena.tscn")
var failures: int = 0
var checks: int = 0

## 记录失败并继续执行，完整暴露内容配置问题。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 延迟运行，确保 Resource 类和自动加载服务完成初始化。
func _ready() -> void:
	_run.call_deferred()

## 核对累计 14/18/4、随机实例、两套构筑与第四独特传播边界。
func _run() -> void:
	check(ItemCatalog.BASES.size() == 14, "累计底材数量为 14")
	check(ItemCatalog.AFFIXES.size() == 18, "累计普通随机词条数量为 18")
	check(ItemCatalog.UNIQUES.size() == 4, "累计独特装备数量为 4")
	var base_ids: Dictionary = {}
	for entry: ItemBase in ItemCatalog.BASES:
		base_ids[entry.id] = true
		check(ItemCatalog.SLOTS.has(entry.slot), "底材 %s 使用合法部位" % entry.id)
	var affix_ids: Dictionary = {}
	for entry: AffixDefinition in ItemCatalog.AFFIXES:
		affix_ids[entry.id] = true
		check(ItemCatalog.STAT_NAMES.has(entry.stat), "词条 %s 有中文结算属性" % entry.id)
		check(not entry.slots.is_empty(), "词条 %s 至少适用一个部位" % entry.id)
	var unique_ids: Dictionary = {}
	for entry: UniqueDefinition in ItemCatalog.UNIQUES:
		unique_ids[entry.id] = true
		check(ItemCatalog.base(entry.base_id) != null, "独特 %s 引用存在的底材" % entry.id)
	check(base_ids.size() == 14 and affix_ids.size() == 18 and unique_ids.size() == 4, "底材、词条、独特 ID 均唯一")
	check(unique_ids.has("thunder_ring") and unique_ids.has("ember_mail") and unique_ids.has("energy_grips") and unique_ids.has("blood_echo"), "前三个稳定独特 ID 保持并新增 blood_echo")
	var generator: ItemGenerator = ItemGenerator.new()
	generator.rng.seed = 3103
	var legal: bool = true
	var seen_slots: Dictionary = {}
	var seen_qualities: Dictionary = {}
	for index: int in range(2400):
		var item: ItemInstanceResource = generator.generate(1 + index % 6, index % 4 == 0)
		legal = legal and item.validate().ok
		seen_slots[ItemCatalog.base(item.base).slot] = true
		seen_qualities[item.quality] = true
		var groups: Dictionary = {}
		for rolled: AffixRollResource in item.affixes:
			var affix: AffixDefinition = ItemCatalog.affix(rolled.id)
			legal = legal and affix != null and affix.min_level <= item.level and affix.slots.has(ItemCatalog.base(item.base).slot) and not groups.has(affix.group)
			groups[affix.group] = true
	check(legal and seen_slots.size() == 6 and seen_qualities.has(0) and seen_qualities.has(1) and seen_qualities.has(2) and seen_qualities.has(3), "多等级样本覆盖六部位与四品质且全部实例合法")
	var blood: ItemInstanceResource = generator.generate(6, true, "blood_echo")
	check(blood.validate().ok and blood.unique_id == "blood_echo" and blood.base == "serrated_blade", "第四件独特使用稳定 ID 和指定底材")
	var inventory: InventoryState = InventoryState.new()
	inventory.pickup(blood)
	inventory.equip(0)
	var build: BuildDefinition = inventory.build()
	check(build.bleed_damage_multiplier > 1.0 and build.bleed_spread_max_targets == 3 and build.bleed_spread_max_generation == 1, "流血底材与独特传播参数进入真实属性汇总")
	check(ItemGenerator.describe(blood).contains("流血击杀传播"), "第四件独特说明展示真实传播参数")
	await _check_elite_builds(inventory)
	await _check_bleed_spread(inventory)
	print("P1_CONTENT_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)

## 使用真实技能结算确认历史雷霆预设和新增流血构筑都能击杀固定精英原型。
func _check_elite_builds(inventory: InventoryState) -> void:
	var arena: Node3D = ARENA.instantiate()
	arena.auto_spawn = false
	get_tree().root.add_child(arena)
	await get_tree().process_frame
	get_tree().paused = true
	arena.player.restore_position(Vector3.ZERO)
	arena.skills.equip(SkillRunner.THUNDER)
	var thunder_elite: EnemyController = arena.encounters.spawn_enemy(EncounterDirector.ELITE, Vector3(0.0, 0.05, -2.0))
	thunder_elite.set_physics_process(false)
	for index: int in range(64):
		if thunder_elite.is_dead:
			break
		arena.skills.cast_whirlwind()
		arena.effects.drain(1000)
	check(thunder_elite.is_dead, "历史雷霆构筑可通过真实旋风结算击杀固定精英")
	arena.encounters.clear()
	await get_tree().process_frame
	arena.effects.reset()
	arena.skills.equip(inventory.build())
	var bleed_elite: EnemyController = arena.encounters.spawn_enemy(EncounterDirector.ELITE, Vector3(0.0, 0.05, -2.0))
	bleed_elite.set_physics_process(false)
	for index: int in range(64):
		if bleed_elite.is_dead:
			break
		arena.skills.cast_sweep()
		arena.effects.drain(1000)
		arena.effects.advance_bleeds(SkillRunner.SWEEP.bleed_tick_sec)
		arena.effects.drain(1000)
	check(bleed_elite.is_dead, "blood_echo 流血构筑可通过真实横扫与流血结算击杀固定精英")
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame

## 在真实战斗系统中验证传播重置完整时长、最多三个目标、只传播一代，卸装后失去传播能力。
func _check_bleed_spread(inventory: InventoryState) -> void:
	var arena: Node3D = ARENA.instantiate()
	arena.auto_spawn = false
	get_tree().root.add_child(arena)
	await get_tree().process_frame
	get_tree().paused = true
	arena.skills.equip(inventory.build())
	var definition: EnemyDefinition = EncounterDirector.DEFINITIONS[0]
	var origin: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(10.0, 0.05, 0.0))
	var near_a: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(11.0, 0.05, 0.0))
	var near_b: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(9.0, 0.05, 0.0))
	var near_c: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(10.0, 0.05, 1.0))
	var second_only: EnemyController = arena.encounters.spawn_enemy(definition, Vector3(14.2, 0.05, 0.0))
	origin.health = 10000.0
	origin.apply_bleed(arena.skills._bleed_snapshot(7001), SkillRunner.SWEEP.bleed_max_stacks)
	var elapsed_before_kill: float = SkillRunner.SWEEP.bleed_duration_sec - SkillRunner.SWEEP.bleed_tick_sec
	arena.effects.advance_bleeds(elapsed_before_kill)
	arena.effects.drain(1000)
	check(origin.bleeds.size() == 1 and is_equal_approx(float(origin.bleeds[0].remaining_sec), SkillRunner.SWEEP.bleed_tick_sec), "源流血推进到最后一个跳伤周期")
	origin.health = 1.0
	arena.effects.advance_bleeds(SkillRunner.SWEEP.bleed_tick_sec)
	arena.effects.drain(1000)
	check(origin.is_dead and arena.effects.bleed_spread_count == 3, "流血末段击杀仍最多向三个附近目标传播")
	check(near_a.bleeds.size() == 1 and near_b.bleeds.size() == 1 and near_c.bleeds.size() == 1 and second_only.bleeds.is_empty(), "首代传播受半径和目标数约束")
	check(is_equal_approx(float(near_a.bleeds[0].remaining_sec), SkillRunner.SWEEP.bleed_duration_sec) and is_equal_approx(float(near_a.bleeds[0].next_tick_sec), SkillRunner.SWEEP.bleed_tick_sec), "传播目标从完整流血持续时间和首跳间隔重新计时")
	near_a.health = 1.0
	arena.effects.advance_bleeds(SkillRunner.SWEEP.bleed_tick_sec)
	arena.effects.drain(1000)
	check(near_a.is_dead and second_only.bleeds.is_empty() and arena.effects.bleed_spread_count == 3, "传播流血击杀不会产生第二代链式放大")
	check(inventory.unequip("weapon"), "第四件独特可正常卸下")
	arena.skills.equip(inventory.build())
	var clean_snapshot: Dictionary = arena.skills._bleed_snapshot(7002)
	check(int(clean_snapshot.bleed_spread_max_targets) == 0 and int(clean_snapshot.bleed_spread_max_generation) == 0, "卸下后新攻击快照失去流血传播")
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame
