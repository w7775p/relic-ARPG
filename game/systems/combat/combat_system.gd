class_name CombatSystem
extends Node
## 汇总敌人集合，统一处理范围、视线、暴击、防御与伤害事件。

signal hit_resolved(event: DamageEvent)

var enemies: Array[CombatActor] = []
var player: CombatActor
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var kills: int = 0
var damage_dealt: float = 0.0
var clock_sec: float = 0.0
var _next_attack_id: int = 0


## 使用独立战斗随机序列，场地设置种子以便复现。
func _ready() -> void:
	rng.seed = 1701


## 使用游戏时间，暂停时计时随世界一起停止。
func _physics_process(delta: float) -> void:
	clock_sec += delta


## 注册唯一可命中角色；死亡和场景销毁均移出集合。
func register_enemy(actor: CombatActor) -> void:
	if not enemies.has(actor):
		enemies.append(actor)
		actor.died.connect(_remove_enemy.bind(actor))
		actor.tree_exiting.connect(_remove_enemy.bind(actor))


## 移除角色；重复移除保持幂等。
func _remove_enemy(actor: CombatActor) -> void:
	enemies.erase(actor)


## 分配根攻击编号，触发出的伤害沿用该编号。
func next_attack_id() -> int:
	_next_attack_id += 1
	return _next_attack_id


## 检查地形视线；伤害与闪电连锁都不能穿过墙体。
func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to) < 0.001:
		return true
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.8, to + Vector3.UP * 0.8, 1)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## 遍历注册集合获取范围目标，无物理查询默认数量上限；每个角色只返回一次。
func targets_in_range(origin: Vector3, radius_m: float) -> Array[CombatActor]:
	var targets: Array[CombatActor] = []
	for enemy: CombatActor in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead and enemy.global_position.distance_squared_to(origin) <= radius_m * radius_m:
			if has_line_of_sight(origin, enemy.global_position):
				targets.append(enemy)
	return targets


## 判断会触发直接命中收益和暴击闪电的攻击来源。
static func is_direct_skill(skill_id: StringName) -> bool:
	return skill_id == &"primary" or skill_id == &"whirlwind" or skill_id == &"sweep"


## 结算玩家伤害；持续与派生技能不掷暴击，感电提供 20% 伤害增幅。
func hit(target: CombatActor, amount: float, skill_id: StringName, root_id: int, build: BuildDefinition) -> DamageEvent:
	if not is_instance_valid(target) or target.is_dead or amount <= 0.0:
		return null
	var event: DamageEvent = DamageEvent.new()
	event.target = target
	event.origin = target.global_position
	event.skill_id = skill_id
	event.root_attack_id = root_id
	event.was_shocked = target.shock_remaining_sec > 0.0
	event.build = build
	var direct: bool = is_direct_skill(skill_id)
	event.is_critical = direct and rng.randf() < build.critical_chance
	var multiplier: float = build.critical_multiplier if event.is_critical else 1.0
	if event.was_shocked:
		multiplier *= 1.2
	var damage: float = amount * multiplier * 100.0 / (100.0 + maxf(0.0, target.armor))
	event.amount = target.receive_damage(damage)
	event.killed = target.is_dead
	if skill_id == &"lightning" and not target.is_dead:
		target.shock_remaining_sec = build.shock_duration_sec
	if event.killed:
		kills += 1
	damage_dealt += event.amount
	hit_resolved.emit(event)
	return event


## 敌人伤害走同一生命和护甲规则；闪避期间可被命中。
func hit_player(amount: float) -> float:
	if not is_instance_valid(player) or player.is_dead:
		return 0.0
	return player.receive_damage(amount * 100.0 / (100.0 + maxf(0.0, player.armor)))
