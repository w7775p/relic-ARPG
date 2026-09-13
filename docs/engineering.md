# 当前工程实现

引擎实测：`4.7.2.stable.official.ed1daf0bf`；导出模板：4.7.2 stable；语言：GDScript；插件：无。M0 使用兼容渲染器，原生几何体已足以验证操控与场景流程；M1 继续使用兼容渲染器，当前原生网格效果没有引入 Forward+ 专属功能；目标机结果决定后续选择。目标 Windows 电脑型号、显卡与驱动待提供。

`game/` 对应 `res://`。仓库文档放 `docs/`，辅助验证放 `tools/`，导出包放 Git 忽略的 `builds/`。其余功能目录随代码创建，完整目标结构见 `plan.md`。

| 实现 | 职责 |
| --- | --- |
| `app/boot/` | 启动后延迟进入主菜单；发行 smoke 沿正式 Hub 路由运行 |
| `app/validation/` | 源码与成品共用拾取回归；仅由测试场景或 Boot 的 `--smoke-loot` 参数启动 |
| `app/services/scene_router.gd` | MainMenu / Hub / Expedition 场景切换、一次性跨场景角色状态交接、离场解除暂停 |
| `app/services/settings_manager.gd` | ConfigFile 设置与原生窗口、音频总线应用 |
| `app/services/audio_manager.gd` | 原生 WAV 短提示及 SFX 总线播放 |
| `app/services/save_manager.gd` | 地点能力、保存/恢复用例及结构化结果；文件事务委托 SaveStore |
| `actors/player/` | CharacterBody3D、胶囊碰撞、独立视觉朝向与武器挂点 |
| `world/hub/` | 独立据点场景；装备、背包、仓库、出售、技能与被动整备 |
| `world/maps/expedition_runtime.*` | 正式新角色探险场景；接收 Hub 状态、运行战斗、撤离/死亡返回 Hub |
| `systems/persistence/` | 会话、完整检查点、模块注册/升级/准备恢复、槽位存储与可重建索引 |
| `ui/saves/` | 多角色手动槽、自动历史、覆盖确认及失败回退选择 |
| `world/camera/` | 正交镜头，固定朝向，指数平滑跟随 |
| `ui/menus/` | 主菜单与可复用设置面板 |
| `ui/inventory/` | Hub 与探险共用物品/装配面板，通过 `session.is_hub()` 查询地点能力 |
| `ui/theme/` | 原生 Theme、样式盒与中文系统字体候选 |
| `tests/` | 实际场景回归，发行导出排除；包含 HubFlow 场景边界验证 |

移动用 `Input.get_vector`，斜向速度保持一致，`move_and_slide` 处理墙体与地面。鼠标投向脚下水平面，仅转动视觉根。闪避没有无敌效果，当前只验证移动速度、持续时间、冷却和碰撞。

测试场地根节点持续处理暂停输入；玩家、镜头和导航区域明确使用可暂停模式。HUD 不拦截鼠标。设置面板和暂停菜单在暂停中保持响应。

正式持久化使用五模块 Resource 完整检查点，只有 Hub 开放保存；设置继续使用 ConfigFile。旧 JSON 与旧探险兼容已按本轮决定移除，不提供旧档迁移。M0/M1 调试场地不保存位置。完整字段及扩展规则见 [save_system.md](save_system.md)。

自动化测试使用临时用户目录；正式模板保存在引擎标准目录。Git 远端地址使用普通 HTTPS 地址，认证信息由外部连接管理。

`project.godot` 明确关闭 `editor/export/convert_text_resources_to_binary`。4.7.2 实测导出二进制转换会将词条 `slots: PackedStringArray` 变为空，源码与普通 ResourceSaver 二进制往返正常；保留内容 `.tres` 后发布包恢复完整配置。`tools/verify.py` 除源码回归还导出并运行 PCK；Windows 进一步对实际 exe 执行同一拾取与存档用例，防止仅启动成功掩盖玩法数据丢失。

官方实现依据：[CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)、[命令行导入与导出](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)。实际 API 兼容性以本仓库 4.7.2 运行结果为准。

## M1 战斗实现

M1 延续兼容渲染器，无动态特效灯。`combat_arena.tscn` 继承 M0 场地，添加会话内 CombatSystem、SkillRunner、EffectResolver、EncounterDirector 和 CombatFeedback。M0 的场景回归保持独立。

| 模块 | 实际规则 |
| --- | --- |
| CombatActor | 独立生命、护甲、感电、硬直；死亡先标记，再通知移出目标集合 |
| CombatSystem | 独立固定种子 RNG；注册集合范围筛选与地形射线；直接攻击暴击、护甲减伤、感电增伤 |
| SkillRunner | 普攻前方 120 度扇形；旋风移动施放、按秒消耗、按间隔伤害；停止施放回复能量 |
| EffectResolver | 命中事件快照入队；每帧处理至多 256 件，余额保留；死亡有限传播 |
| EnemyController | 近战蓄力、远程扫掠弹体、锁向冲锋；NavigationAgent3D 导航与局部避让 |
| EncounterDirector | 24 怪包含三种类型及一名精英；F6 生成 100 怪；压力脚本持续补足目标数 |
| CombatFeedback | 原生网格挥砍、环形范围、闪电、颜色受击、死亡补间；最多 96 个短期视觉节点 |

直接攻击暴击才能触发闪电，触发有 0.12 秒间隔。闪电最多访问五个不同可见目标，存活目标感电三秒；感电使后续伤害提高 20%。击杀事先已感电的目标触发爆炸，爆炸可击杀其他已感电目标继续传播，自身不施加感电。每名角色只产生一次死亡事件。

预设定义保存在 `content/builds/`，静态 Resource 共享，换装仅替换属性引用；待处理事件继续使用攻击时的预设快照。真实装备生成与穿脱归 M2。能量回复分别接受直接命中及击杀，单体战斗也有命中回复。

范围目标来自会话注册集合，不受物理查询默认结果上限影响；LOS 射线只检测地形，弹体扫掠检测地形和玩家。尸体立即退出可命中集合，短动画后释放。重开清除尸体、在途弹体和触发队列。

局部避让与碰撞层：敌人碰撞层为 4，检测世界及玩家（掩码 3），相互通过原生导航避让，每名代理最多六个近邻。寻路目标每 0.4 秒错峰刷新，每个物理帧推进导航路径。

官方依据：[NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html)、[PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)。

## M2 / D1 装备与探险实现

正式入口为 `Hub → expedition_runtime.tscn`，`expedition_runtime.gd` 和场景直接继承 `combat_arena`，承载实际战斗、掉落和探险生命周期。旧 expedition 已删除；M1 测试场景和压力测试保持独立。

| 模块 | 职责 |
| --- | --- |
| `systems/items/` | ItemBase、AffixDefinition、UniqueDefinition 资源，目录索引，独立 RNG 抽取与实例描述 |
| `content/items/` | 10 底材、12 词条、3 独特装备的可编辑 `.tres` |
| `systems/inventory/` | 单一持有归属、40 格背包、120 格仓库、6 槽穿戴、锁定、出售、属性汇总与基础经验成长 |
| `ui/inventory/` | 原生容器与列表、双列装备说明、服务按钮；通过场景能力接口判断 Hub 服务权限 |
| `world/hub/hub.gd` | 当前 GameSession、据点服务、保存入口及成功保存后离场 |
| `world/maps/expedition_runtime.gd` | 正式探险生命周期；领取 Hub 状态、生成 48 怪、战斗、撤离/死亡回 Hub |
| `systems/persistence/` | SaveGameResource 聚合五个模块；GameSession 建立业务入口，SaveStore 完成读写事务 |

实例为 ItemInstanceResource：`id/base/level/quality/unique_id/affixes/locked`；每条 AffixRollResource 记录 `id/value`。独特使用稳定字符串 ID `thunder_ring`、`ember_mail`、`energy_grips`，随机目录顺序不构成持久身份。词条描述来自实际抽取值，独特机制来自资源参数，技能默认数值来自 BuildDefinition。定义资源不承载每件装备的强化或抽取结果。

生成顺序：选底材→按来源抽品质→精英独特概率→按物品等级和部位过滤词条→加权抽取→排除整个互斥组→抽具体值。普通零条、魔法 1～2 条、稀有 3～4 条，独特固定机制加一条浮动词条。物品等级当前取角色等级。普通怪装备率 28%，精英必掉装备；精英随机独特概率 12%。前三次清场额外定向奖励三件机制装备。出售、掉落和成长数值目前均为原型参数。

普通怪经验 6，精英 35；升级需求为当前等级×60，每级基础伤害 +2、生命上限 +15。升级与换装不会直接回满生命。通关撤离使难度 +1，每档怪物生命 +25%、伤害 +15%，金币乘当前难度；额外掉落数和物品等级暂不随难度直接增加。

### Hub / Expedition 生命周期

主菜单新建 GameSession，起始装备只由新角色工厂发放一次。Hub 与 ExpeditionRuntime 各自拥有当前会话；SceneRouter 只暂存一次过渡引用，目标领取后清空。InventoryState、LoadoutState 和 ItemGenerator 直接操作所属持久 Resource，保存时捕获独立深拷贝。

Hub 开放仓库、出售、技能和被动；探险中 `is_hub()` 与 `can_save_checkpoint()` 返回 false。撤离、死亡或正常退出先排空有限触发队列，保留已拾取物品和成长；清场进度和难度只结算一次。地面对象随场景销毁，战斗技能计时清理，再交接 GameSession 回真实 Hub。

Hub 在初建、出发前、结算返回、退出及持久事务约 1 秒去抖后保存。正常菜单/退出动作必须等待成功；失败显示阶段与重试入口，当前会话继续保留。读取旧检查点整体替换为候选会话，进入 Hub 后不立即自动保存。不存在 `in_town` 或旧 JSON 分支。

### Resource 持久化

总集成负责收集和事务，模块负责业务字段、独立版本、升级、校验及依赖准备。角色、物品、经济、据点、进度分别定义 Resource；五手动槽与自动最近三版都是同一格式的完整检查点。可重建索引只存摘要，实际加载仍重新验证正文；恢复失败不改变当前会话。

保存执行校验、同目录 pending 写入、真实读回、字段核对、旧文件恢复副本、替换及索引更新。正文替换成功是保存成功边界，索引失败显示警告。持久版本字段默认零，由新建工厂显式写当前版本，防止 ResourceSaver 省略版本后跳过升级。具体接口、数据表、故障行为和性能边界以 [save_system.md](save_system.md) 为准。

背包打开暂停探险世界；列表拥有焦点时全局 I/Esc/F5 仍可使用。装备掉落为原生小方块与 Label3D 名称，稀有以上增加环形反馈。当前标签没有屏幕空间防重叠排布，使用附近候选选择与过滤控制拾取；美术与标签视觉打磨仍需后续验收。

## D1 技能装配与流血技能

`LoadoutState` 由 InventoryState 持有并交给 SkillRunner，记录 basic/main/auxiliary 技能 ID 和最多三项被动 ID。静态 SkillDefinition 与 PassiveDefinition 资源显式预载；`inventory.build()` 和 `defense()` 分别叠加技能与防御属性。装配修改由 Hub 的 `loadout_action` 处理；探险中的共用面板只读。右键主要槽当前提供旋风与流血横扫，F 辅助槽提供战吼，Q 药剂使用独立语义动作。

横扫配置保存在 `content/skills/sweep.tres`：前方范围筛选继续复用 CombatSystem 的注册目标集合与地形 LOS。直接伤害属于 direct skill，可暴击并触发已有直接命中收益；流血以单独 `bleed` 来源进入伤害系统。每层保存攻击根编号、伤害、击杀回能与死亡爆炸参数、剩余时间和下一跳，最多三层；满层后替换剩余时间最短的一层。流血跳伤不属于 direct skill，因此没有暴击闪电或直接命中回能；死亡仍沿统一事件发放一次击杀收益。

战吼配置保存在 `content/skills/warcry.tres`，提供单层护甲增益、即时回能、持续时间和冷却。重复施放刷新持续时间，护甲只保留一层；属性重算会把这层临时护甲重新叠到装备基础值上，结束与 reset 通过同一入口移除。恢复药剂配置保存在 `content/skills/potion.tres`，Q 使用时按最大生命比例治疗；满血、死亡、暂停或冷却中拒绝，进入新探险时 reset 清零药剂冷却。

长期装配由 CharacterResource 内的 LoadoutResource 保存，LoadoutState 提供规则与变更通知。流血、横扫计时、战吼与药剂归本趟 SkillRunner/战斗对象；撤离后清理，进入新探险重新初始化。它们不进入正式存档。
