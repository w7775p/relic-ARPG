extends Node
## 保存服务只编排能力检查、完整快照和磁盘结果，不长期持有角色会话。
signal operation_completed(result: SaveResult)
var store: SaveStore = SaveStore.new()

## 返回目录是否包含可选择的槽位，坏槽也允许进入恢复界面。
func has_session() -> bool:
	return not store.catalog().slots.is_empty()

## 仅接受据点能力，手动槽显式指定；自动保存合并未变化的会话。
func save_game(session: GameSession, location: Node, manual_slot: int = 0, reason: String = "manual") -> SaveResult:
	if session == null or location == null or not location.has_method("can_save_checkpoint") or not location.can_save_checkpoint():
		return _report(SaveResult.failure("capability", ERR_UNAVAILABLE, "请撤离回据点后保存"))
	session.generator.synchronize()
	if manual_slot == 0 and not session.needs_initial_save and session.saved_revision == session.revision and _checkpoint_exists(session):
		session.pending_settlement = false
		return SaveResult.success(null, "进度已保存，无新增变化")
	if manual_slot < 0 or manual_slot > store.manual_count:
		return _report(SaveResult.failure("slot", ERR_INVALID_PARAMETER, "请选择有效手动槽位"))
	var slot: String = "manual_%02d" % manual_slot if manual_slot > 0 else store.auto_slot(session.group_id)
	var result: SaveResult = store.write_checkpoint(session.capture(reason), slot)
	if result.ok:
		session.saved_revision = session.revision
		session.saved_checkpoint_id = result.value.checkpoint_id
		session.needs_initial_save = false
		session.pending_settlement = false
	return _report(result)

## 跳过未变化写入前确认对应成功文件仍在目录中，文件缺失时重建检查点。
func _checkpoint_exists(session: GameSession) -> bool:
	for entry: SaveSlotResource in store.catalog().slots:
		if entry.group_id == session.group_id and entry.checkpoint_id == session.saved_checkpoint_id and entry.usable:
			return true
	return false

## 加载独立候选，路由在成功后采用它，当前会话不参与恢复。
func load_game(group: String, slot: String) -> SaveResult:
	return _report(store.load_session(group, slot))

## 统一输出阶段、模块、字段和错误码，界面只显示可操作消息。
func _report(result: SaveResult) -> SaveResult:
	SceneRouter.debug_log("INFO" if result.ok else "ERROR", result.diagnostic())
	operation_completed.emit(result)
	return result
