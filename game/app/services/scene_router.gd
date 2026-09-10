extends Node
## 管理主菜单和测试场地切换，离开场景时解除暂停。

const MAIN_MENU: String = "res://ui/menus/main_menu.tscn"
const TEST_ARENA: String = "res://world/maps/combat_arena.tscn"

var should_restore_session: bool = false


## 进入测试场地；读取存档由场地初始化时执行。
func start_session(restore: bool = false) -> void:
	should_restore_session = restore
	_change_scene(TEST_ARENA)


## 回到主菜单，保留已写入的存档。
func open_main_menu() -> void:
	_change_scene(MAIN_MENU)


## 切换原生场景，并报告实际加载错误。
func _change_scene(path: String) -> void:
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("场景加载失败：%s，错误码 %s" % [path, error])
