class_name EnemyProjectile
extends Node3D
## 远程弹体沿锁定方向运动，每帧扫掠检测避免高速穿墙或穿过玩家。

var combat: CombatSystem
var direction: Vector3
var damage: float = 14.0
var lifetime_sec: float = 3.0
var speed_mps: float = 10.0


## 物理帧扫掠世界和玩家碰撞层，首次碰撞后回收。
func _physics_process(delta: float) -> void:
	lifetime_sec -= delta
	if lifetime_sec <= 0.0 or combat.player.is_dead:
		queue_free()
		return
	var next: Vector3 = global_position + direction * speed_mps * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, next, 3)
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		if result.collider == combat.player:
			combat.hit_player(damage)
		queue_free()
		return
	global_position = next
