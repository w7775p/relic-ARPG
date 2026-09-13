extends Node3D
## M0 运行场地：操控、暂停和导航样板烘焙。

@onready var player: PlayerController = $Player
@onready var pause_panel: Control = $Interface/Pause
@onready var status: Label = $Interface/Hud/Rows/Status


## 对齐镜头并烘焙场地静态碰撞的导航网格。
func _ready() -> void:
	$FollowCamera.snap_to_target()
	$NavigationRegion.bake_navigation_mesh.call_deferred(false)
	get_tree().auto_accept_quit = false


## 更新真实位置和闪避冷却，不展示尚未实现的战斗数值。
func _process(_delta: float) -> void:
	$Interface/Hud/Rows/Position.text = "位置 %.1f / %.1f　闪避冷却 %.1f 秒" % [player.position.x, player.position.z, player.cooldown_remaining_sec]


## 原生窗口关闭请求打开暂停菜单，允许保存后退出。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_set_paused(true)


## 统一处理暂停与快捷保存，设置面板打开时优先关闭它。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if $Interface/Settings.visible:
			$Interface/Settings.hide()
		else:
			_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save"):
		_request_save()
		get_viewport().set_input_as_handled()


## 场地根节点持续接收菜单输入，角色等世界节点使用可暂停模式。
func _set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value
	if value:
		$Interface/Pause/Center/Rows/Resume.grab_focus()


## 调试场地只验证操控，正式存档从独立 Hub 使用。
func _request_save() -> Error:
	status.text = "请从主菜单进入据点使用存档"
	$Interface/Pause/Center/Rows/Status.text = status.text
	return ERR_UNAVAILABLE


## 恢复物理更新。
func _on_resume_pressed() -> void:
	_set_paused(false)


## 暂停状态下保存。
func _on_save_pressed() -> void:
	_request_save()


## 调试场地返回主菜单。
func _on_menu_pressed() -> void:
	SceneRouter.open_main_menu()


## 打开设置并保持世界暂停。
func _on_settings_pressed() -> void:
	$Interface/Settings.show()


## 调试场地正常退出。
func _on_quit_pressed() -> void:
	get_tree().quit()


## 恢复默认关闭行为，避免影响主菜单。
func _exit_tree() -> void:
	get_tree().auto_accept_quit = true
