# 当前工程实现

引擎实测：`4.7.2.stable.official.ed1daf0bf`；导出模板：4.7.2 stable；语言：GDScript；插件：无。M0 使用兼容渲染器，原生几何体已足以验证操控与场景流程；M1 继续使用兼容渲染器，当前原生网格效果没有引入 Forward+ 专属功能；目标机结果决定后续选择。目标 Windows 电脑型号、显卡与驱动待提供。

`game/` 对应 `res://`。仓库文档放 `docs/`，辅助验证放 `tools/`，导出包放 Git 忽略的 `builds/`。其余功能目录随代码创建，完整目标结构见 `plan.md`。

| 实现 | 职责 |
| --- | --- |
| `app/boot/` | 启动后延迟进入主菜单 |
| `app/services/scene_router.gd` | 场景切换、恢复意图、离场解除暂停 |
| `app/services/settings_manager.gd` | ConfigFile 设置与原生窗口、音频总线应用 |
| `app/services/audio_manager.gd` | 原生 WAV 短提示及 SFX 总线播放 |
| `app/services/save_manager.gd` | 版本化 JSON、坐标校验、临时文件替换 |
| `actors/player/` | CharacterBody3D、胶囊碰撞、独立视觉朝向与武器挂点 |
| `world/camera/` | 正交镜头，固定朝向，指数平滑跟随 |
| `world/maps/` | 可编辑静态场地、导航烘焙、HUD、暂停及存档入口 |
| `ui/menus/` | 主菜单与可复用设置面板 |
| `ui/theme/` | 原生 Theme、样式盒与中文系统字体候选 |
| `tests/` | 实际场景回归，发行导出排除 |

移动用 `Input.get_vector`，斜向速度保持一致，`move_and_slide` 处理墙体与地面。鼠标投向脚下水平面，仅转动视觉根。闪避没有无敌效果，当前只验证移动速度、持续时间、冷却和碰撞。

测试场地根节点持续处理暂停输入；玩家、镜头和导航区域明确使用可暂停模式。HUD 不拦截鼠标。设置面板和暂停菜单在暂停中保持响应。

M0 存档只保存 `version=1`、`map_id` 和 `player_position`。读取损坏文件或未知版本时返回空结果，主菜单禁用继续按钮。保存返回真实错误，失败时保留场景。M2 增加装备、敌人、掉落及技能运行状态时，单独升级存档结构和恢复规则。

自动化测试使用临时用户目录；正式模板保存在引擎标准目录。Git 远端地址使用普通 HTTPS 地址，认证信息由外部连接管理。

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

## M2 装备与探险实现

正式入口改为继承 M1 场地的 `expedition.tscn`，M1 测试场景和压力测试保持独立。会话内装配规则与界面，继续沿用四个全局服务。

| 模块 | 职责 |
| --- | --- |
| `systems/items/` | ItemBase、AffixDefinition、UniqueDefinition 资源，目录索引，独立 RNG 抽取与实例描述 |
| `content/items/` | 10 底材、12 词条、3 独特装备的可编辑 `.tres` |
| `systems/inventory/` | 单一持有归属、40 格背包、120 格仓库、6 槽穿戴、锁定、出售、属性汇总与基础经验成长 |
| `ui/inventory/` | 原生容器与列表、双列装备说明、服务按钮；操作由会话再次校验地点 |
| `world/maps/expedition.gd` | 击杀产出、地面物品、手动/自动拾取、据点出发、撤离、死亡与快照装配 |
| `systems/persistence/` | 显式运行字段快照、版本内数据校验、内容白名单、跨容器物品 ID 唯一性 |

实例结构：`id/base/level/quality/unique/affixes/locked`；每条词条记录 `id/value`。当前版本独特编号固定 0=雷鸣指环、1=余烬锁甲、2=噬能护手；更改映射必须迁移存档。词条描述来自实际抽取值，独特机制来自资源参数，技能默认数值来自 BuildDefinition。定义资源不承载每件装备的强化或抽取结果。

生成顺序：选底材→按来源抽品质→精英独特概率→按物品等级和部位过滤词条→加权抽取→排除整个互斥组→抽具体值。普通零条、魔法 1～2 条、稀有 3～4 条，独特固定机制加一条浮动词条。物品等级当前取角色等级。普通怪装备率 28%，精英必掉装备；精英随机独特概率 12%。前三次清场额外定向奖励三件机制装备。出售、掉落和成长数值目前均为原型参数。

普通怪经验 6，精英 35；升级需求为当前等级×60，每级基础伤害 +2、生命上限 +15。升级与换装不会直接回满生命。通关撤离使难度 +1，每档怪物生命 +25%、伤害 +15%，金币乘当前难度；额外掉落数和物品等级暂不随难度直接增加。

保存版本 2 与版本 1 同时可读。新版本保存背包、仓库、穿戴、成长、地面物品、活敌人的生命/护甲/感电/硬直/击退/速度/状态/蓄力与攻击冷却/锁定方向、玩家闪避、技能间隔、弹体位置方向寿命、战斗计时与触发冷却。随机状态用十进制字符串存储，避免 JSON 双精度丢失 64 位状态。实例计数随存档恢复，掉落与战斗序列互相独立。

保存是本物理阶段的结算检查点：先排空有限触发队列，然后记录所有结果。恢复不重放死亡事件，尸体只留下已经生成的战利品；纯视觉补间不保存，仍处于蓄力的敌人重建危险提示，导航路径由原生代理重算。按键意图重新采集，技能与闪避冷却继续保留。存档字段逐一校验，JSON 解析结果禁止直接整包写进任意节点。

背包打开暂停世界；列表拥有焦点时全局 I/Esc/F5 仍可使用。装备掉落为原生小方块与 Label3D 名称，稀有以上增加环形反馈。当前标签没有屏幕空间防重叠排布，使用附近候选选择与过滤控制拾取；美术与标签视觉打磨仍需后续验收。
