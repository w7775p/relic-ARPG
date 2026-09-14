extends Node
## P1_Task3 精英回归：两种修饰参数生效，并验证实例修改不会污染共享原型或其他精英。
const ARENA: PackedScene = preload("res://world/maps/combat_arena.tscn")
var failures: int = 0
var checks: int = 0

## 记录断言结果并继续执行全部检查。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

## 延迟进入真实场地，保证导航和节点依赖完成初始化。
func _ready() -> void:
	_run.call_deferred()

## 生成两只同原型精英，比较坚韧与迅捷的可测属性和实例隔离。
func _run() -> void:
	check(EncounterDirector.ELITE_MODIFIERS.size() == 2, "D1 精英修饰总量为 2")
	var tough_def: EliteModifierDefinition = EncounterDirector.elite_modifier("tough")
	var swift_def: EliteModifierDefinition = EncounterDirector.elite_modifier("swift")
	check(tough_def != null and tough_def.display_name == "坚韧" and tough_def.supports(EncounterDirector.ELITE), "坚韧记录名称、参数与精英兼容性")
	check(swift_def != null and swift_def.display_name == "迅捷" and swift_def.supports(EncounterDirector.ELITE), "迅捷记录名称、参数与精英兼容性")
	var arena: Node3D = ARENA.instantiate()
	arena.auto_spawn = false
	get_tree().root.add_child(arena)
	await get_tree().process_frame
	get_tree().paused = true
	var prototype_health: float = EncounterDirector.ELITE.health
	var prototype_speed: float = EncounterDirector.ELITE.speed_mps
	var tough: EnemyController = arena.encounters.spawn_enemy(EncounterDirector.ELITE, Vector3(-10, 0.05, 0), tough_def)
	var swift: EnemyController = arena.encounters.spawn_enemy(EncounterDirector.ELITE, Vector3(10, 0.05, 0), swift_def)
	check(tough.modifier == tough_def and swift.modifier == swift_def, "每只精英最多持有单个修饰引用")
	check(tough.max_health > swift.max_health and tough.armor > swift.armor, "坚韧可测提高生命与护甲")
	check(swift.runtime_speed_mps > tough.runtime_speed_mps and swift.runtime_attack_cooldown_sec < tough.runtime_attack_cooldown_sec, "迅捷可测提高移动与攻击频率")
	var swift_health: float = swift.max_health
	var swift_speed: float = swift.runtime_speed_mps
	tough.max_health = 1.0
	tough.runtime_speed_mps = 99.0
	check(is_equal_approx(swift.max_health, swift_health) and is_equal_approx(swift.runtime_speed_mps, swift_speed), "修改一只同底材精英不会污染另一只")
	check(is_equal_approx(EncounterDirector.ELITE.health, prototype_health) and is_equal_approx(EncounterDirector.ELITE.speed_mps, prototype_speed), "运行时修饰不会改写共享 EnemyDefinition 原型")
	check(tough.runtime_tint != swift.runtime_tint, "两种修饰具有不同基础表现色")
	get_tree().paused = false
	arena.queue_free()
	await get_tree().process_frame
	print("P1_TASK3_ELITES_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
