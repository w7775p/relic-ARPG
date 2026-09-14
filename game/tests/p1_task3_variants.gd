extends Node
## P1_Task3 场地回归：两种固定布局复用现有墙体与三类敌人，并验证正式探险选型记录。
const EXPEDITION: PackedScene = preload("res://world/maps/expedition_runtime.tscn")
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

## 延迟运行正式探险，确保自动加载服务已经可用。
func _ready() -> void:
	_run.call_deferred()

## 检查两套出生布局、三类敌人和本趟变体/精英修饰记录。
func _run() -> void:
	check(EncounterDirector.VARIANT_IDS == ["corner_grid", "cross_lanes"], "固定场地提供两个稳定变体 ID")
	var different: int = 0
	for index: int in range(48):
		var corner: Vector3 = EncounterDirector.spawn_position(index, "corner_grid")
		var cross: Vector3 = EncounterDirector.spawn_position(index, "cross_lanes")
		if not corner.is_equal_approx(cross):
			different += 1
		check(absf(corner.x) < 19.0 and absf(corner.z) < 19.0 and absf(cross.x) < 19.0 and absf(cross.z) < 19.0, "变体出生点 %d 位于现有场地边界内" % index)
	check(different == 48, "两种布局的全部出生点均发生可见变化")
	var kind_sets: Array[Dictionary] = [{}, {}]
	for variant_index: int in range(2):
		for index: int in range(47):
			kind_sets[variant_index][EncounterDirector.definition_index_for_variant(index, EncounterDirector.VARIANT_IDS[variant_index])] = true
	check(kind_sets[0].size() == 3 and kind_sets[1].size() == 3, "两种遭遇均复用三类普通敌人")
	var arena: Node3D = EXPEDITION.instantiate()
	arena.forced_variant_id = "cross_lanes"
	arena.forced_modifier_id = "swift"
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await _frames(3)
	get_tree().paused = true
	check(arena.encounter_variant_id == "cross_lanes" and arena.elite_modifier_id == "swift", "正式探险记录本趟变体 ID 与单个精英修饰 ID")
	check(arena.combat.enemies.size() == 48, "变体探险仍生成 48 名敌人")
	var elites: Array[EnemyController] = []
	for enemy: CombatActor in arena.combat.enemies:
		if enemy is EnemyController and enemy.definition.is_elite:
			elites.append(enemy)
	check(elites.size() == 1 and elites[0].modifier != null and elites[0].modifier.id == "swift", "正式探险保留单精英原型并应用一项修饰")
	for victim: CombatActor in arena.combat.enemies.duplicate():
		arena.combat.hit(victim, 1000000.0, &"primary", 9001, arena.skills.build)
	arena.effects.drain(1000000)
	check(arena.wave_completed and arena.inventory.completed == 1, "cross_lanes 可完成清场并正常结算首通")
	var session: GameSession = arena.game_session
	arena.return_to_town()
	await _frames(5)
	var hub: Control = get_tree().current_scene
	check(hub.is_hub() and hub.game_session == session, "变体清场后可撤离回真实 Hub")
	hub.request_transition("depart")
	await _frames(5)
	arena = get_tree().current_scene
	check(EncounterDirector.VARIANT_IDS.has(arena.encounter_variant_id) and arena.combat.enemies.size() == 48, "再次出发会重建一个合法本趟变体")
	arena.return_to_town()
	await _frames(5)
	hub = get_tree().current_scene
	check(hub.is_hub() and hub.inventory.completed == 1, "未清场撤离保持既有通关进度且运行态变体不进入长期数据")
	hub.queue_free()
	await _frames()
	get_tree().paused = false
	print("P1_TASK3_VARIANTS_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)

## 等待场景切换与延迟回收完成。
func _frames(count: int = 2) -> void:
	for index: int in range(count):
		await get_tree().process_frame
