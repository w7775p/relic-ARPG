extends Node
## 管理主菜单和测试场地切换，离开场景时解除暂停；持有常驻 DebugLog 覆盖层。

const MAIN_MENU: String = "res://ui/menus/main_menu.tscn"
const TEST_ARENA: String = "res://world/maps/expedition.tscn"
const DEBUG_CONSOLE: Script = preload("res://ui/debug/debug_console.gd")

var should_restore_session: bool = false
var _debug_console: CanvasLayer


## 创建跨场景常驻调试控制台，并打印本机运行路径。
func _ready() -> void:
	_debug_console = DEBUG_CONSOLE.new()
	_debug_console.name = "DebugConsole"
	add_child(_debug_console)
	debug_log("INFO", "Godot %s · %s" % [Engine.get_version_info().get("string", "unknown"), OS.get_name()])
	debug_log("INFO", "user:// = %s" % ProjectSettings.globalize_path("user://"))
	debug_log("INFO", "存档 = %s" % ProjectSettings.globalize_path("user://session.json"))


## 同时写入 Godot 日志文件与标准输出，供 F3 控制台查看。
func debug_log(level: String, message: String) -> void:
	var line: String = "[DEBUGLOG][%s] %s" % [level, message]
	if level == "ERROR":
		printerr(line)
	else:
		print(line)


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
		debug_log("ERROR", "场景加载失败：%s，错误码 %s" % [path, error])
		push_error("场景加载失败：%s，错误码 %s" % [path, error])
