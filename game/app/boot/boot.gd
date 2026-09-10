extends Node
## 自动加载服务准备后进入主菜单。


## 延迟切换，避免在场景创建过程中修改场景树。
func _ready() -> void:
	SceneRouter.open_main_menu.call_deferred()
