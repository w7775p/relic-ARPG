extends Node
## M1 真实场景回归：伤害、去重、范围、触发、能量与敌人行为。

const ARENA: PackedScene = preload("res://world/maps/combat_arena.tscn")

var _arena: Node3D
var _failures: int = 0
var _deaths: int = 0
var _lightning_targets: Array[int] = []


## 延迟启动，保证自动加载服务已经完成初始化。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


## 等待物理回调和延迟回收完成。
func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


## 记录断言，统一通过进程退出码交付结果。
func _check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)


## 清空案例的敌人、事件和计数，保持同一真实场景。
func _clear() -> void:
	_arena.encounters.clear()
	_arena.effects.reset()
	_arena.combat.kills = 0
	await _frames(2)
	_arena.player.reset_health()
	_arena.player.restore_position(Vector3.ZERO)
	_arena.skills.reset()
	_arena.skills.set_physics_process(false)
	_arena.player.set_physics_process(false)


## 构造可控的普通目标；默认冻结行为，仅测试实际结算。
func _enemy(at: Vector3, health: float = 1000.0, active: bool = false, kind: int = 0) -> EnemyController:
	var definition: EnemyDefinition = EncounterDirector.DEFINITIONS[kind].duplicate()
	definition.health = health
	var enemy: EnemyController = _arena.encounters.spawn_enemy(definition, at)
	enemy.set_physics_process(active)
	return enemy


## 记录死亡通知次数，检查幂等死亡。
func _count_death() -> void:
	_deaths += 1


## 收集闪电目标，检查一次连锁的唯一目标集合。
func _observe_hit(event: DamageEvent) -> void:
	if event.skill_id == &"lightning":
		_lightning_targets.append(event.target.get_instance_id())


## 运行机制与输入行为测试，最后验证敌人攻击和死亡重开。
func _run() -> void:
	_arena = ARENA.instantiate()
	_arena.auto_spawn = false
	add_child(_arena)
	await _frames(12)
	_arena.skills.input_enabled = false
	_arena.combat.hit_resolved.connect(_observe_hit)
	await _clear()
	var basic: BuildDefinition = SkillRunner.BASIC.duplicate()
	basic.critical_chance = 0.0
	_arena.skills.equip(basic)
	var target: EnemyController = _enemy(Vector3(0, 0, -1))
	target.armor = 100.0
	var event: DamageEvent = _arena.combat.hit(target, 100.0, &"primary", 1, basic)
	_check(is_equal_approx(event.amount, 50.0), "护甲按公式减伤")
	basic.critical_chance = 1.0
	event = _arena.combat.hit(target, 100.0, &"primary", 2, basic)
	_check(event.is_critical and is_equal_approx(event.amount, 90.0), "暴击倍率参与结算")
	target.health = 1.0
	target.died.connect(_count_death)
	_arena.combat.hit(target, 100.0, &"primary", 3, basic)
	_arena.combat.hit(target, 100.0, &"primary", 3, basic)
	_check(_deaths == 1 and _arena.combat.kills == 1, "重复命中死亡目标只计一次击杀")
	_check(not _arena.combat.enemies.has(target), "死亡立即移出可命中集合")
	await _clear()
	basic.critical_chance = 0.0
	var front: EnemyController = _enemy(Vector3(0, 0, -1.5))
	var back: EnemyController = _enemy(Vector3(0, 0, 1.5))
	_arena.player.visual_root.rotation = Vector3.ZERO
	_arena.skills.cast_primary()
	_check(front.health < front.max_health and back.health == back.max_health, "普攻只命中前方扇形")
	await _clear()
	for index: int in range(100):
		var angle: float = TAU * index / 100.0
		_enemy(Vector3(cos(angle), 0, sin(angle)) * 2.0)
	_arena.skills.cast_whirlwind()
	var hit_count: int = 0
	for enemy: CombatActor in _arena.combat.enemies:
		if is_equal_approx(enemy.max_health - enemy.health, basic.damage):
			hit_count += 1
	_check(hit_count == 100, "旋风完整命中 100 个范围目标且各扣血一次")
	await _clear()
	_arena.player.restore_position(Vector3(-6, 0, -1))
	target = _enemy(Vector3(-6, 0, -8))
	_check(_arena.combat.targets_in_range(_arena.player.position, 12.0).is_empty(), "地形阻挡范围伤害与连锁视线")
	await _clear()
	var thunder: BuildDefinition = SkillRunner.THUNDER.duplicate()
	thunder.critical_chance = 1.0
	thunder.death_explosion = false
	_arena.skills.equip(thunder)
	_lightning_targets.clear()
	for index: int in range(7):
		_enemy(Vector3(float(index) * 0.5, 0, -2))
	_arena.combat.hit(_arena.combat.enemies[0], 1.0, &"primary", 10, thunder)
	_arena.effects.drain()
	_check(_lightning_targets.size() == thunder.chain_count, "闪电遵守最大连锁目标数")
	var unique: Dictionary = {}
	for id: int in _lightning_targets:
		unique[id] = true
	_check(unique.size() == _lightning_targets.size(), "同次闪电目标不重复")
	_check(_arena.effects.lightning_count == 1, "闪电伤害不会再次触发暴击闪电")
	_check(_arena.combat.enemies[0].shock_remaining_sec > 0.0, "闪电命中存活目标施加感电")
	await _clear()
	thunder.death_explosion = true
	thunder.chain_count = 0
	_arena.skills.equip(thunder)
	for index: int in range(4):
		var enemy: EnemyController = _enemy(Vector3(index, 0, -2), 20.0)
		enemy.shock_remaining_sec = 3.0
	_arena.combat.hit(_arena.combat.enemies[0], 100.0, &"primary", 20, thunder)
	_arena.effects.drain()
	_check(_arena.combat.kills == 4 and _arena.effects.explosion_count == 4, "已感电目标死亡爆炸有限传播")
	_check(_arena.effects.queue.is_empty(), "爆炸事件队列完整排空")
	await _clear()
	target = _enemy(Vector3(0, 0, -2), 10.0)
	_arena.combat.hit(target, 100.0, &"lightning", 30, thunder)
	_arena.effects.drain()
	_check(_arena.effects.explosion_count == 0, "首次闪电直接击杀未感电目标不会爆炸")
	await _clear()
	_arena.skills.equip(basic)
	_arena.skills.energy = 1.0
	_arena.skills.channel_requested = true
	_arena.skills.advance(0.1)
	_check(not _arena.skills.is_channeling and _arena.skills.energy == 0.0, "能量不足立即停止旋风")
	_arena.skills.channel_requested = false
	_arena.skills.advance(1.0)
	_check(is_equal_approx(_arena.skills.energy, basic.idle_energy_regen), "停止施放后按秒恢复能量")
	_arena.skills.energy = 10.0
	_arena.skills.equip(thunder)
	_check(_arena.skills.energy == 10.0 and _arena.player.move_speed_mps == thunder.move_speed_mps, "换装刷新属性并保留现有能量")
	target = _enemy(Vector3(0, 0, -1), 1000.0)
	_arena.combat.hit(target, 1.0, &"primary", 40, thunder)
	_arena.effects.drain()
	_check(is_equal_approx(_arena.skills.energy, 10.0 + thunder.hit_energy), "单体直接命中也能回复能量")
	await _clear()
	_arena.player.max_health = 300.0
	_arena.player.reset_health()
	target = _enemy(Vector3(0, 0, -1.5), 1000.0, true)
	await _frames(120)
	_check(target.attacks_performed > 0 and _arena.player.health < 300.0, "近战怪蓄力后实际造成伤害")
	var paused_position: Vector3 = target.position
	var paused_health: float = _arena.player.health
	_arena._set_paused(true)
	await _frames(10)
	_check(target.position.is_equal_approx(paused_position) and _arena.player.health == paused_health, "暂停时敌人导航与伤害均停止")
	_check(not _arena.get_node("Interface/CombatInfo").visible, "暂停菜单覆盖战斗信息面板")
	_arena._set_paused(false)
	await _clear()
	target = _enemy(Vector3(0, 0, -5), 1000.0, true, 1)
	await _frames(150)
	_check(target.attacks_performed > 0 and _arena.player.health < 300.0, "远程弹体扫掠命中玩家")
	await _clear()
	target = _enemy(Vector3(0, 0, -6), 1000.0, true, 2)
	await _frames(180)
	_check(target.attacks_performed > 0 and _arena.player.health < 300.0, "冲锋怪锁定方向后突进命中")
	_arena.combat.hit_player(10000.0)
	_check(_arena.player.is_dead, "玩家死亡状态生效")
	_arena.restart(24)
	await _frames(3)
	_check(not _arena.player.is_dead and _arena.combat.enemies.size() == 24, "死亡后可重开并清理旧事件与弹体")
	_check(_arena.effects.queue.is_empty() and _arena.get_node("Projectiles").get_child_count() == 0, "重开没有残留触发或投射物")
	print("M1_COMBAT_RESULT: ", _failures, " failures")
	get_tree().quit(0 if _failures == 0 else 1)
