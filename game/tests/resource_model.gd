extends Node
## 新持久模型回归：隔离、唯一归属、版本、依赖和默认模块扩展。
var failures: int = 0

## 测试扩展模块，验证总集成无需了解业务字段。
class ExtensionModule extends SaveModule:
	@export var counter: int = 0
	## 分配测试模块 ID。
	func _init() -> void:
		module_id = "extension"
	## 新模块依赖已恢复的据点。
	func dependencies() -> Array[String]:
		return ["hub"]

## 记录断言，全部完成后返回结果。
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

## 使用实际 Resource 副本检验各模块边界。
func _ready() -> void:
	var session: GameSession = GameSession.new()
	var another: GameSession = GameSession.new()
	var character: CharacterResource = session.modules.character
	character.loadout.passives.append("might")
	character.touch()
	check(another.modules.character.loadout.passives.is_empty() and session.revision == 1, "角色模块和嵌套装配独立，变更通知递增修订")
	var items: ItemsResource = session.modules.items
	var item: ItemInstanceResource = ItemInstanceResource.new()
	item.id = "1"
	item.base = "rust_sword"
	items.instances[item.id] = item
	items.bag_ids.append(item.id)
	items.next_id = 2
	var save: SaveGameResource = session.capture("test")
	var registry: SaveModuleRegistry = SaveModuleRegistry.standard()
	var prepared: SaveResult = registry.prepare(save)
	check(prepared.ok, "五个模块组成合法完整检查点")
	if prepared.ok:
		prepared.value.items.instances["1"].locked = true
		prepared.value.character.loadout.passives.clear()
		check(not item.locked and character.loadout.passives == ["might"], "候选恢复与当前会话不存在嵌套共享")
	items.stash_ids.append("1")
	check(not items.validate().ok, "相同装备不能同时归属背包和仓库")
	items.stash_ids.clear()
	items.next_id = 1
	check(not items.validate().ok, "下一个编号不能覆盖已有实例")
	items.next_id = 2
	item.quality = 1
	item.affixes.append(AffixRollResource.create("power", 999.0))
	check(items.validate().ok, "历史抽取值不受当前掉落区间限制")
	item.affixes[0].id = "missing"
	check(not items.validate().ok, "缺少词条内容时给出明确恢复失败")
	check(not registry.register_module(CharacterResource.new()).ok, "注册表拒绝重复模块")
	save.modules.pop_back()
	check(not registry.prepare(save).ok, "当前版本缺少必要模块时拒绝默认填充")
	save = another.capture("test")
	registry.register_module(ExtensionModule.new(), 2)
	prepared = registry.prepare(save)
	check(prepared.ok and prepared.value.extension.counter == 0, "新版本引入模块可以为旧封装创建独立默认值")
	var ordered: SaveResult = registry.ordered(prepared.value)
	check(ordered.ok and ordered.value.back().module_id == "extension", "模块按声明依赖顺序准备")
	save.format_version = 99
	check(not registry.prepare(save).ok, "未来封装版本被拒绝")
	check(not SaveGameResource.valid_id("../../escape"), "角色目录只接受内部生成标识")
	print("RESOURCE_MODEL_RESULT: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
