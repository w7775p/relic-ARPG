class_name CombatFeedback
extends Node3D
## 合并与限制短期视觉、声音数量，规则伤害不受视觉额度影响。

@export var max_visuals: int = 96
var visuals_enabled: bool = true
var _sound_remaining: float = 0.0
var _materials: Dictionary = {}


## 限制命中提示音频率，避免密集怪群同帧叠加过响。
func _process(delta: float) -> void:
	_sound_remaining = maxf(0.0, _sound_remaining - delta)


## 复用同色原生材质，不引入动态光源。
func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]


## 只在视觉额度内建立网格，并在指定时间后回收。
func _visual(mesh: Mesh, duration_sec: float) -> MeshInstance3D:
	if not visuals_enabled or get_child_count() >= max_visuals:
		return null
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	var tween: Tween = instance.create_tween()
	tween.tween_property(instance, "scale", Vector3.ONE * 0.02, duration_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(instance.queue_free)
	return instance


## 显示地面旋风、爆炸和危险圈，半径与实际技能参数一致。
func ring(origin: Vector3, radius_m: float, color: Color, duration_sec: float) -> void:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = maxf(0.02, radius_m - 0.08)
	mesh.outer_radius = radius_m
	mesh.rings = 24
	mesh.ring_segments = 6
	mesh.material = _material(color)
	var instance: MeshInstance3D = _visual(mesh, duration_sec)
	if instance != null:
		instance.global_position = origin + Vector3.UP * 0.12


## 用圆柱连接两点，可同时显示闪电段和冲锋预警。
func beam(from: Vector3, to: Vector3, color: Color, duration_sec: float, width_m: float = 0.07) -> void:
	var offset: Vector3 = to - from
	if offset.length_squared() < 0.001:
		return
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = width_m
	mesh.bottom_radius = width_m
	mesh.height = offset.length()
	mesh.radial_segments = 5
	mesh.material = _material(color)
	var instance: MeshInstance3D = _visual(mesh, duration_sec)
	if instance != null:
		instance.global_position = (from + to) * 0.5 + Vector3.UP * 0.7
		instance.quaternion = Quaternion(Vector3.UP, offset.normalized())


## 多段折线呈现闪电，零距离首段以短脉冲标识。
func lightning(from: Vector3, to: Vector3) -> void:
	if from.distance_squared_to(to) < 0.01:
		ring(to, 0.5, Color(0.4, 0.9, 1.0), 0.12)
		return
	var middle: Vector3 = (from + to) * 0.5 + Vector3(0.22, 0.25, -0.22)
	beam(from, middle, Color(0.6, 0.95, 1.0), 0.16)
	beam(middle, to, Color(0.6, 0.95, 1.0), 0.16)


## 普攻显示前方挥砍轨迹，随角色朝向旋转。
func slash(origin: Vector3, facing: Vector3, color: Color = Color(0.9, 0.85, 0.55)) -> void:
	var side: Vector3 = facing.cross(Vector3.UP)
	beam(origin + facing * 1.4 - side, origin + facing * 2.2, color, 0.12, 0.13)
	beam(origin + facing * 2.2, origin + facing * 1.4 + side, color, 0.12, 0.13)


## 横扫按真实判定半径绘制扇形边界与中心线，确保玩家能看清方向和覆盖范围。
func sweep(origin: Vector3, facing: Vector3, radius_m: float, facing_dot_min: float) -> void:
	var flat_facing: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	if flat_facing.length_squared() < 0.001:
		return
	var color: Color = Color(1.0, 0.2, 0.08)
	var half_angle: float = acos(clampf(facing_dot_min, -1.0, 1.0))
	var segments: int = 10
	var points: Array[Vector3] = []
	for index: int in range(segments + 1):
		var weight: float = float(index) / float(segments)
		var angle: float = lerpf(-half_angle, half_angle, weight)
		points.append(origin + flat_facing.rotated(Vector3.UP, angle) * radius_m)
	beam(origin, points[0], color, 0.24, 0.11)
	for index: int in range(points.size() - 1):
		beam(points[index], points[index + 1], color, 0.24, 0.11)
	beam(points[points.size() - 1], origin, color, 0.24, 0.11)
	beam(origin, origin + flat_facing * radius_m, Color(1.0, 0.55, 0.15), 0.24, 0.15)
	slash(origin, flat_facing, color)


## 命中反馈只改变表现，原始结算事件保持完整。
func on_hit(event: DamageEvent) -> void:
	if _sound_remaining <= 0.0:
		_sound_remaining = 0.09
		AudioManager.play_cue(0.45 if event.killed else (1.4 if event.is_critical else 0.85))
	if event.killed:
		ring(event.origin, 0.7, Color(1.0, 0.75, 0.35), 0.25)
