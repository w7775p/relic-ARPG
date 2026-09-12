class_name GameSession
extends RefCounted
## 场景拥有的运行会话；仅持久模块参与检查点，路由只暂存一次引用。
signal changed(module_id: String)
var group_id: String = SaveGameResource.make_id()
var modules: Dictionary = {}
var inventory: InventoryState
var generator: ItemGenerator
var revision: int = 0
var saved_revision: int = -1
var saved_checkpoint_id: String = ""
var needs_initial_save: bool = true
var return_action: String = ""
var pending_settlement: bool = false

## 创建模块并连接事务完成通知。
func _init(initial_modules: Array[SaveModule] = []) -> void:
	var values: Array[SaveModule] = initial_modules if not initial_modules.is_empty() else SaveModuleRegistry.standard().defaults()
	for module: SaveModule in values:
		modules[module.module_id] = module
		module.changed.connect(_on_module_changed.bind(module.module_id))
	inventory = InventoryState.new(modules.items, modules.character, modules.economy, modules.progression)
	generator = ItemGenerator.new(modules.items)

## 模块发生业务变化后递增会话修订，供自动存档去抖合并。
func _on_module_changed(id: String) -> void:
	revision += 1
	changed.emit(id)

## 捕获独立完整资源，生成器需在此调用前同步到所属模块。
func capture(reason: String) -> SaveGameResource:
	generator.synchronize()
	var save: SaveGameResource = SaveGameResource.new()
	save.group_id = group_id
	save.checkpoint_id = SaveGameResource.make_id()
	save.saved_at = int(Time.get_unix_time_from_system())
	save.reason = reason
	for module: SaveModule in modules.values():
		save.modules.append(module.capture())
	return save

## 从已准备好的候选模块构建全新会话；读取本身不触发自动保存。
static func restored(save: SaveGameResource, prepared: Dictionary) -> GameSession:
	var values: Array[SaveModule] = []
	for module: SaveModule in prepared.values():
		values.append(module)
	var session: GameSession = GameSession.new(values)
	session.group_id = save.group_id
	session.saved_revision = session.revision
	session.saved_checkpoint_id = save.checkpoint_id
	session.needs_initial_save = false
	return session

## 唯一的新角色初始化入口，起装只在新建时生成一次。
static func new_character() -> GameSession:
	var session: GameSession = GameSession.new()
	var starter: ItemInstanceResource = session.generator.generate(1)
	starter.base = "rust_sword"
	starter.quality = 0
	starter.unique_id = ""
	starter.affixes.clear()
	session.inventory.pickup(starter)
	session.inventory.equip(0)
	return session
