extends Camera3D
## 固定方向的正交镜头，平滑跟随角色。

@export var target: Node3D
@export var follow_speed: float = 12.0
@export var offset_m: Vector3 = Vector3(0.0, 18.0, 14.0)


## 初次进入与读档后立即对齐，避免从原点长距离追赶。
func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target.global_position + offset_m
		look_at(target.global_position, Vector3.UP)


## 在帧更新中使用指数插值，保持不同帧率下的跟随速度。
func _process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = global_position.lerp(target.global_position + offset_m, 1.0 - exp(-follow_speed * delta))
