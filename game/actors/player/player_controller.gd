class_name PlayerController
extends CharacterBody3D
## 处理平面移动、地面瞄准与有碰撞的闪避；M0 暂无战斗。

@export var move_speed_mps: float = 7.0
@export var dodge_speed_mps: float = 18.0
@export var dodge_duration_sec: float = 0.18
@export var dodge_cooldown_sec: float = 0.7

var dodge_remaining_sec: float = 0.0
var cooldown_remaining_sec: float = 0.0
var _dodge_direction: Vector3 = Vector3.FORWARD

@onready var visual_root: Node3D = $VisualRoot


## 在物理帧中移动；斜向输入由 Input.get_vector 自动归一化。
func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y)
	cooldown_remaining_sec = maxf(0.0, cooldown_remaining_sec - delta)
	dodge_remaining_sec = maxf(0.0, dodge_remaining_sec - delta)
	_update_aim()
	if Input.is_action_just_pressed("dodge") and cooldown_remaining_sec <= 0.0:
		_dodge_direction = direction if direction.length_squared() > 0.01 else -visual_root.global_basis.z
		dodge_remaining_sec = dodge_duration_sec
		cooldown_remaining_sec = dodge_cooldown_sec
		AudioManager.play_cue(0.6)
	var movement: Vector3 = direction * move_speed_mps
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
	global_position = value
	velocity = Vector3.ZERO
	dodge_remaining_sec = 0.0
	cooldown_remaining_sec = 0.0
