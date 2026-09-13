class_name SaveModuleRegistry
extends RefCounted
## 注册模块默认值和依赖；总集成不读取业务模块的内部字段。
var prototypes: Dictionary[String, SaveModule] = {}
var introduced_versions: Dictionary[String, int] = {}

## 注册当前游戏的五个持久模块。
static func standard() -> SaveModuleRegistry:
	var registry: SaveModuleRegistry = SaveModuleRegistry.new()
	for module: SaveModule in [CharacterResource.new(), ItemsResource.new(), EconomyResource.new(), ProgressionResource.new(), HubResource.new()]:
		registry.register_module(module)
	return registry

## 注册模块；新增模块只在更旧的封装版本中允许缺省。
func register_module(prototype: SaveModule, introduced_version: int = 1) -> SaveResult:
	if prototype == null or prototype.module_id.is_empty() or prototypes.has(prototype.module_id):
		return SaveResult.failure("registry", ERR_ALREADY_EXISTS, "模块 ID 为空或重复")
	# 版本字段默认零，创建新模块时显式赋值，确保 ResourceSaver 总是把版本写入文件。
	prototype.module_version = prototype.current_version()
	prototypes[prototype.module_id] = prototype
	introduced_versions[prototype.module_id] = introduced_version
	return SaveResult.success()

## 创建独立默认模块，角色之间不共享可变资源。
func defaults() -> Array[SaveModule]:
	var result: Array[SaveModule] = []
	for prototype: SaveModule in prototypes.values():
		result.append(prototype.capture())
	return result

## 按依赖拓扑顺序返回模块，缺少依赖或环会中止恢复。
func ordered(modules: Dictionary) -> SaveResult:
	var ordered_modules: Array[SaveModule] = []
	var remaining: Dictionary = modules.duplicate()
	var ready: Dictionary = {}
	while not remaining.is_empty():
		var progressed: bool = false
		for id: String in remaining.keys():
			var module: SaveModule = remaining[id]
			var satisfied: bool = true
			for dependency: String in module.dependencies():
				if not ready.has(dependency):
					satisfied = false
			if satisfied:
				ordered_modules.append(module)
				ready[id] = true
				remaining.erase(id)
				progressed = true
		if not progressed:
			return SaveResult.failure("dependencies", ERR_INVALID_DATA, "模块依赖缺失或存在环")
	return SaveResult.success(ordered_modules)

## 在独立候选上完成升级、全部校验和依赖准备，成功才返回模块。
func prepare(save: SaveGameResource) -> SaveResult:
	if save == null or save.format_version < 1 or save.format_version > SaveGameResource.FORMAT_VERSION or save.content_version < 1 or save.content_version > SaveGameResource.CONTENT_VERSION:
		return SaveResult.failure("version", ERR_INVALID_DATA, "存档格式或内容版本不受支持")
	if not SaveGameResource.valid_id(save.group_id) or not SaveGameResource.valid_id(save.checkpoint_id) or save.saved_at < 1:
		return SaveResult.failure("validate", ERR_INVALID_DATA, "检查点身份或时间损坏")
	var modules: Dictionary = {}
	for source: SaveModule in save.modules:
		if source == null or not prototypes.has(source.module_id) or modules.has(source.module_id):
			return SaveResult.failure("validate", ERR_INVALID_DATA, "模块缺失、重复或当前游戏不支持")
		var module: SaveModule = source.capture()
		if module.get_script() != prototypes[module.module_id].get_script():
			return module.invalid("type", "模块类型与注册定义不一致")
		var result: SaveResult = module.upgrade()
		if not result.ok:
			return result
		result = module.validate()
		if not result.ok:
			return result
		modules[module.module_id] = module
	for id: String in prototypes:
		if not modules.has(id):
			if save.format_version >= introduced_versions[id]:
				return SaveResult.failure("validate", ERR_INVALID_DATA, "存档缺少必要模块", id)
			modules[id] = prototypes[id].capture()
			var validation: SaveResult = modules[id].validate()
			if not validation.ok:
				return validation
	var order: SaveResult = ordered(modules)
	if not order.ok:
		return order
	for module: SaveModule in order.value:
		var result: SaveResult = module.prepare_restore(modules)
		if not result.ok:
			return result
	return SaveResult.success(modules)
