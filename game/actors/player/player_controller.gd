class_name PlayerController
extends CombatActor
## 处理移动、地面瞄准、闪避与技能视觉朝向。

signal dodge_started

signal charge_advanced(from: Vector3, to: Vector3)
signal charge_finished(completed: bool)

@export var move_speed_mps: float = 7.0
@export var dodge_speed_mps: float = 18.0
@export var dodge_duration_sec: float = 0.18
@export var dodge_cooldown_sec: float = 0.7

var attack_locked: bool = false
var charge_remaining_m: float = 0.0
var _charge_direction: Vector3 = Vector3.FORWARD
var _charge_speed_mps: float = 0.0
var skills: SkillRunner

var dodge_remaining_sec: float = 0.0
var cooldown_remaining_sec: float = 0.0
var _dodge_direction: Vector3 = Vector3.FORWARD

@onready var visual_root: Node3D = $VisualRoot


## 在物理帧中移动；斜向输入由 Input.get_vector 自动归一化。
func _physics_process(delta: float) -> void:
	if is_dead:
		cancel_charge()
		velocity = Vector3.ZERO
		return
	tick_status(delta)
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y)
	cooldown_remaining_sec = maxf(0.0, cooldown_remaining_sec - delta)
	dodge_remaining_sec = maxf(0.0, dodge_remaining_sec - delta)
	if charge_remaining_m <= 0.0 and not attack_locked:
		_update_aim()
	if attack_locked:
		pass
	elif is_instance_valid(skills) and skills.is_channeling:
		$VisualRoot/WeaponSocket.rotation.y += delta * 20.0
	else:
		$VisualRoot/WeaponSocket.rotation.y = 0.0
	if Input.is_action_just_pressed("dodge") and cooldown_remaining_sec <= 0.0:
		cancel_charge()
		dodge_started.emit()
		_dodge_direction = direction if direction.length_squared() > 0.01 else -visual_root.global_basis.z
		dodge_remaining_sec = dodge_duration_sec
		cooldown_remaining_sec = dodge_cooldown_sec
		AudioManager.play_cue(0.6)
	if charge_remaining_m > 0.0:
		advance_charge(delta)
		return
	var movement: Vector3 = Vector3.ZERO if attack_locked else direction * move_speed_mps
	if dodge_remaining_sec > 0.0:
		movement = _dodge_direction * dodge_speed_mps
	velocity.x = movement.x
	velocity.z = movement.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if global_position.y < -5.0:
		restore_position(Vector3.ZERO)


## 将鼠标射线投向角色脚下水平面，仅转动视觉节点。
func _update_aim() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var plane: Plane = Plane(Vector3.UP, global_position.y)
	var target: Variant = plane.intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if target is Vector3:
		var offset: Vector3 = target - global_position
		if offset.length_squared() > 0.04:
			visual_root.look_at(global_position + offset, Vector3.UP)


## 恢复存档或回到出生点时清除速度和闪避瞬态。
func restore_position(value: Vector3) -> void:
	cancel_charge()
	global_position = value
	velocity = Vector3.ZERO
	dodge_remaining_sec = 0.0
	cooldown_remaining_sec = 0.0


## 开始固定瞄准方向的冲锋，距离为米、速度为米/秒；移动只通过物理碰撞接口。
func start_charge(direction: Vector3, distance_m: float, speed_mps: float) -> bool:
	if is_dead or charge_remaining_m > 0.0 or dodge_remaining_sec > 0.0:
		return false
	_charge_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if _charge_direction.is_zero_approx():
		return false
	charge_remaining_m = distance_m
	_charge_speed_mps = speed_mps
	return true


## 按实际扫掠位移检测沿途目标，地形与敌人碰撞立即结束，避免薄墙穿透。
func advance_charge(delta: float) -> void:
	if charge_remaining_m <= 0.0 or is_dead or get_tree().paused:
		return
	var from: Vector3 = global_position
	var distance: float = minf(charge_remaining_m, _charge_speed_mps * delta)
	var original_mask: int = collision_mask
	collision_mask = original_mask | 4
	var collision: KinematicCollision3D = move_and_collide(_charge_direction * distance)
	collision_mask = original_mask
	charge_remaining_m = maxf(0.0, charge_remaining_m - from.distance_to(global_position))
	charge_advanced.emit(from, global_position)
	if collision != null or charge_remaining_m <= 0.001:
		charge_remaining_m = 0.0
		velocity = Vector3.ZERO
		charge_finished.emit(true)


## 闪避、死亡与离场取消冲锋，取消时不发放组合增益。
func cancel_charge() -> void:
	if charge_remaining_m > 0.0:
		charge_remaining_m = 0.0
		velocity = Vector3.ZERO
		charge_finished.emit(false)


## 重击模块通过公开接口驱动举刀动作，progress 为前摇 0～1，恢复阶段逐渐落刀。
func set_heavy_pose(progress: float, recovering: bool = false) -> void:
	attack_locked = true
	$VisualRoot/WeaponSocket.rotation = Vector3(lerpf(-1.4, 0.0, progress) if recovering else lerpf(0.0, -1.4, progress), 0.0, 0.0)


## 释放动作锁定并恢复武器姿态，供命中后结束、闪避与死亡共用。
func clear_attack_pose() -> void:
	attack_locked = false
	$VisualRoot/WeaponSocket.rotation = Vector3.ZERO
