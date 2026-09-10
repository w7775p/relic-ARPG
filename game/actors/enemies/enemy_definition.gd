class_name EnemyDefinition
extends Resource
## 配置敌人基础属性与行为类型，运行状态保留在敌人实例。

enum Kind { MELEE, RANGED, CHARGER }

@export var display_name: String = "近战怪"
@export var kind: Kind = Kind.MELEE
@export var health: float = 100.0
@export var armor: float = 0.0
@export var speed_mps: float = 3.2
@export var damage: float = 12.0
@export var attack_cooldown_sec: float = 1.4
@export var windup_sec: float = 0.45
@export var tint: Color = Color(0.75, 0.3, 0.28)
@export var is_elite: bool = false
