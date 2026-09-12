extends Control
## 主菜单提供独立角色新建、槽位继续、设置及退出入口。
const SLOTS: PackedScene = preload("res://ui/saves/save_slots.tscn")
var slots: Control


## 根据有效存档更新继续按钮。
func _ready() -> void:
	slots = SLOTS.instantiate()
	add_child(slots)
	$Center/Rows/Continue.disabled = not SaveManager.has_session()
	$Center/Rows/Start.grab_focus()


## 创建新的角色组并进入据点。
func _on_start_pressed() -> void:
	AudioManager.play_cue()
	SceneRouter.start_session()


## 展示手动槽与自动历史，选择后完整恢复到据点。
func _on_continue_pressed() -> void:
	slots.open(self, null, false)


## 显示设置面板。
func _on_settings_pressed() -> void:
	$Settings.show()


## 退出程序。
func _on_quit_pressed() -> void:
	get_tree().quit()
