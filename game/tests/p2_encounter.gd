extends Node
## 第三构筑独立战斗回归：正式敌人 AI、测试装备、固定物理帧与有限能量循环。
const ARENA: PackedScene = preload("res://world/maps/combat_arena.tscn")
const BUILD: BuildDefinition = preload("res://debug/charge_test.tres")
var failures: int = 0
var checks: int = 0

## 等待正式服务初始化后执行两种遭遇。
func _ready() -> void:
	_run.call_deferred()

## 记录战斗结果与能量边界。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 怪群与精英均保留正常生命、护甲、伤害和 AI，不在战斗中回满资源。
func fight(elite: bool) -> void:
	var arena: Node3D = ARENA.instantiate()
	arena.auto_spawn = false
	get_tree().root.add_child(arena)
	arena.skills.equip(BUILD.duplicate())
	arena.skills.loadout.set_skill("basic", "heavy")
	arena.skills.loadout.set_skill("main", "")
	arena.skills.loadout.set_skill("auxiliary", "charge")
	arena.skills.input_enabled = false
	# 固定朝向与站位，运动仍交由真实冲锋物理接口；敌人保留正常 AI。
	arena.player.set_physics_process(false)
	arena.player.restore_position(Vector3(0, 0.05, 0))
	var count: int = 1 if elite else 6
	for index: int in range(count):
		var at: Vector3 = Vector3(sin(float(index) * 0.5) * 2.0, 0.05, -2.0 - cos(float(index) * 0.5))
		arena.encounters.spawn_enemy(EncounterDirector.ELITE if elite else EncounterDirector.DEFINITIONS[0], at)
	var lowest: float = 100.0
	var recharge_frames: int = 0
	var elapsed: float = 0.0
	var charge_count: int = 0
	var last_charge: float = 0.0
	for frame: int in range(2400):
		if arena.combat.enemies.is_empty() or arena.player.is_dead:
			break
		var target: CombatActor = arena.combat.enemies[0]
		if arena.player.charge_remaining_m <= 0.0 and not arena.player.attack_locked:
			arena.player.visual_root.look_at(Vector3(target.global_position.x, arena.player.global_position.y, target.global_position.z), Vector3.UP)
		arena.skills.primary_requested = true
		arena.skills.auxiliary_requested = arena.skills.charge.cooldown_sec <= 0.0 and arena.skills.heavy.phase == HeavyAttack.Phase.IDLE and arena.player.global_position.distance_to(target.global_position) > 2.0 and arena.skills.energy >= 46.0
		arena.skills.potion_requested = arena.player.health < arena.player.max_health * 0.5
		arena.player.advance_charge(1.0 / 60.0)
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		lowest = minf(lowest, arena.skills.energy)
		if arena.skills.energy < HeavyAttack.DEFINITION.energy_cost:
			recharge_frames += 1
		if arena.skills.charge.cooldown_sec > last_charge:
			charge_count += 1
		last_charge = arena.skills.charge.cooldown_sec
	var name: String = "单精英" if elite else "六只普通怪群"
	check(arena.combat.enemies.is_empty() and not arena.player.is_dead, "冲锋重击独立击杀" + name)
	check(arena.skills.energy >= 0.0 and arena.skills.energy <= 100.0 and charge_count >= 1, "遭遇内完成冲锋且能量保持合法：" + name)
	if elite:
		check(recharge_frames > 0, "单精英战进入低能量恢复阶段后仍能继续重击")
	print("P2_ENERGY: ", name, " seconds=", snappedf(elapsed, 0.01), " min=", snappedf(lowest, 0.01), " end=", snappedf(arena.skills.energy, 0.01), " low_energy_frames=", recharge_frames, " charges=", charge_count, " health=", snappedf(arena.player.health, 0.01))
	arena.queue_free()
	await get_tree().process_frame

## 两种遭遇分别从相同测试装备与初始资源开始。
func _run() -> void:
	await fight(false)
	await fight(true)
	print("P2_ENCOUNTER_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
