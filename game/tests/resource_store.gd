extends Node
## 使用真实隔离文件验证整档往返、多槽位、自动历史和失败保留。
var failures: int = 0

## 记录真实操作的断言。
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

## 用角色独立目录测试磁盘行为，测试入口由 verify.py 隔离用户数据。
func _ready() -> void:
	var store: SaveStore = SaveStore.new()
	store.root = "user://store_tests"
	var session: GameSession = GameSession.new()
	var other: GameSession = GameSession.new()
	check(store.write_checkpoint(session.capture("manual"), "manual_01").ok, "Resource 检查点通过真实写入和读回验证")
	session.modules.economy.gold = 77
	check(store.write_checkpoint(session.capture("manual"), "manual_02").ok, "第二个手动槽独立保存")
	check(store.write_checkpoint(other.capture("manual"), "manual_01").ok, "另一角色拥有独立同名槽位")
	var loaded: SaveResult = store.load_session(session.group_id, "manual_01")
	check(loaded.ok and loaded.value.modules.economy.gold == 0, "选择旧槽后所有模块回到对应检查点")
	loaded = store.load_session(session.group_id, "manual_02")
	check(loaded.ok and loaded.value.modules.economy.gold == 77 and loaded.value.saved_revision == loaded.value.revision, "读回新槽且读取本身标记为无需自动保存")
	loaded.value.modules.economy.gold = 999
	check(store.load_session(session.group_id, "manual_02").value.modules.economy.gold == 77, "运行期修改不污染 ResourceLoader 缓存或磁盘")
	for amount: int in range(1, 5):
		session.modules.economy.gold = amount
		check(store.write_checkpoint(session.capture("auto"), store.auto_slot(session.group_id)).ok, "自动保存成功版本 %d" % amount)
	var amounts: Array[int] = []
	for entry: SaveSlotResource in store.catalog().slots:
		if entry.group_id == session.group_id and entry.slot_id.begins_with("auto_"):
			amounts.append(store.load_session(entry.group_id, entry.slot_id).value.modules.economy.gold)
	amounts.sort()
	check(amounts == [2, 3, 4], "一个自动栏位保留最近三个成功版本")
	var bad: SaveGameResource = session.capture("invalid")
	bad.modules.pop_back()
	check(not store.write_checkpoint(bad, "manual_02").ok and store.load_session(session.group_id, "manual_02").value.modules.economy.gold == 77, "模块校验失败不覆盖旧文件")
	DirAccess.remove_absolute(store.root.path_join("index.tres"))
	var rebuilt: SaveStore = SaveStore.new()
	rebuilt.root = store.root
	check(rebuilt.catalog().slots.size() == 6, "索引缺失后从实际检查点重建全部槽位")
	check(not store.load_session(session.group_id, "manual_05").ok, "空槽返回缺失信息，不创建默认角色")
	check(not store.load_session(session.group_id, "../../index").ok, "槽位路径不能越过角色目录")
	print("RESOURCE_STORE_RESULT: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
