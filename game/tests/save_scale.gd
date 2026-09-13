extends Node
## 实测 Resource 检查点规模成本；可用 --scale-count=10000 扩大测试仓库容量。
var failures: int = 0

## 记录大小、耗时和当前进程静态内存，不修改正式背包容量配置。
func _ready() -> void:
	var count: int = 166
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scale-count="):
			count = maxi(166, int(argument.get_slice("=", 1)))
	var session: GameSession = GameSession.new()
	var items: ItemsResource = session.modules.items
	items.stash_capacity = count - 46
	session.generator.rng.seed = 8912
	var bases: Array[String] = ["rust_sword", "iron_helm", "mail", "grips", "boots", "copper_ring"]
	for index: int in range(count):
		var item: ItemInstanceResource = session.generator.generate(8, true)
		if index < 6:
			item.base = bases[index]
			item.quality = 0
			item.unique_id = ""
			item.affixes.clear()
			items.equipment_ids[ItemCatalog.SLOTS[index]] = item.id
		elif index < 46:
			items.bag_ids.append(item.id)
		else:
			items.stash_ids.append(item.id)
		items.instances[item.id] = item
	var store: SaveStore = SaveStore.new()
	store.root = "user://scale_test"
	var memory_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var started: int = Time.get_ticks_usec()
	var snapshot: SaveGameResource = session.capture("scale")
	var write: SaveResult = store.write_checkpoint(snapshot, "manual_01")
	var save_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var loaded: SaveResult = store.load_session(session.group_id, "manual_01")
	var load_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	if not write.ok or not loaded.ok:
		failures += 1
		push_error(write.diagnostic() + loaded.diagnostic())
	else:
		var expected: String = ResourceFingerprint.digest(session.generator.generate(8, true))
		var next: String = ResourceFingerprint.digest(loaded.value.generator.generate(8, true))
		if loaded.value.modules.items.instances.size() != count or expected != next:
			failures += 1
			push_error("大容量往返丢失实例或随机序列")
	var file: FileAccess = FileAccess.open(store.slot_path(session.group_id, "manual_01"), FileAccess.READ)
	var memory_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	print("SAVE_SCALE_METRICS: count=%d bytes=%d save_ms=%.2f load_ms=%.2f retained_memory_delta=%d" % [count, file.get_length() if file != null else 0, save_ms, load_ms, memory_after - memory_before])
	print("SAVE_SCALE_RESULT: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
