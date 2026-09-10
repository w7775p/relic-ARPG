extends PanelContainer
## 可嵌入主菜单和暂停界面的设置面板。

@onready var volume: HSlider = $Margin/Rows/Volume
@onready var fullscreen: CheckButton = $Margin/Rows/Fullscreen
@onready var status: Label = $Margin/Rows/Status


## 用当前设置初始化控件，避免初始化时重复保存。
func _ready() -> void:
	volume.set_value_no_signal(SettingsManager.master_volume)
	fullscreen.set_pressed_no_signal(SettingsManager.is_fullscreen)


## 即时调整总音量并显示文件写入错误。
func _on_volume_value_changed(value: float) -> void:
	_show_result(SettingsManager.set_master_volume(value))


## 应用全屏选项。
func _on_fullscreen_toggled(value: bool) -> void:
	_show_result(SettingsManager.set_fullscreen(value))


## 试听当前音量。
func _on_test_pressed() -> void:
	AudioManager.play_cue()


## 关闭面板，返回调用它的菜单。
func _on_close_pressed() -> void:
	hide()


## 统一显示设置保存结果。
func _show_result(error: Error) -> void:
	status.text = "设置已保存" if error == OK else "设置写入失败：%s" % error
