extends Node
## 自动加载服务准备后进入主菜单。


## 延迟切换，避免在场景创建过程中修改场景树。
func _ready() -> void:
	if OS.get_cmdline_user_args().has("--smoke-loot"):
		# 同一拾取回归随发行包导出，由专用参数在独立测试目录执行。
		var probe: Node = preload("res://app/validation/pickup_smoke.gd").new()
		get_tree().root.add_child.call_deferred(probe)
	elif OS.get_cmdline_user_args().has("--smoke-combat"):
		# 发行模板禁用场景路径覆盖，自动验证通过正常路由进入战斗。
		SceneRouter.start_session.call_deferred()
	else:
		SceneRouter.open_main_menu.call_deferred()
