extends "res://tests/p2_charge.gd"
## D2 重击实际动作回归，复用冲锋测试的场地/目标工具。

## 验证前摇伤害、恢复期、取消、快照和组合消费。
func _run() -> void:
	arena = ARENA.instantiate()
	arena.auto_spawn = false
	get_tree().root.add_child(arena)
	arena.player.set_physics_process(false)
	arena.skills.set_physics_process(false)
	var build: BuildDefinition = SkillRunner.BASIC.duplicate()
	build.critical_chance = 0.0
	arena.skills.equip(build)
	reset()
	var enemy: EnemyController = target(Vector3(0, 0.05, -2))
	enemy.armor = 0.0
	check(arena.skills.heavy.cast(), "重击从合法起手进入前摇")
	check(arena.skills.energy == 72.0 and arena.player.attack_locked and not arena.skills.heavy.cast() and not arena.skills.charge.cast(), "前摇扣费一次并锁定其他动作")
	arena.skills.heavy.advance(0.34)
	check(enemy.health == 1000.0, "前摇截止前尚未造成伤害")
	var timer: float = arena.skills.heavy.remaining_sec
	get_tree().paused = true
	arena.skills.heavy.advance(10.0)
	check(arena.skills.heavy.remaining_sec == timer and enemy.health == 1000.0, "暂停十秒不跳过重击前摇")
	get_tree().paused = false
	arena.skills.heavy.advance(0.01)
	var expected: float = build.damage * HeavyAttack.DEFINITION.damage_multiplier
	check(is_equal_approx(enemy.health, 1000.0 - expected) and arena.skills.heavy.phase == HeavyAttack.Phase.RECOVERY, "规定时点单次结算并进入恢复期")
	check(is_equal_approx(enemy.knockback_velocity.length(), 7.0), "重击向外施加七米每秒击退")
	check(not arena.skills.heavy.cast(), "恢复期禁止再次起手")
	arena.skills.heavy.advance(0.46)
	check(arena.skills.heavy.phase == HeavyAttack.Phase.IDLE and not arena.player.attack_locked and is_equal_approx(enemy.health, 1000.0 - expected), "恢复结束解锁移动且没有重复伤害")

	reset()
	enemy.reset_health()
	check(arena.skills.heavy.cast(), "取消测试起手")
	arena.player.dodge_started.emit()
	arena.skills.heavy.advance(1.0)
	check(enemy.health == 1000.0 and arena.skills.energy == 72.0 and arena.skills.heavy.phase == HeavyAttack.Phase.IDLE, "闪避取消前摇丢弃攻击且不退还消耗")
	arena.skills.energy = 27.0
	check(not arena.skills.heavy.cast() and arena.skills.energy == 27.0, "能量不足起手失败保持资源")

	reset()
	arena.skills.heavy.cast()
	arena.player.receive_damage(arena.player.health)
	arena.skills.heavy.advance(1.0)
	check(enemy.health == 1000.0 and not arena.player.attack_locked and arena.skills.heavy.phase == HeavyAttack.Phase.IDLE, "死亡同步取消重击且无死后攻击")
	arena.player.reset_health()
	reset()
	arena.skills.heavy.cast()
	var changed: BuildDefinition = build.duplicate()
	changed.damage = 999.0
	arena.skills.equip(changed)
	arena.skills.heavy.advance(0.35)
	check(is_equal_approx(enemy.health, 1000.0 - expected), "前摇中换装不会改写已冻结的攻击快照")
	arena.skills.equip(build)

	reset()
	enemy.reset_health()
	await run_charge()
	var before: float = enemy.health
	check(arena.skills.heavy.cast() and arena.skills.charge.combo_remaining_sec == 0.0, "命中冲锋的限时增益在下一次重击起手消费")
	arena.skills.heavy.advance(0.35)
	check(is_equal_approx(before - enemy.health, expected * 1.6), "组合重击按配置提高六成伤害")
	arena.skills.heavy.advance(0.46)
	before = enemy.health
	arena.skills.heavy.cast()
	arena.skills.heavy.advance(0.35)
	check(is_equal_approx(before - enemy.health, expected), "第二次重击恢复原伤害，增益不可重复利用")

	reset()
	enemy.reset_health()
	await run_charge()
	before = enemy.health
	arena.skills.heavy.cast()
	arena.player.dodge_started.emit()
	arena.skills.energy = 100.0
	arena.skills.heavy.cast()
	arena.skills.heavy.advance(0.35)
	check(is_equal_approx(before - enemy.health, expected), "取消已强化的前摇仍消费组合增益")
	arena.encounters.clear()
	await get_tree().physics_frame

	reset()
	var blocked: EnemyController = target(Vector3(0, 0.05, -2))
	var outside: EnemyController = target(Vector3(3.3, 0.05, 0))
	var behind: EnemyController = target(Vector3(0, 0.05, 2))
	var barrier: StaticBody3D = wall(Vector3(0, 1, -1), Vector3(4, 2, 0.05))
	await get_tree().physics_frame
	arena.skills.heavy.cast()
	arena.skills.heavy.advance(2.0)
	check(blocked.health == blocked.max_health and outside.health == outside.max_health, "重击排除墙后和半径外目标")
	check(behind.health < behind.max_health and arena.skills.heavy.phase == HeavyAttack.Phase.IDLE, "环形重击覆盖身后，大步长完整结算且不重复")
	barrier.queue_free()
	arena.skills.reset()
	check(arena.skills.heavy.phase == HeavyAttack.Phase.IDLE and arena.skills.charge.combo_remaining_sec == 0.0, "离场重置清空动作和组合增益")
	arena.queue_free()
	await get_tree().process_frame
	print("P2_HEAVY_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
