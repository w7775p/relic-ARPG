extends Node
## D1 技能回归：横扫几何、流血边界、战吼、药剂、暂停和 v4 状态往返。
const ARENA: PackedScene = preload("res://world/maps/expedition.tscn")
const BLEED_BUILD: BuildDefinition = preload("res://debug/bleed_test.tres")
var failures: int = 0
var checks: int = 0

## 服务就绪后启动测试；测试节点保持暂停时可运行断言。
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

## 创建静止高生命目标，并记录正式定义路径供完整存档恢复。
func spawn_target(arena: Node3D, at: Vector3, health: float = 1000.0) -> EnemyController:
	var definition: EnemyDefinition = EncounterDirector.DEFINITIONS[0].duplicate()
	definition.health = health
	definition.damage = 0.0
	definition.speed_mps = 0.0
	var enemy: EnemyController = arena.encounters.spawn_enemy(definition, at)
	enemy.set_meta("definition_path", EncounterDirector.DEFINITIONS[0].resource_path)
	enemy.set_physics_process(false)
	return enemy

## 回收当前目标并等待 queued_free 生效，避免旧碰撞影响下一条几何断言。
func clear_targets(arena: Node3D) -> void:
	arena.encounters.clear()
	await get_tree().process_frame

## 建立只参与 world 层射线的测试墙。
func make_wall(arena: Node3D, at: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.6, 2.2, 0.25)
	collision.shape = shape
	wall.add_child(collision)
	arena.add_child(wall)
	wall.global_position = at
	return wall

## 统计指定类型地面收益，用于检查死亡只结算一次。
func count_ground(arena: Node3D, kind: String) -> int:
	var total: int = 0
	for drop: Dictionary in arena.ground:
		if drop.kind == kind:
			total += 1
	return total

## 返回当前唯一带流血层的存活目标。
func bleeding_target(arena: Node3D) -> EnemyController:
	for enemy: EnemyController in arena.combat.enemies:
		if not enemy.bleeds.is_empty():
			return enemy
	return null

## 完整覆盖任务卡核心规则和状态恢复。
func _run() -> void:
	var arena: Node3D = ARENA.instantiate()
	add_child(arena)
	check(LoadoutState.skill("sweep") != null and LoadoutState.skill("warcry") != null, "横扫与战吼进入稳定技能目录")
	check(is_equal_approx(SkillRunner.SWEEP.range_m, 8.0) and is_equal_approx(SkillRunner.SWEEP.bleed_damage_multiplier, 0.84), "横扫试玩参数为8米范围与0.84流血倍率")
	check(arena.loadout_action("skill", "sweep", "main").contains("更新"), "据点可把右键主要技能替换为横扫")
	check(arena.loadout_action("skill", "warcry", "auxiliary").contains("更新"), "据点可把战吼装入 F 辅助槽")
	arena.depart()
	await clear_targets(arena)
	arena.skills.equip(BLEED_BUILD)
	arena.player.restore_position(Vector3.ZERO)
	arena.player.visual_root.rotation.y = 0.0

	var front: EnemyController = spawn_target(arena, Vector3(0, 0.05, -2.4))
	var back: EnemyController = spawn_target(arena, Vector3(0, 0.05, 2.4))
	arena.skills.cast_sweep()
	arena.effects.drain()
	check(front.health < front.max_health and front.bleeds.size() == 1, "横扫命中前方目标并附加一层流血")
	check(is_equal_approx(back.health, back.max_health) and back.bleeds.is_empty(), "横扫拒绝背后目标")

	await clear_targets(arena)
	arena.effects.reset()
	var edge_in: EnemyController = spawn_target(arena, Vector3(0, 0.05, -(SkillRunner.SWEEP.range_m - 0.01)))
	var edge_out: EnemyController = spawn_target(arena, Vector3(0, 0.05, -(SkillRunner.SWEEP.range_m + 0.01)))
	arena.skills.cast_sweep()
	arena.effects.drain()
	check(edge_in.health < edge_in.max_health, "横扫包含资源范围内侧边缘")
	check(is_equal_approx(edge_out.health, edge_out.max_health), "横扫排除资源范围外侧目标")

	await clear_targets(arena)
	arena.effects.reset()
	var blocked: EnemyController = spawn_target(arena, Vector3(0, 0.05, -2.6))
	var wall: StaticBody3D = make_wall(arena, Vector3(0, 0.8, -1.3))
	await get_tree().physics_frame
	arena.skills.cast_sweep()
	arena.effects.drain()
	check(is_equal_approx(blocked.health, blocked.max_health) and blocked.bleeds.is_empty(), "地形视线阻挡横扫直接命中与流血")
	wall.queue_free()
	await get_tree().process_frame

	await clear_targets(arena)
	arena.effects.reset()
	var stacked: EnemyController = spawn_target(arena, Vector3(0, 0.05, -2.0), 3000.0)
	for index: int in range(3):
		arena.skills.cast_sweep()
		arena.effects.drain()
	check(stacked.bleeds.size() == SkillRunner.SWEEP.bleed_max_stacks, "流血层数达到资源上限后保持有界")
	stacked.advance_bleeds(0.5)
	arena.skills.cast_sweep()
	arena.effects.drain()
	var refreshed: int = 0
	for layer: Dictionary in stacked.bleeds:
		if is_equal_approx(float(layer.remaining_sec), SkillRunner.SWEEP.bleed_duration_sec):
			refreshed += 1
	check(stacked.bleeds.size() == 3 and refreshed == 1, "满层后仅替换剩余时间最短的一层并使用新快照")

	stacked.bleeds.clear()
	arena.effects.reset()
	var mixed: BuildDefinition = BLEED_BUILD.duplicate()
	mixed.critical_chance = 1.0
	mixed.chain_count = 2
	mixed.hit_energy = 4.0
	arena.skills.equip(mixed)
	arena.skills.energy = 40.0
	arena.skills.cast_sweep()
	arena.effects.drain()
	var lightning_after_direct: int = arena.effects.lightning_count
	var energy_after_direct: float = arena.skills.energy
	arena.effects.advance_bleeds(SkillRunner.SWEEP.bleed_tick_sec)
	arena.effects.drain()
	check(arena.effects.lightning_count == lightning_after_direct, "流血跳伤不会递归触发暴击闪电")
	check(is_equal_approx(arena.skills.energy, energy_after_direct), "流血跳伤不会发放直接命中回能")

	await clear_targets(arena)
	arena.effects.reset()
	arena._clear_ground()
	arena.wave_completed = false
	arena.combat.kills = 0
	arena.skills.equip(BLEED_BUILD)
	arena.skills.energy = 20.0
	var doomed: EnemyController = spawn_target(arena, Vector3(0, 0.05, -2.0), 200.0)
	var root_id: int = arena.combat.next_attack_id()
	doomed.apply_bleed({
		"source":"player:sweep", "root_attack_id":root_id, "damage":50.0,
		"remaining_sec":2.0, "next_tick_sec":1.0, "tick_interval_sec":1.0,
		"kill_energy":9.0, "death_explosion":false,
		"explosion_radius_m":0.0, "explosion_damage":0.0,
	}, 3)
	doomed.health = 10.0
	var xp_before: int = arena.inventory.experience
	arena.effects.advance_bleeds(1.0)
	arena.effects.drain()
	var gold_after_kill: int = count_ground(arena, "gold")
	check(arena.combat.kills == 1 and arena.inventory.experience == xp_before + 6, "流血击杀登记一次击杀与经验")
	check(is_equal_approx(arena.skills.energy, 29.0), "流血击杀按施加时快照发放一次击杀回能")
	arena.effects.advance_bleeds(5.0)
	arena.effects.drain()
	check(arena.combat.kills == 1 and arena.inventory.experience == xp_before + 6 and count_ground(arena, "gold") == gold_after_kill, "死亡目标后续不会重复发放金币经验或击杀")

	arena.skills.reset()
	var base_armor: float = arena.inventory.defense("armor")
	arena.player.armor = base_armor
	arena.skills.energy = 40.0
	check(arena.skills.cast_warcry(), "F 战吼在就绪时成功施放")
	check(is_equal_approx(arena.player.armor, base_armor + SkillRunner.WARCRY.armor_bonus) and is_equal_approx(arena.skills.energy, 70.0), "战吼提供单层护甲并立即回能")
	arena.skills._warcry_cooldown_remaining = 0.0
	check(arena.skills.cast_warcry() and is_equal_approx(arena.player.armor, base_armor + SkillRunner.WARCRY.armor_bonus) and is_equal_approx(arena.skills._warcry_remaining, SkillRunner.WARCRY.duration_sec), "重复战吼只刷新持续时间且护甲不叠层")
	arena.skills.advance(SkillRunner.WARCRY.duration_sec)
	check(not arena.skills._warcry_applied and is_equal_approx(arena.player.armor, base_armor), "战吼到期准确移除临时护甲")

	arena.skills.reset()
	arena.player.health = arena.player.max_health * 0.4
	var expected_health: float = arena.player.health + arena.player.max_health * SkillRunner.POTION.heal_ratio
	check(arena.skills.use_potion() and is_equal_approx(arena.player.health, expected_health), "Q 药剂按最大生命比例恢复生命")
	var health_after_potion: float = arena.player.health
	check(not arena.skills.use_potion() and is_equal_approx(arena.player.health, health_after_potion), "药剂冷却中快速重复使用被拒绝")
	arena.skills._potion_remaining = 0.0
	arena.player.health = arena.player.max_health
	check(not arena.skills.use_potion() and arena.skills._potion_remaining == 0.0, "满血使用药剂不进入冷却")
	arena.player.is_dead = true
	arena.player.health = 1.0
	check(not arena.skills.use_potion() and arena.skills._potion_remaining == 0.0, "死亡状态使用药剂被拒绝")
	arena.player.is_dead = false

	await clear_targets(arena)
	arena.effects.reset()
	arena._clear_ground()
	arena.wave_completed = false
	var paused_target: EnemyController = spawn_target(arena, Vector3(0, 0.05, -2.0), 1200.0)
	arena.skills.reset()
	arena.player.armor = arena.inventory.defense("armor")
	arena.skills.cast_warcry()
	arena.player.health = arena.player.max_health * 0.5
	arena.skills.use_potion()
	paused_target.apply_bleed(arena.skills._bleed_snapshot(arena.combat.next_attack_id()), SkillRunner.SWEEP.bleed_max_stacks)
	var pause_warcry: float = arena.skills._warcry_remaining
	var pause_potion: float = arena.skills._potion_remaining
	var pause_bleed: float = paused_target.bleeds[0].remaining_sec
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(arena.skills._warcry_remaining, pause_warcry) and is_equal_approx(arena.skills._potion_remaining, pause_potion), "暂停期间战吼与药剂计时停止")
	check(is_equal_approx(float(paused_target.bleeds[0].remaining_sec), pause_bleed), "暂停期间流血计时与跳伤停止")
	var potion_before_paused_use: float = arena.skills._potion_remaining
	arena.skills._potion_remaining = 0.0
	check(not arena.skills.use_potion(), "暂停期间主动药剂请求被拒绝")
	arena.skills._potion_remaining = potion_before_paused_use
	get_tree().paused = false

	check(arena._save_position() == OK, "战斗中流血、战吼与药剂状态可写入完整存档")
	var saved: Dictionary = SaveManager.load_session()
	check(saved.version == 4 and SaveManager.is_valid_session(saved), "D1 完整存档使用 v4 并通过结构校验")
	var saved_enemy: Dictionary = {}
	for entry: Dictionary in saved.expedition.enemies:
		if not entry.bleeds.is_empty():
			saved_enemy = entry
			break
	check(not saved_enemy.is_empty() and saved.expedition.skills._warcry_applied, "v4 保存流血层与战吼生效状态")
	var saved_bleed: Dictionary = saved_enemy.bleeds[0]
	var saved_warcry: float = saved.expedition.skills._warcry_remaining
	var saved_warcry_cd: float = saved.expedition.skills._warcry_cooldown_remaining
	var saved_potion_cd: float = saved.expedition.skills._potion_remaining
	var saved_armor: float = saved.expedition.player.armor
	arena.restore_expedition(saved.expedition)
	var restored_target: EnemyController = bleeding_target(arena)
	if restored_target != null:
		restored_target.set_physics_process(false)
	check(restored_target != null and is_equal_approx(float(restored_target.bleeds[0].remaining_sec), float(saved_bleed.remaining_sec)) and is_equal_approx(float(restored_target.bleeds[0].next_tick_sec), float(saved_bleed.next_tick_sec)), "重载保留流血剩余时间与下一跳")
	check(is_equal_approx(arena.skills._warcry_remaining, saved_warcry) and is_equal_approx(arena.skills._warcry_cooldown_remaining, saved_warcry_cd) and is_equal_approx(arena.player.armor, saved_armor), "重载保留战吼持续、冷却与临时护甲")
	check(is_equal_approx(arena.skills._potion_remaining, saved_potion_cd), "重载保留药剂冷却")
	if restored_target != null:
		var health_before_tick: float = restored_target.health
		arena.effects.advance_bleeds(float(saved_bleed.next_tick_sec) + 0.01)
		arena.effects.drain()
		check(restored_target.health < health_before_tick, "重载后流血从保存的下一跳继续造成剩余伤害")
	var advance_time: float = saved_warcry + 0.01
	arena.skills.advance(advance_time)
	check(not arena.skills._warcry_applied and is_equal_approx(arena.player.armor, arena.inventory.defense("armor")), "重载后的战吼按剩余时间结束并恢复基础护甲")
	check(is_equal_approx(arena.skills._warcry_cooldown_remaining, maxf(0.0, saved_warcry_cd - advance_time)) and is_equal_approx(arena.skills._potion_remaining, maxf(0.0, saved_potion_cd - advance_time)), "重载后的战吼与药剂冷却按剩余时间继续")

	arena.return_to_town()
	check(arena.skills._potion_remaining == 0.0 and not arena.skills._warcry_applied, "返回据点整备重置药剂冷却与战吼临时状态")
	arena.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	print("P1_BLEED_SKILLS_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
