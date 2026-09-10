extends Node
## 使用 ConfigFile 保存音量和窗口设置。

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"

var master_volume: float = 0.7
var is_fullscreen: bool = false


## 启动时恢复设置；无配置文件时使用默认值。
func _ready() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", 0.7)), 0.0, 1.0)
		is_fullscreen = bool(config.get_value("display", "fullscreen", false))
	_apply_settings()


## 修改总音量并返回落盘结果。
func set_master_volume(value: float) -> Error:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	return _save_settings()


## 修改全屏状态并返回落盘结果。
func set_fullscreen(value: bool) -> Error:
	is_fullscreen = value
	_apply_settings()
	return _save_settings()


## 应用原生音频总线与窗口模式；无窗口测试跳过显示操作。
func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	if DisplayServer.get_name() != "headless":
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	settings_changed.emit()


## 将用户设置独立保存，避免与探险存档互相覆盖。
func _save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", is_fullscreen)
	return config.save(SETTINGS_PATH)
