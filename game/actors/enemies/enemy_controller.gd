class_name EnemyController
extends CombatActor
## 原生导航追击与三种攻击状态；静态定义由遭遇管理器注入。

const PROJECTILE: PackedScene = preload("res://actors/enemies/projectile.tscn")

enum State { CHASE, WINDUP, CHARGE, RECOVER }

var definition: EnemyDefinition
var combat: CombatSystem
var feedback: CombatFeedback
var projectile_root: Node3D
var state: State = State.CHASE
var state_remaining: float = 0.0
var _cooldown: float = 0.0
var _path_remaining: float = 0.0
var _locked_direction: Vector3 = Vector3.FORWARD
var _flash_remaining: float = 0.0
var _material: StandardMaterial3D
var attacks_performed: int = 0

@onready var navigation: NavigationAgent3D = $NavigationAgent


## 注入属性与独立材质，错开重新寻路和首次攻击时间。
func _ready() -> void:
	max_health = definition.health
	armor = definition.armor
	super._ready()
	_material = $Visual/Body.mesh.material.duplicate()
	$Visual/Body.material_override = _material
	_material.albedo_color = definition.tint
	if definition.is_elite:
		$Visual.scale = Vector3.ONE * 1.35
	_path_remaining = float(get_instance_id() % 17) * 0.025
	_cooldown = float(get_instance_id() % 11) * 0.08
	died.connect(_on_died)
	health_changed.connect(_on_health_changed)
	combat.register_enemy(self)


## 推进状态并移动，导航数据尚未同步时保持原地。
func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(combat.player) or combat.player.is_dead:
		return
	tick_status(delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_path_remaining -= delta
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	_material.albedo_color = Color.WHITE if _flash_remaining > 0.0 else (Color(0.25, 0.8, 1.0) if shock_remaining_sec > 0.0 else definition.tint)
	var offset: Vector3 = combat.player.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()
	var path_velocity: Vector3 = _chase_velocity()
	var movement: Vector3 = Vector3.ZERO
	match state:
		State.WINDUP:
			state_remaining -= delta
			if state_remaining <= 0.0:
				_execute_attack()
		State.CHARGE:
			movement = _locked_direction * 13.0
			state_remaining -= delta
			if distance < 1.4 and combat.has_line_of_sight(global_position, combat.player.global_position):
				combat.hit_player(definition.damage)
				state_remaining = 0.0
			if state_remaining <= 0.0:
				state = State.RECOVER
				state_remaining = 0.4
		State.RECOVER:
			state_remaining -= delta
			if state_remaining <= 0.0:
				state = State.CHASE
		State.CHASE:
			if _can_attack(distance):
				_begin_attack(offset)
			else:
				movement = path_velocity
	if stagger_remaining_sec > 0.0 and not definition.is_elite:
		movement = Vector3.ZERO
	velocity.x = movement.x + knockback_velocity.x
	velocity.z = movement.z + knockback_velocity.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 24.0 * delta
	navigation.velocity = Vector3(velocity.x, 0.0, velocity.z)
	if state == State.CHARGE and is_on_wall():
		state = State.RECOVER
		state_remaining = 0.4
	if movement.length_squared() > 0.1:
		$Visual.rotation.y = atan2(-movement.x, -movement.z)


## 各类敌人使用不同启动距离；攻击前检查地形视线。
func _can_attack(distance: float) -> bool:
	if _cooldown > 0.0:
		return false
	var reach: float = 1.7
	if definition.kind == EnemyDefinition.Kind.RANGED:
		reach = 10.0
	elif definition.kind == EnemyDefinition.Kind.CHARGER:
		reach = 8.0
	return distance <= reach and combat.has_line_of_sight(global_position, combat.player.global_position)


## 每 0.4 秒更新目的地，逐物理帧推进原生导航路径。
func _chase_velocity() -> Vector3:
	if NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map()) == 0:
		return Vector3.ZERO
	if _path_remaining <= 0.0:
		_path_remaining = 0.4
		navigation.target_position = combat.player.global_position
	var next: Vector3 = navigation.get_next_path_position()
	var direction: Vector3 = next - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return Vector3.ZERO
	return direction.normalized() * definition.speed_mps


## 蓄力时锁定方向并显示红色危险范围，允许玩家走位躲避。
func _begin_attack(offset: Vector3) -> void:
	state = State.WINDUP
	state_remaining = definition.windup_sec
	_locked_direction = offset.normalized() if offset.length_squared() > 0.001 else Vector3.FORWARD
	feedback.ring(global_position, 1.8, Color(1.0, 0.18, 0.14), definition.windup_sec)
	if definition.kind == EnemyDefinition.Kind.CHARGER:
		feedback.beam(global_position, global_position + _locked_direction * 8.0, Color(1.0, 0.2, 0.1), definition.windup_sec, 0.12)


## 蓄力结束执行攻击；近战重新检查距离，远程发射具有扫掠碰撞的弹体。
func _execute_attack() -> void:
	attacks_performed += 1
	_cooldown = definition.attack_cooldown_sec
	state = State.RECOVER
	state_remaining = 0.25
	match definition.kind:
		EnemyDefinition.Kind.MELEE:
			if global_position.distance_to(combat.player.global_position) <= 2.0 and combat.has_line_of_sight(global_position, combat.player.global_position):
				combat.hit_player(definition.damage)
			feedback.slash(global_position, _locked_direction, Color(1.0, 0.3, 0.2))
		EnemyDefinition.Kind.RANGED:
			var projectile: EnemyProjectile = PROJECTILE.instantiate()
			projectile.combat = combat
			projectile.direction = _locked_direction
			projectile.damage = definition.damage
			projectile_root.add_child(projectile)
			projectile.global_position = global_position + Vector3.UP * 0.8 + _locked_direction * 0.6
		EnemyDefinition.Kind.CHARGER:
			state = State.CHARGE
			state_remaining = 0.65


## 受击时短暂闪白，并更新原生血条比例。
func _on_health_changed(current: float, maximum: float) -> void:
	_flash_remaining = 0.07
	$HealthBar.scale.x = maxf(0.001, current / maximum)


## 先停止行动与碰撞，再播放倒下动画，最后回收节点。
func _on_died() -> void:
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	$HealthBar.hide()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Visual, "rotation:z", PI * 0.5, 0.18)
	tween.tween_property($Visual, "scale", Vector3.ONE * 0.05, 0.3)
	tween.chain().tween_callback(queue_free)


## 原生局部避让返回安全速度后移动，敌人间不再进行昂贵的刚性碰撞。
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_dead or combat.player.is_dead or not is_physics_processing():
		return
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()
