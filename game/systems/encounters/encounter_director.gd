class_name EncounterDirector
extends Node
## 在固定场地创建可重复怪群；压力模式维持指定敌人数。

const ENEMY: PackedScene = preload("res://actors/enemies/enemy.tscn")
const DEFINITIONS: Array[EnemyDefinition] = [
	preload("res://content/enemies/melee.tres"),
	preload("res://content/enemies/ranged.tres"),
	preload("res://content/enemies/charger.tres"),
]
const ELITE: EnemyDefinition = preload("res://content/enemies/elite.tres")

var combat: CombatSystem
var feedback: CombatFeedback
var enemy_root: Node3D
var projectile_root: Node3D
var maintain_population: bool = false
var target_population: int = 24
var wave: int = 0
var _spawn_index: int = 0


## 压力模式逐帧补充死亡目标，正常模式由玩家重开遭遇。
func _physics_process(_delta: float) -> void:
	if maintain_population and not combat.player.is_dead:
		var count: int = mini(8, target_population - combat.enemies.size())
		for index: int in range(maxi(0, count)):
			spawn_enemy(DEFINITIONS[_spawn_index % DEFINITIONS.size()], _spawn_position(_spawn_index))


## 建立新怪群，最后一名固定为精英，确保单次试玩包含精英目标。
func start_wave(count: int = 24) -> void:
	clear()
	wave += 1
	target_population = count
	_spawn_index = 0
	for index: int in range(count):
		var definition: EnemyDefinition = ELITE if index == count - 1 else DEFINITIONS[index % DEFINITIONS.size()]
		spawn_enemy(definition, _spawn_position(index))


## 四个角落使用网格间距，避免出生在中央静态障碍内。
func _spawn_position(index: int) -> Vector3:
	var centers: Array[Vector3] = [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 12), Vector3(11, 0, 12)]
	var cell: int = (index / 4) % 25
	return centers[index % 4] + Vector3(float(cell % 5 - 2) * 1.1, 0.05, float(cell / 5 - 2) * 1.1)


## 注入会话依赖后实例化敌人，便于测试指定属性与位置。
func spawn_enemy(definition: EnemyDefinition, at: Vector3) -> EnemyController:
	var enemy: EnemyController = ENEMY.instantiate()
	enemy.definition = definition
	enemy.combat = combat
	enemy.feedback = feedback
	enemy.projectile_root = projectile_root
	enemy.position = at
	enemy_root.add_child(enemy)
	_spawn_index += 1
	return enemy


## 回收旧怪群、尸体与在途弹体，清空可命中集合。
func clear() -> void:
	combat.enemies.clear()
	for child: Node in enemy_root.get_children():
		child.set_physics_process(false)
		child.set_deferred("collision_layer", 0)
		child.set_deferred("collision_mask", 0)
		child.queue_free()
	for child: Node in projectile_root.get_children():
		child.set_physics_process(false)
		child.queue_free()
