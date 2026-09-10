class_name EffectResolver
extends Node
## 排队处理命中与击杀触发，派生伤害重新入队，避免同步递归。

var combat: CombatSystem
var skills: SkillRunner
var feedback: CombatFeedback
var queue: Array[DamageEvent] = []
var lightning_count: int = 0
var explosion_count: int = 0
var peak_queue_size: int = 0
var _next_lightning_sec: float = 0.0


## 接收快照；每帧最多处理 256 个事件，剩余事件留待后续帧完整结算。
func enqueue(event: DamageEvent) -> void:
	queue.append(event)
	peak_queue_size = maxi(peak_queue_size, queue.size())


## 处理队列中的来源规则；没有目标时的暴击也不会消耗额外随机数。
func _physics_process(_delta: float) -> void:
	drain()


## 每个死亡事件只出现一次，爆炸链终点由有限敌人集合确定。
func drain(budget: int = 256) -> void:
	var processed: int = 0
	while not queue.is_empty() and processed < budget:
		var event: DamageEvent = queue.pop_front()
		processed += 1
		var direct: bool = event.skill_id == &"primary" or event.skill_id == &"whirlwind"
		if direct:
			skills.restore_energy(event.build.hit_energy)
		if event.killed:
			skills.restore_energy(event.build.kill_energy)
			if event.was_shocked and event.build.death_explosion:
				_explode(event)
		if direct and event.is_critical and event.build.chain_count > 0 and combat.clock_sec >= _next_lightning_sec:
			_next_lightning_sec = combat.clock_sec + event.build.lightning_cooldown_sec
			_chain_lightning(event)


## 每次连锁选择最近的可见未访问目标；已死亡起点只作为空间锚点。
func _chain_lightning(event: DamageEvent) -> void:
	lightning_count += 1
	var origin: Vector3 = event.origin
	var visited: Array[CombatActor] = []
	for index: int in range(event.build.chain_count):
		var target: CombatActor = null
		var distance: float = INF
		for candidate: CombatActor in combat.targets_in_range(origin, event.build.chain_range_m):
			if visited.has(candidate):
				continue
			var squared: float = candidate.global_position.distance_squared_to(origin)
			if squared < distance:
				target = candidate
				distance = squared
		if target == null:
			break
		visited.append(target)
		feedback.lightning(origin, target.global_position)
		origin = target.global_position
		combat.hit(target, event.build.lightning_damage, &"lightning", event.root_attack_id, event.build)


## 爆炸不施加感电；击杀原本已感电目标时可继续传播。
func _explode(event: DamageEvent) -> void:
	explosion_count += 1
	feedback.ring(event.origin, event.build.explosion_radius_m, Color(1.0, 0.55, 0.16), 0.32)
	for target: CombatActor in combat.targets_in_range(event.origin, event.build.explosion_radius_m):
		combat.hit(target, event.build.explosion_damage, &"explosion", event.root_attack_id, event.build)


## 重开时清空旧事件，防止旧尸体效果作用于新遭遇。
func reset() -> void:
	queue.clear()
	_next_lightning_sec = 0.0
	lightning_count = 0
	explosion_count = 0
	peak_queue_size = 0
