class_name EliteModifierDefinition
extends Resource
## 精英修饰只保存静态参数；运行时由敌人实例复制结算，避免改写共享 EnemyDefinition。

@export var id: String = ""
@export var display_name: String = ""
@export var compatible_kinds: PackedInt32Array = PackedInt32Array([0, 1, 2])
@export var health_multiplier: float = 1.0
@export var armor_bonus: float = 0.0
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var attack_cooldown_multiplier: float = 1.0
@export var windup_multiplier: float = 1.0
@export var presentation_tint: Color = Color.WHITE

## 只允许标记为精英且行为类型在兼容表中的原型使用当前修饰。
func supports(definition: EnemyDefinition) -> bool:
	return definition != null and definition.is_elite and compatible_kinds.has(int(definition.kind))
