extends Node
## 兼容 M0 位置存档与 M2/D1 完整探险，校验后写入临时文件替换。

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
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not is_valid_session(data):
		return {}
	if data.version == 2:
		return SessionSnapshot.migrate_v3(SessionSnapshot.migrate_v2(data))
	if data.version == 3:
		return SessionSnapshot.migrate_v3(data)
	return data


## 先完整写入临时文件，再替换正式存档，返回实际文件错误。
func save_session(player_position: Vector3) -> Error:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"map_id": "map_m0_arena",
		"player_position": [player_position.x, player_position.y, player_position.z],
	}
	if not is_valid_session(data):
		return ERR_INVALID_DATA
	return _write(data)


## 保存通过结构、持续状态与实例唯一性校验的完整会话。
func save_expedition(snapshot: Dictionary) -> Error:
	var data: Dictionary = {"version":EXPEDITION_VERSION, "map_id":"map_m2_arena", "expedition":snapshot}
	if not is_valid_session(data):
		return ERR_INVALID_DATA
	return _write(data)


## 完整刷新文件后替换正式路径，保留真实系统错误。
func _write(data: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
