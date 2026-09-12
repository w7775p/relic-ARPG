extends Node
## 故障探针独立进程执行，真实制造文件系统失败并检查保留、回退与重试。
var failures: int = 0
var fault: String = ""

## 在替换窗口制造路径竞争，再调用真实 DirAccess.rename_absolute。
class RacingStore extends SaveStore:
	var armed: bool = false
	## 模拟另一进程将目标文件位置占成目录，旧文件保存在可检查位置。
	func _replace_file(pending: String, target: String) -> Error:
		if armed:
			DirAccess.rename_absolute(target, target + ".displaced")
			DirAccess.make_dir_absolute(target)
		return super._replace_file(pending, target)

## 选择单项故障，测试驱动在真实场景切换后仍存活。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fault-case="):
			fault = argument.get_slice("=", 1)
	_run.call_deferred()

## 断言失败使用独立标记，预期引擎 I/O 报错不会掩盖测试失败。
func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		printerr("FAULT_ASSERT_FAILED: ", message)

## 等待路由、自动保存与延迟删除。
func frames(count: int = 4) -> void:
	for index: int in range(count):
		await get_tree().process_frame

## 每个进程使用唯一隔离根目录。
func _run() -> void:
	SaveManager.store.root = "user://faults_" + fault
	SceneRouter.start_session()
	await frames()
	var hub: Control = get_tree().current_scene
	var session: GameSession = hub.game_session
	var store: SaveStore = SaveManager.store
	var group: String = session.group_id
	var target: String = store.slot_path(group, "manual_01")
	check(SaveManager.save_game(session, hub, 1).ok, "故障前建立有效手动检查点")
	match fault:
		"write":
			var slot: String = store.auto_slot(group)
			var obstruction: String = store.slot_path(group, slot).trim_suffix(".tres") + ".pending.tres"
			DirAccess.make_dir_absolute(obstruction)
			hub.inventory.gold = 777
			var departure_message: String = hub.inventory_action("depart", 0, 0)
			check(get_tree().current_scene == hub and departure_message.contains("失败") and not departure_message.contains("已出发"), "出发前实际写入失败时，整备面板返回真实失败提示")
			hub.request_transition("menu")
			check(get_tree().current_scene == hub and hub.inventory.gold == 777 and hub.get_node("Toolbar/Rows/Buttons/Retry").visible, "真实写入失败阻止退出并展示重试，当前会话保留")
			check(store.load_session(group, "manual_01").value.inventory.gold == 0, "写入失败保留上一份有效存档")
			DirAccess.remove_absolute(obstruction)
			hub._on_retry_pressed()
			await frames(8)
			check(get_tree().current_scene.scene_file_path == SceneRouter.MAIN_MENU and store.load_session(group, slot).value.inventory.gold == 777, "移除故障后重试保存，成功才返回菜单")
		"replace":
			var race: RacingStore = RacingStore.new()
			race.root = store.root
			race.armed = true
			session.inventory.gold = 91
			var result: SaveResult = race.write_checkpoint(session.capture("race"), "manual_01")
			check(not result.ok and result.stage == "replace", "真实文件替换失败返回替换阶段")
			check(race.load_session(group, "manual_01.rollback").value.inventory.gold == 0 and session.inventory.gold == 91, "路径竞争后上一份完整检查点仍可选择回退")
			DirAccess.remove_absolute(target)
			DirAccess.rename_absolute(target + ".displaced", target)
			race.armed = false
			check(race.write_checkpoint(session.capture("retry"), "manual_01").ok and race.load_session(group, "manual_01").value.inventory.gold == 91, "解除路径竞争后可重试成功")
		"corrupt", "content":
			if fault == "corrupt":
				var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
				file.store_string("[gd_resource\n损坏中断")
				file.close()
			else:
				var bad: SaveGameResource = session.capture("missing_content")
				var items: ItemsResource = bad.modules[1]
				items.instances[items.equipment_ids.weapon].base = "removed_base"
				ResourceSaver.save(bad, target)
			hub.inventory.gold = 99
			store.catalog(true)
			hub._on_load_pressed()
			hub.slots.selected = SaveSlotResource.new()
			hub.slots.selected.group_id = group
			hub.slots.selected.slot_id = "manual_01"
			hub.slots._on_accept_pressed()
			check(get_tree().current_scene == hub and session.inventory.gold == 99 and hub.slots.get_node("Rows/Message").text.contains("回退"), "坏存档或缺失内容加载失败保留现场，界面说明可选回退")
			var result: SaveResult = store.read_slot(group, "manual_01")
			check(not result.ok and (fault == "corrupt" or result.module_id == "items"), "失败报告读取阶段或具体物品模块")
			hub.slots.selected.slot_id = "auto_01"
			hub.slots._on_accept_pressed()
			await frames()
			hub = get_tree().current_scene
			check(hub.inventory.gold == 0 and hub.game_session != session, "玩家选择自动检查点后完整回退到独立会话")
		"index":
			var index_path: String = store.root.path_join("index.tres")
			DirAccess.remove_absolute(index_path)
			DirAccess.make_dir_absolute(index_path)
			session.inventory.gold = 31
			var result: SaveResult = SaveManager.save_game(session, hub, 2)
			check(result.ok and not result.warning.is_empty() and store.load_session(group, "manual_02").value.inventory.gold == 31, "索引替换失败仍报告正文保存成功和可恢复警告")
			DirAccess.remove_absolute(index_path)
			var index_file: FileAccess = FileAccess.open(index_path, FileAccess.WRITE)
			index_file.store_string("[gd_resource\n损坏索引")
			index_file.close()
			var fresh: SaveStore = SaveStore.new()
			fresh.root = store.root
			check(fresh.catalog().slots.size() == 3, "损坏索引从有效正文重建")
		"interrupted":
			session.inventory.gold = 800
			ResourceSaver.save(session.capture("uncommitted"), target.trim_suffix(".tres") + ".pending.tres")
			var fresh: SaveStore = SaveStore.new()
			fresh.root = store.root
			check(fresh.catalog().slots.size() == 2 and fresh.load_session(group, "manual_01").value.inventory.gold == 0, "中断写入的 pending 不会成为成功存档，重启仍使用上次提交")
			DirAccess.remove_absolute(target)
			DirAccess.remove_absolute(store.slot_path(group, "auto_01"))
			session.inventory.gold = 0
			session.saved_revision = session.revision
			check(SaveManager.save_game(session, hub).ok and FileAccess.file_exists(store.slot_path(group, "auto_01")), "已保存文件缺失时，未变化会话也会重新建立检查点")
		"quit":
			hub.request_transition("depart")
			await frames()
			var arena: Node3D = get_tree().current_scene
			arena.inventory.gold = 643
			SaveManager.operation_completed.connect(_on_quit_saved.bind(group))
			arena._on_quit_pressed()
			return
		_:
			check(false, "未知故障案例")
	get_tree().current_scene.queue_free()
	await frames()
	print("SAVE_FAULT_RESULT: ", fault, " ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

## 正常退出探针在成功保存信号中检查文件，退出必须由正式 Hub 执行。
func _on_quit_saved(result: SaveResult, group: String) -> void:
	if result.ok and result.value is SaveGameResource:
		var latest: SaveSlotResource
		for entry: SaveSlotResource in SaveManager.store.catalog().slots:
			if entry.group_id == group:
				latest = entry
				break
		check(latest != null and SaveManager.store.load_session(group, latest.slot_id).value.inventory.gold == 643, "正常退出前检查点已包含本趟收益")
		print("SAVE_FAULT_RESULT: quit ", failures, " failures")
