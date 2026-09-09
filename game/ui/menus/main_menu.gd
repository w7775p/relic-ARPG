extends Control
## 主菜单提供新建、继续、设置及退出入口。


## 根据有效存档更新继续按钮。
func _ready() -> void:
	$Center/Rows/Continue.disabled = not SaveManager.has_session()
	$Center/Rows/Start.grab_focus()


## 开始新的测试；原存档在玩家主动保存后更新。
func _on_start_pressed() -> void:
	AudioManager.play_cue()
	SceneRouter.start_session()


## 恢复已保存位置。
func _on_continue_pressed() -> void:
	SceneRouter.start_session(true)


## 显示设置面板。
func _on_settings_pressed() -> void:
	$Settings.show()


## 退出程序。
func _on_quit_pressed() -> void:
	get_tree().quit()
