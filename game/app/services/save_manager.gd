extends Node
## 兼容 M0 位置存档与 M2/D1 完整探险，校验后写入临时文件替换；保存过程写入 DebugLog。

const SAVE_PATH: String = "user://session.json"
const SAVE_VERSION: int = 1
const EXPEDITION_VERSION: int = 4


## 判断是否存在可恢复的当前版本存档。
func has_session() -> bool:
	return not load_session().is_empty()


## 校验有限坐标与版本，拒绝损坏或不支持的数据。
func is_valid_session(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var version: Variant = data.get("version")
	if (version is int or version is float) and (version == 2 or version == 3 or version == 4):
		return data.get("map_id") == "map_m2_arena" and SaveValidator.expedition(data.get("expedition"), int(version))
	if version != SAVE_VERSION or data.get("map_id") != "map_m0_arena":
		return false
	var position_data: Variant = data.get("player_position")
	if not position_data is Array or position_data.size() != 3:
		return false
	for coordinate: Variant in position_data:
		if not (coordinate is float or coordinate is int):
			return false
		if not is_finite(float(coordinate)):
			return false
	return absf(float(position_data[0])) <= 19.2 and absf(float(position_data[2])) <= 19.2 and float(position_data[1]) >= -1.0 and float(position_data[1]) < 5.0


## 读取并校验文件；v2/v3 依次迁移到 v4，失败时返回空字典。
func load_session() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var raw: String = FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(raw)
	if not is_valid_session(data):
		_debug("ERROR", "读取存档失败：文件存在但内容未通过校验；path=%s，chars=%d" % [_absolute(SAVE_PATH), raw.length()])
		return {}
	if data.version == 2:
		return SessionSnapshot.migrate_v3(SessionSnapshot.migrate_v2(data))
	if data.version == 3:
		return SessionSnapshot.migrate_v3(data)
	return data


## 保存 M0 位置并记录实际写入结果。
func save_session(player_position: Vector3) -> Error:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"map_id": "map_m0_arena",
		"player_position": [player_position.x, player_position.y, player_position.z],
	}
	if not is_valid_session(data):
		_debug("ERROR", "位置存档校验失败：position=%s" % player_position)
		return ERR_INVALID_DATA
	return _write(data)


## 保存通过结构、持续状态与实例唯一性校验的完整会话。
func save_expedition(snapshot: Dictionary) -> Error:
	var data: Dictionary = {"version":EXPEDITION_VERSION, "map_id":"map_m2_arena", "expedition":snapshot}
	_debug("INFO", "开始保存完整探险：in_town=%s，enemies=%d，ground=%d" % [snapshot.get("in_town", false), snapshot.get("enemies", []).size(), snapshot.get("ground", []).size()])
	if not is_valid_session(data):
		_debug("ERROR", "完整探险存档校验失败：version=%d，snapshot_keys=%s" % [EXPEDITION_VERSION, snapshot.keys()])
		return ERR_INVALID_DATA
	return _write(data)


## 完整刷新临时文件后替换正式路径，并记录每一步真实系统错误。
func _write(data: Dictionary) -> Error:
	var temp_path: String = SAVE_PATH + ".tmp"
	var serialized: String = JSON.stringify(data, "\t")
	_debug("INFO", "写入临时存档：%s；目标=%s；chars=%d" % [_absolute(temp_path), _absolute(SAVE_PATH), serialized.length()])
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		_debug("ERROR", "打开临时存档失败：%s (%d)；path=%s" % [error_string(open_error), open_error, _absolute(temp_path)])
		return open_error
	file.store_string(serialized)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_debug("ERROR", "写入或刷新临时存档失败：%s (%d)；temp_exists=%s" % [error_string(write_error), write_error, FileAccess.file_exists(temp_path)])
		return write_error
	var target_existed: bool = FileAccess.file_exists(SAVE_PATH)
	var rename_error: Error = DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if rename_error != OK:
		_debug("ERROR", "替换正式存档失败：%s (%d)；target_existed=%s；target_exists_now=%s；temp_exists=%s" % [error_string(rename_error), rename_error, target_existed, FileAccess.file_exists(SAVE_PATH), FileAccess.file_exists(temp_path)])
		return rename_error
	_debug("INFO", "保存成功：%s；chars=%d" % [_absolute(SAVE_PATH), serialized.length()])
	return OK


## 将 user:// 路径转换为系统绝对路径，便于玩家直接定位文件。
func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)


## 日志优先交给常驻场景路由，同时保留无路由测试环境下的标准输出。
func _debug(level: String, message: String) -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null and router.has_method("debug_log"):
		router.call("debug_log", level, message)
	elif level == "ERROR":
		printerr("[DEBUGLOG][ERROR] %s" % message)
	else:
		print("[DEBUGLOG][INFO] %s" % message)
