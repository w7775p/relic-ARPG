extends Node
## 管理主菜单、据点与探险切换；离开场景时解除暂停，并持有一次性跨场景角色状态。

const MAIN_MENU: String = "res://ui/menus/main_menu.tscn"
const HUB: String = "res://world/hub/hub.tscn"
const EXPEDITION: String = "res://world/maps/expedition_runtime.tscn"
const DEBUG_CONSOLE: Script = preload("res://ui/debug/debug_console.gd")

var _debug_console: CanvasLayer
var _transition_session: GameSession


## 创建跨场景常驻调试控制台，并打印本机运行路径。
func _ready() -> void:
	_debug_console = DEBUG_CONSOLE.new()
	_debug_console.name = "DebugConsole"
	add_child(_debug_console)
	debug_log("INFO", "Godot %s · %s" % [Engine.get_version_info().get("string", "unknown"), OS.get_name()])
	debug_log("INFO", "user:// = %s" % ProjectSettings.globalize_path("user://"))
	debug_log("INFO", "存档 = %s" % ProjectSettings.globalize_path("user://saves/"))


## 同时写入 Godot 日志文件与标准输出，供 F3 控制台查看。
func debug_log(level: String, message: String) -> void:
	var line: String = "[DEBUGLOG][%s] %s" % [level, message]
	if level == "ERROR":
		printerr(line)
	else:
		print(line)


## 暂存一次完整会话，目标场景领取后清空引用。
func stage_session(session: GameSession) -> void:
	_transition_session = session


## 领取会话；场景负责持有它的整个运行生命周期。
func take_session() -> GameSession:
	var result: GameSession = _transition_session
	_transition_session = null
	return result


## 检查目标场景尚未领取的会话。
func has_session_transition() -> bool:
	return _transition_session != null


## 通过唯一工厂新建独立角色组，先进入 Hub 自动建立初始检查点。
func start_session() -> void:
	stage_session(GameSession.new_character())
	open_hub()


## 指定槽位经过全部模块准备后才交给 Hub，失败保持当前场景。
func load_game(group: String, slot: String) -> SaveResult:
	var result: SaveResult = SaveManager.load_game(group, slot)
	if not result.ok:
		return result
	stage_session(result.value)
	var error: Error = open_hub()
	if error != OK:
		_transition_session = null
		return SaveResult.failure("scene", error, "据点加载失败，当前会话保留")
	return result


## 切换到真实独立据点。
func open_hub() -> Error:
	return _change_scene(HUB)


## 切换到正式探险场景，状态由一次性会话交接。
func open_expedition() -> Error:
	return _change_scene(EXPEDITION)


## 回到主菜单，保留已写入的存档。
func open_main_menu() -> void:
	_change_scene(MAIN_MENU)


## 切换原生场景，并报告实际加载错误。
func _change_scene(path: String) -> Error:
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		debug_log("ERROR", "场景加载失败：%s，错误码 %s" % [path, error])
		push_error("场景加载失败：%s，错误码 %s" % [path, error])
	return error
