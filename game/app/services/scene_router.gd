extends Node
## 管理主菜单、据点与探险切换；离开场景时解除暂停，并持有一次性跨场景角色状态。

const MAIN_MENU: String = "res://ui/menus/main_menu.tscn"
const HUB: String = "res://world/hub/hub.tscn"
const EXPEDITION: String = "res://world/maps/expedition.tscn"
const DEBUG_CONSOLE: Script = preload("res://ui/debug/debug_console.gd")

var should_restore_session: bool = false
var _debug_console: CanvasLayer
var _transition_inventory: InventoryState
var _transition_generator: ItemGenerator
var _transition_minimum_quality: int = 0
var _has_transition_state: bool = false


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


## 暂存一次跨场景角色状态；目标场景读取后立即清空引用。
func stage_character_state(inventory: InventoryState, generator: ItemGenerator, minimum_quality: int) -> void:
	_transition_inventory = inventory
	_transition_generator = generator
	_transition_minimum_quality = minimum_quality
	_has_transition_state = true


## 取得一次性跨场景角色状态，避免 SceneRouter 长期持有玩法数据。
func take_character_state() -> Dictionary:
	if not _has_transition_state:
		return {}
	var result: Dictionary = {
		"inventory": _transition_inventory,
		"generator": _transition_generator,
		"minimum_quality": _transition_minimum_quality,
	}
	_transition_inventory = null
	_transition_generator = null
	_transition_minimum_quality = 0
	_has_transition_state = false
	return result


## 判断当前是否有等待目标场景领取的角色状态。
func has_character_state() -> bool:
	return _has_transition_state


## 进入旧兼容探险入口；完整据点切换在 Hub 场景接通后替换此调用。
func start_session(restore: bool = false) -> void:
	should_restore_session = restore
	_change_scene(EXPEDITION)


## 切换到独立据点场景。
func open_hub() -> void:
	should_restore_session = false
	_change_scene(HUB)


## 切换到探险场景；角色状态应在调用前通过 stage_character_state 暂存。
func open_expedition() -> void:
	should_restore_session = false
	_change_scene(EXPEDITION)


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
