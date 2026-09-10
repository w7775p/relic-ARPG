extends Node
## 持续补足 100 怪并自动巡场施放旋风，输出帧时间和机制计数。

const ARENA: PackedScene = preload("res://world/maps/combat_arena.tscn")
const WAYPOINTS: Array[Vector3] = [Vector3(0, 0, -11), Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(11, 0, 12), Vector3(-11, 0, 12), Vector3(-11, 0, 0)]

var _arena: Node3D
var _elapsed: float = 0.0
var _duration_sec: float = 180.0
var _output_path: String = "user://m1_stress.json"
var _frame_times_ms: Array[float] = []
var _physics_times_ms: Array[float] = []
var _active_counts: Array[int] = []
var _waypoint: int = 0
var _last_tick_usec: int = 0
var _next_progress_sec: float = 30.0
var _preset: String = "thunder"


## 解析时长和输出文件，自动脚本专用高生命防止测试被死亡打断。
func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--stress-seconds="):
			_duration_sec = maxf(1.0, argument.get_slice("=", 1).to_float())
		elif argument.begins_with("--output-path="):
			_output_path = argument.trim_prefix("--output-path=")
		elif argument.begins_with("--preset="):
			_preset = argument.get_slice("=", 1)
	Engine.max_fps = 60
	_arena = ARENA.instantiate()
	_arena.auto_spawn = false
	add_child(_arena)
	_arena.restart(100)
	_arena.encounters.maintain_population = true
	_arena.player.max_health = 1000000.0
	_arena.player.reset_health()
	_arena.skills.equip(SkillRunner.BASIC if _preset == "basic" else SkillRunner.THUNDER)
	_arena.skills.input_enabled = false
	_last_tick_usec = Time.get_ticks_usec()


## 自动沿固定路线移动，能量不足时松开旋风恢复，保证两套预设使用相同规则。
func _physics_process(_delta: float) -> void:
	var destination: Vector3 = WAYPOINTS[_waypoint]
	var offset: Vector3 = destination - _arena.player.position
	offset.y = 0.0
	if offset.length() < 1.2:
		_waypoint = (_waypoint + 1) % WAYPOINTS.size()
	var direction: Vector3 = offset.normalized()
	_set_action("move_left", maxf(0.0, -direction.x))
	_set_action("move_right", maxf(0.0, direction.x))
	_set_action("move_up", maxf(0.0, -direction.z))
	_set_action("move_down", maxf(0.0, direction.z))
	if _arena.skills.energy < 1.0:
		_arena.skills.channel_requested = false
	elif _arena.skills.energy >= 80.0:
		_arena.skills.channel_requested = true


## 写入真实输入动作，保持玩家控制器和碰撞路径参与测试。
func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## 收集真实帧间隔，前 5 秒预热不纳入分位数。
func _process(delta: float) -> void:
	_elapsed += delta
	var now: int = Time.get_ticks_usec()
	if _elapsed > 5.0:
		_frame_times_ms.append(float(now - _last_tick_usec) / 1000.0)
		_physics_times_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_active_counts.append(_arena.combat.enemies.size())
	_last_tick_usec = now
	if _elapsed >= _next_progress_sec:
		print("STRESS_PROGRESS: ", int(_elapsed), "s kills=", _arena.combat.kills, " active=", _arena.combat.enemies.size())
		_next_progress_sec += 30.0
	if _elapsed >= _duration_sec:
		_finish()


## 对已经排序的数据取分位数。
func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	return values[mini(values.size() - 1, int(ceil(values.size() * fraction)) - 1)]


## 输出设备、模式、负载与结算数据；无窗口数据明确排除 GPU 性能结论。
func _finish() -> void:
	set_process(false)
	set_physics_process(false)
	_frame_times_ms.sort()
	_physics_times_ms.sort()
	_active_counts.sort()
	var result: Dictionary = {
		"engine": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"display_driver": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name(),
		"resolution": [1280, 720], "preset": _preset, "duration_sec": _elapsed,
		"warmup_sec": 5, "fps_cap": 60, "target_population": 100,
		"active_min": _active_counts[0] if not _active_counts.is_empty() else 0,
		"samples": _frame_times_ms.size(),
		"frame_p50_ms": _percentile(_frame_times_ms, 0.5),
		"frame_p95_ms": _percentile(_frame_times_ms, 0.95),
		"frame_p99_ms": _percentile(_frame_times_ms, 0.99),
		"frame_max_ms": _frame_times_ms.back() if not _frame_times_ms.is_empty() else 0,
		"physics_p95_ms": _percentile(_physics_times_ms, 0.95),
		"physics_p99_ms": _percentile(_physics_times_ms, 0.99),
		"kills": _arena.combat.kills, "damage": _arena.combat.damage_dealt,
		"lightning": _arena.effects.lightning_count, "explosions": _arena.effects.explosion_count,
		"peak_event_queue": _arena.effects.peak_queue_size,
		"note": "高生命测试角色；无窗口模式只验证 CPU/物理与逻辑，帧率受 60 上限限制。",
	}
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("压力报告无法写入")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("M1_STRESS_RESULT: ", JSON.stringify(result))
	get_tree().quit()
