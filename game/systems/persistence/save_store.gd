class_name SaveStore
extends RefCounted
## 单文件检查点仓库；写入临时文件并读回验证，成功后才替换正式槽位。
var root: String = "user://saves"
var manual_count: int = 5
var auto_count: int = 3
var registry: SaveModuleRegistry = SaveModuleRegistry.standard()
var _writing: bool = false
var _catalog: SaveIndexResource

## 显式校验外部传入的槽位，恢复副本只允许读取。
func valid_slot(slot: String, allow_recovery: bool = false) -> bool:
	var plain: String = slot.trim_suffix(".rollback") if allow_recovery else slot
	for index: int in range(1, manual_count + 1):
		if plain == "manual_%02d" % index:
			return true
	for index: int in range(1, auto_count + 1):
		if plain == "auto_%02d" % index:
			return true
	return false

## 构造已验证的内部路径。
func slot_path(group: String, slot: String) -> String:
	return root.path_join(group).path_join(slot + ".tres")

## 从磁盘读取独立资源，缓存不会把旧槽位或运行期修改带入候选。
func read_file(path: String) -> SaveResult:
	if not FileAccess.file_exists(path):
		return SaveResult.failure("read", ERR_FILE_NOT_FOUND, "存档文件缺失")
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not resource is SaveGameResource:
		return SaveResult.failure("read", ERR_FILE_CORRUPT, "存档文件损坏或类型不正确")
	var result: SaveResult = registry.prepare(resource)
	if not result.ok:
		return result
	return SaveResult.success(resource)

## 读取指定槽并验证文件所属角色，失败不创建或修改会话。
func read_slot(group: String, slot: String) -> SaveResult:
	if not SaveGameResource.valid_id(group) or not valid_slot(slot, true):
		return SaveResult.failure("read", ERR_INVALID_PARAMETER, "角色或槽位标识不合法")
	var result: SaveResult = read_file(slot_path(group, slot))
	if result.ok and result.value.group_id != group:
		return SaveResult.failure("validate", ERR_INVALID_DATA, "存档与角色目录不匹配")
	return result

## 全部模块准备成功后组装候选会话，由场景路由决定何时采用。
func load_session(group: String, slot: String) -> SaveResult:
	var result: SaveResult = read_slot(group, slot)
	if not result.ok:
		return result
	var save: SaveGameResource = result.value
	var prepared: SaveResult = registry.prepare(save)
	if not prepared.ok:
		return prepared
	return SaveResult.success(GameSession.restored(save, prepared.value), "已读取存档，将返回据点")

## 枚举正式槽和失败事务留下的回退副本；pending 文件不会成为可用存档。
func _files() -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		return result
	for group: String in DirAccess.get_directories_at(root):
		if not SaveGameResource.valid_id(group):
			continue
		for filename: String in DirAccess.get_files_at(root.path_join(group)):
			if filename.ends_with(".tres") and valid_slot(filename.trim_suffix(".tres"), true):
				result.append(group.path_join(filename))
	result.sort()
	return result

## 用路径、时间和长度判断索引是否需要重建；加载时仍重新校验正文。
func _fingerprint(files: Array[String]) -> String:
	var parts: PackedStringArray = []
	for relative: String in files:
		var path: String = root.path_join(relative)
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		parts.append("%s:%d:%d" % [relative, FileAccess.get_modified_time(path), file.get_length() if file != null else -1])
	return "\n".join(parts).sha256_text()

## 读取轻量目录，缓存失效时扫描实际文件；坏槽也保留供玩家选择回退。
func catalog(force_rebuild: bool = false) -> SaveIndexResource:
	var files: Array[String] = _files()
	var stamp: String = _fingerprint(files)
	if not force_rebuild and _catalog != null and _catalog.fingerprint == stamp:
		return _catalog
	if not force_rebuild and _catalog == null and FileAccess.file_exists(root.path_join("index.tres")):
		var loaded: Resource = ResourceLoader.load(root.path_join("index.tres"), "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is SaveIndexResource and loaded.fingerprint == stamp and _valid_index(loaded, files):
			_catalog = loaded
			return _catalog
	_catalog = SaveIndexResource.new()
	_catalog.fingerprint = stamp
	for relative: String in files:
		var group: String = relative.get_slice("/", 0)
		var slot: String = relative.get_file().trim_suffix(".tres")
		_catalog.slots.append(SaveSlotResource.from_result(group, slot, read_slot(group, slot)))
	_catalog.slots.sort_custom(_newer)
	_write_index()
	return _catalog

## 索引只接受实际枚举到的槽位，不能引入外部路径。
func _valid_index(index: SaveIndexResource, files: Array[String]) -> bool:
	if index.slots.size() != files.size():
		return false
	var seen: Dictionary = {}
	for slot: SaveSlotResource in index.slots:
		if slot == null:
			return false
		var relative: String = slot.group_id.path_join(slot.slot_id + ".tres")
		if not files.has(relative) or seen.has(relative):
			return false
		seen[relative] = true
	return true

## 时间跨角色排序，同角色同秒多次保存按单调序号排序。
func _newer(a: SaveSlotResource, b: SaveSlotResource) -> bool:
	if a.group_id == b.group_id:
		return a.sequence > b.sequence
	return a.saved_at > b.saved_at

## 查询角色的自动保存写入目标；按成功序号替换最旧版本。
func auto_slot(group: String) -> String:
	var used: Dictionary = {}
	for slot: SaveSlotResource in catalog().slots:
		if slot.group_id == group and slot.slot_id.begins_with("auto_") and not slot.slot_id.ends_with(".rollback"):
			used[slot.slot_id] = slot.sequence
	for index: int in range(1, auto_count + 1):
		var id: String = "auto_%02d" % index
		if not used.has(id):
			return id
	var oldest: String = "auto_01"
	for id: String in used:
		if used[id] < used[oldest]:
			oldest = id
	return oldest

## 保存完整候选，单写者拒绝重入；所有失败均返回实际阶段。
func write_checkpoint(save: SaveGameResource, slot: String) -> SaveResult:
	if _writing:
		return SaveResult.failure("queue", ERR_BUSY, "上一笔保存正在完成，请稍后重试")
	if save == null or not SaveGameResource.valid_id(save.group_id) or not valid_slot(slot):
		return SaveResult.failure("validate", ERR_INVALID_PARAMETER, "角色或槽位标识不合法")
	_writing = true
	var result: SaveResult = _commit(save, slot)
	_writing = false
	return result

## 执行事务：校验、临时写入、读回、保留旧文件、替换与索引更新。
func _commit(save: SaveGameResource, slot: String) -> SaveResult:
	var validation: SaveResult = registry.prepare(save)
	if not validation.ok:
		return validation
	var sequence: int = 0
	var directory: SaveIndexResource = catalog()
	for entry: SaveSlotResource in directory.slots:
		if entry.group_id == save.group_id:
			sequence = maxi(sequence, entry.sequence)
	save.sequence = sequence + 1
	var target: String = slot_path(save.group_id, slot)
	var pending: String = target.trim_suffix(".tres") + ".pending.tres"
	var backup: String = target.trim_suffix(".tres") + ".rollback.tres"
	var error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if error != OK:
		return SaveResult.failure("mkdir", error, "无法创建存档目录")
	error = ResourceSaver.save(save, pending)
	if error != OK:
		return SaveResult.failure("write", error, "临时存档写入失败，请检查磁盘和目录权限")
	var readback: SaveResult = read_file(pending)
	if not readback.ok or ResourceFingerprint.digest(readback.value) != ResourceFingerprint.digest(save):
		return SaveResult.failure("readback", ERR_FILE_CORRUPT, "临时存档读回校验失败")
	if FileAccess.file_exists(target):
		error = DirAccess.copy_absolute(target, backup)
		if error != OK:
			return SaveResult.failure("backup", error, "无法保留上一份存档，已停止覆盖")
	error = _replace_file(pending, target)
	if error != OK:
		_catalog = null
		return SaveResult.failure("replace", error, "正式存档替换失败，原文件及恢复副本保留")
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	# 当前正文已经提交，索引失败不应误报保存失败或重复结算。
	for index: int in range(directory.slots.size() - 1, -1, -1):
		var entry: SaveSlotResource = directory.slots[index]
		if entry.group_id == save.group_id and entry.slot_id in [slot, slot + ".rollback"]:
			directory.slots.remove_at(index)
	directory.slots.append(SaveSlotResource.from_result(save.group_id, slot, SaveResult.success(save)))
	directory.slots.sort_custom(_newer)
	directory.fingerprint = _fingerprint(_files())
	_catalog = directory
	var result: SaveResult = SaveResult.success(save, "已保存")
	if _write_index() != OK:
		result.warning = "存档已成功，目录索引稍后重建"
	result.value = save
	return result

## 同目录替换正式文件；独立入口便于验证替换瞬间的实际文件系统竞争。
func _replace_file(pending: String, target: String) -> Error:
	return DirAccess.rename_absolute(pending, target)

## 索引采用同目录临时文件；正文始终是可重建目录的依据。
func _write_index() -> Error:
	if _catalog == null:
		return ERR_UNCONFIGURED
	var error: Error = DirAccess.make_dir_recursive_absolute(root)
	if error != OK:
		return error
	var pending: String = root.path_join("index.pending.tres")
	error = ResourceSaver.save(_catalog, pending)
	if error != OK:
		return error
	return DirAccess.rename_absolute(pending, root.path_join("index.tres"))
