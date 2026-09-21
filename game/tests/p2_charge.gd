extends Node
## D2 冲锋实际物理回归：薄墙、墙角、入口、敌人碰撞、沿途命中去重和暂停。
const ARENA: PackedScene = preload("res://world/maps/combat_arena.tscn")
var failures: int = 0
var checks: int = 0
var arena: Node3D

## 独立测试驱动在暂停时保留断言能力。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

## 输出可定位断言与统一完成标记。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 创建世界层薄墙；尺寸为米。
func wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)
	body.global_position = at
	return body

## 使用正式敌人碰撞与注册路径，但停用 AI 以分离运动判定。
func target(at: Vector3) -> EnemyController:
	var definition: EnemyDefinition = EncounterDirector.DEFINITIONS[0].duplicate()
	definition.health = 1000.0
	var enemy: EnemyController = arena.encounters.spawn_enemy(definition, at)
	enemy.set_physics_process(false)
	return enemy

## 以固定原点和朝向开始下一条独立断言。
func reset() -> void:
	arena.skills.reset()
	arena.effects.reset()
	arena.player.restore_position(Vector3(0, 0.05, 0))
	arena.player.visual_root.rotation = Vector3.ZERO

## 执行真实物理扫掠，允许墙体、敌人先进入物理世界。
func run_charge() -> void:
	await get_tree().physics_frame
	check(arena.skills.charge.cast(), "冲锋合法起手并扣费")
	for index: int in range(30):
		arena.player.advance_charge(1.0 / 60.0)
		await get_tree().physics_frame

## 覆盖冲锋几何与有限组合增益，输出实际位移。
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
	await run_charge()
	check(absf(arena.player.position.z + 7.0) < 0.01, "空地冲锋按七米距离停止")
	check(arena.skills.energy == 82.0 and not arena.skills.charge.cast(), "消耗一次能量且冷却中拒绝重复施放")
	check(arena.skills.charge.combo_remaining_sec == 0.0, "空冲不发放组合增益")

	reset()
	var thin: StaticBody3D = wall(Vector3(0, 1.0, -2.0), Vector3(6, 2, 0.04))
	await run_charge()
	check(arena.player.position.z > -1.61 and arena.player.charge_remaining_m == 0.0, "四厘米薄墙阻挡真实胶囊扫掠")
	thin.queue_free()
	await get_tree().physics_frame

	reset()
	var left: StaticBody3D = wall(Vector3(-0.55, 1, -2), Vector3(0.6, 2, 2))
	var right: StaticBody3D = wall(Vector3(0.55, 1, -2), Vector3(0.6, 2, 2))
	await run_charge()
	check(arena.player.position.z > -1.0, "五十厘米狭口无法穿过直径八十厘米角色")
	left.queue_free()
	right.queue_free()
	await get_tree().physics_frame

	reset()
	var corner_a: StaticBody3D = wall(Vector3(0, 1, -2), Vector3(5, 2, 0.1))
	var corner_b: StaticBody3D = wall(Vector3(-2, 1, 0), Vector3(0.1, 2, 5))
	arena.player.visual_root.rotation.y = PI / 4.0
	await run_charge()
	check(arena.player.position.z > -1.6 and arena.player.position.x > -1.6 and arena.player.charge_remaining_m == 0.0, "斜向墙角停止且不沿墙滑过转角")
	corner_a.queue_free()
	corner_b.queue_free()
	await get_tree().physics_frame

	reset()
	var enemy: EnemyController = target(Vector3(0, 0.05, -2))
	await run_charge()
	check(arena.player.position.z > -2.0 and enemy.health < enemy.max_health, "冲锋撞敌人停止并结算直接命中")
	check(is_equal_approx(enemy.health, enemy.max_health - build.damage * 1.2 * 100.0 / (100.0 + enemy.armor)), "同一冲锋对接触敌人只命中一次")
	check(arena.skills.charge.combo_remaining_sec == 3.0 and arena.skills.charge.consume_combo() == 0.6 and arena.skills.charge.consume_combo() == 0.0, "命中冲锋只有一层一次性限时增益")
	arena.encounters.clear()
	await get_tree().physics_frame

	reset()
	var side: EnemyController = target(Vector3(1.0, 0.05, -2))
	await run_charge()
	check(absf(arena.player.position.z + 7.0) < 0.01 and side.health < side.max_health, "沿途擦身目标进入命中半径且不阻挡碰撞外路径")
	check(is_equal_approx(side.health, side.max_health - build.damage * 1.2 * 100.0 / (100.0 + side.armor)), "沿途多个物理帧不会重复命中同一目标")
	arena.skills.charge.advance(3.01)
	check(arena.skills.charge.consume_combo() == 0.0, "组合增益超时失效")
	arena.encounters.clear()
	await get_tree().physics_frame

	reset()
	check(arena.skills.charge.cast(), "暂停前冲锋起手")
	var position_before: Vector3 = arena.player.position
	get_tree().paused = true
	arena.player.advance_charge(1.0)
	check(arena.player.position == position_before and not arena.skills.charge.cast(), "暂停保持位移与攻击状态并拒绝新施放")
	get_tree().paused = false
	arena.player.cancel_charge()
	check(arena.player.charge_remaining_m == 0.0 and arena.skills.charge.combo_remaining_sec == 0.0, "取消停止运动并清空增益")
	arena.skills.reset()
	check(arena.skills.charge.cooldown_sec == 0.0, "新探险重置冲锋冷却")
	arena.queue_free()
	await get_tree().process_frame
	print("P2_CHARGE_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
