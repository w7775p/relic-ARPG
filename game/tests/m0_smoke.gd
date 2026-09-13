extends Node
## 验证 M0 的场景、移动碰撞、暂停、设置与独立调试场地。

var _failures: int = 0


## 通过实际场景和输入运行回归，失败时返回非零退出码。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


## 等待物理帧完成，让控制器与碰撞结果稳定。
func _frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame


## 记录断言结果，保证所有失败进入测试进程状态。
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
	else:
		print("PASS: ", message)


## 连续验证用户可执行的路径，使用独立数据目录避免覆盖用户存档。
func _run() -> void:
	var arena: Node3D = load("res://world/maps/test_arena.tscn").instantiate()
	add_child(arena)
	await _frames(10)
	var player: PlayerController = arena.get_node("Player")
	_check(player.is_on_floor(), "角色落在地面")
	var start: Vector3 = player.position
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(player.position.x > start.x + 2.0, "输入驱动角色移动")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_LEFT
	key_event.pressed = true
	start = player.position
	Input.parse_input_event(key_event)
	await _frames(6)
	key_event.pressed = false
	Input.parse_input_event(key_event)
	_check(player.position.x < start.x - 0.2, "左方向键产生向左移动")
	key_event = InputEventKey.new()
	key_event.physical_keycode = KEY_RIGHT
	key_event.pressed = true
	start = player.position
	Input.parse_input_event(key_event)
	await _frames(6)
	key_event.pressed = false
	Input.parse_input_event(key_event)
	_check(player.position.x > start.x + 0.2, "右方向键产生向右移动")
	player.restore_position(Vector3(18.5, 0, 0))
	Input.action_press("move_right")
	Input.action_press("dodge")
	await _frames(20)
	Input.action_release("dodge")
	Input.action_release("move_right")
	_check(player.position.x < 19.2, "闪避被边界墙阻挡")
	_check(arena._request_save() == ERR_UNAVAILABLE, "调试场地提示从正式据点使用存档")
	player.restore_position(Vector3(2, 0, 2))
	await _frames(3)
	arena._set_paused(true)
	var paused_position: Vector3 = player.position
	Input.action_press("move_left")
	await _frames(10)
	Input.action_release("move_left")
	_check(player.position.is_equal_approx(paused_position), "暂停期间角色静止")
	_check(arena.get_node("Interface/Pause").visible, "暂停菜单显示")
	arena._set_paused(false)
	_check(not get_tree().paused, "恢复暂停状态")
	_check(SettingsManager.set_master_volume(0.3) == OK, "音量设置保存")
	_check(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.3) < 0.001, "设置作用于音频总线")
	var nav: NavigationRegion3D = arena.get_node("NavigationRegion")
	_check(nav.navigation_mesh.get_polygon_count() > 0, "导航网格生成")
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav.get_navigation_map(), Vector3(-10, 0, -5), Vector3(0, 0, -5), true)
	_check(path.size() > 2, "导航路径绕过障碍")
	arena.queue_free()
	await _frames(2)
	var menu: Control = load("res://ui/menus/main_menu.tscn").instantiate()
	add_child(menu)
	_check(menu.get_node("Center/Rows/Start") != null, "主菜单保留独立角色新建入口")
	menu._on_settings_pressed()
	_check(menu.get_node("Settings").visible, "设置入口可打开")
	print("M0_SMOKE_RESULT: ", _failures, " failures")
	get_tree().quit(0 if _failures == 0 else 1)
