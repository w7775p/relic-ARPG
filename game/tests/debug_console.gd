extends Node
## DebugLog 回归：常驻覆盖层、F3 输入与发布日志实时写入。

var failures: int = 0
var checks: int = 0


## 等待自动加载节点完成初始化后执行。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


## 记录单项结果并保留失败上下文。
func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


## 验证 F3 控制台可以读取当前 Godot 文件日志。
func _run() -> void:
	await get_tree().process_frame
	var console: Node = SceneRouter.get_node_or_null("DebugConsole")
	check(console != null, "DebugLog 控制台随 SceneRouter 常驻")
	check(InputMap.has_action("debug_console"), "F3 使用语义输入动作 debug_console")
	check(bool(ProjectSettings.get_setting("application/run/flush_stdout_on_print", false)), "发布包 print 实时刷新到文件日志")
	check(String(ProjectSettings.get_setting("debug/file_logging/log_path", "")) == "user://logs/godot.log", "Godot 日志固定写入 user://logs/godot.log")
	SceneRouter.debug_log("INFO", "DEBUG_CONSOLE_PROBE")
	await get_tree().process_frame
	var content: String = FileAccess.get_file_as_string("user://logs/godot.log") if FileAccess.file_exists("user://logs/godot.log") else ""
	check(content.contains("DEBUG_CONSOLE_PROBE"), "DebugLog 信息在运行中即可从日志文件读取")
	if console != null:
		console.call("toggle_console")
		var panel: Control = console.get_node_or_null("DebugConsolePanel")
		check(panel != null and panel.visible, "控制台覆盖层可以打开")
		console.call("toggle_console")
	print("DEBUG_CONSOLE_RESULT: ", failures, " failures; ", checks, " checks")
	get_tree().quit(0 if failures == 0 else 1)
