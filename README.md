# Relic ARPG

单机 3D 俯视动作刷宝项目。当前为 **M2 刷宝原型 + D1 技能扩展**：旋风近战、流血横扫、战吼、恢复药剂、随机装备、雷霆旋风构筑已经接通；据点已拆为独立 Hub 场景。正式美术仍为 Godot 几何体占位，Demo 的其他构筑、随机墓园、首领和发行打磨尚未完成。

## 启动与操作

用 **Godot 4.7.2 标准版**打开 `game/project.godot`，运行项目。Windows 键鼠为首个验证平台，当前使用兼容渲染器。

| 操作 | 按键 / 入口 |
| --- | --- |
| 移动 / 瞄准 | WASD 或方向键 / 鼠标 |
| 普攻 / 主要技能 | 鼠标左键 / 右键；右键技能在据点选择旋风或流血横扫 |
| 战吼 | F；需在辅助槽装配战吼 |
| 恢复药剂 | Q；独立于装备与技能槽，按最大生命比例恢复 |
| 闪避 | 空格 |
| 背包与换装 | I；选择物品，左右查看词条与当前装备，点击穿戴 |
| 拾取装备 | 靠近后 E；重叠候选按 Tab 切换 |
| 金币与材料 | 两米内自动拾取 |
| 撤离整备 | T，或背包里的撤离按钮 |
| 保存完整进度 | F5；当前仍走旧 v4 JSON 兼容存档，下一轮迁移为 Resource |
| DebugLog 控制台 | F3；发布包内可随时查看当前 Godot 日志与保存诊断 |
| 暂停与设置 | Esc |

新建角色进入独立 `Hub` 据点场景，在整备界面完成装备、仓库、出售、技能与被动调整；点击“出发”后切换到 `ExpeditionRuntime`，进入 48 怪固定场地，包含近战、远程、冲锋与一名精英。清怪获得经验、金币、材料与装备，穿戴即时改变伤害、范围、攻速及触发机制。清场后拾取战利品，按 T 撤离；撤离或死亡会结束当前探险场景并真实切换回 Hub。已拾取装备与成长继续保留，未拾取物品随本次探险场景回收。

前三次清场依次在最后击杀位置奖励雷鸣指环、余烬锁甲、噬能护手，仍需手动拾取穿戴。三件分别提供暴击连锁、感电死亡爆炸和命中/击杀回能；独特装备也可由精英随机掉落。独特装备不会自动穿戴。

背包 40 格、仓库 120 格；仓库转移与出售在 Hub 操作。六个装备槽为武器、头部、胸甲、手部、足部、戒指。锁定防止误卖和丢弃；满包可以交换同槽装备，卸下需要空位。过滤可选全部、魔法以上、稀有以上，隐藏的地面物品继续保存在当前探险中。材料暂作持有与掉落资源，消耗服务留给后续 D1 任务。

## D1 技能与被动

Hub 整备的下拉页签选择“技能与被动”。左键基础槽可装普攻；右键主要槽可选择旋风或流血横扫；F 辅助槽可装战吼。六个被动全部开放，同时最多选三个：强攻（伤害＋6）、精准（暴击＋5 个百分点）、扩旋（旋风半径＋0.5 米）、健壮（生命上限＋60）、坚甲（护甲＋15）、调息（停止施放回能＋6/秒）。Hub 免费调整，探险中只读。属性与装备相加；切换保留长期角色状态，进入探险后重新构建战斗属性与瞬态。

流血横扫为前方范围直接攻击，命中后最多保留 3 层独立流血。满层再次施加时替换剩余时间最短的一层，每层保存施加时的伤害与击杀触发参数。流血跳伤来源单列，不触发直接命中回能或暴击闪电。战吼提供单层临时护甲与即时回能，重复施放刷新持续时间；Q 药剂恢复 35% 最大生命，冷却 10 秒，进入新探险时重置。

## Hub 与探险场景边界

正式新角色流程为 `MainMenu → Hub → ExpeditionRuntime → Hub`。`Hub` 持有当前会话的长期角色状态与据点服务；`ExpeditionRuntime` 负责战斗世界、敌人、地面掉落、技能瞬态与本趟状态。两者通过 SceneRouter 的一次性过渡引用交接 InventoryState、ItemGenerator 与掉落过滤设置，目标场景领取后立即清空引用。

旧 `world/maps/expedition.gd` 暂时保留原 `in_town`、弹窗式整备与 v4 JSON 快照，只用于旧存档兼容、历史回归和下一轮迁移输入。新的据点服务禁止继续接入该旧分支。详细边界见 `docs/hub_refactor.md`。

## 存档

当前仓库仍保留旧 Godot `user://session.json` v4 存档，用于旧角色继续、历史回归和迁移输入。它包含角色、背包、仓库、穿戴、等级、难度以及探险运行状态；`settings.cfg` 独立保存设置。Windows 默认目录：`%APPDATA%/Godot/app_userdata/Relic ARPG/`。

正常 Hub→探险流程已经停止在“出发”时写旧 JSON 据点快照。下一轮存档重构必须使用 Godot Resource，目标为 `PlayerProfileResource`、`RunStateResource`、`SaveGameResource`，开发阶段优先写入 `user://save.tres`。旧 `session.json` 只保留一次性迁移入口；Resource 迁移与回归完成后删除 legacy `in_town` 路径。

旧存档版本为 4；兼容 v2 完整探险与 v3 装配存档。若旧发布包显示“保存失败”，按 F3 打开 DebugLog；旧保存流程会输出 `session.json` 的结构校验、临时文件写入与错误码。完整日志保存在 `user://logs/godot.log`。

## 验证与导出

```bash
python tools/verify.py --godot /path/to/godot
```

在临时用户目录执行编辑器导入、主菜单启动、M0/M1/M2、D1、HubFlow 与 DebugLog 实际场景回归。失败、脚本错误与未出现完成标记均导致非零退出码。测试不会覆盖玩家存档。验证范围与实际结果见 `docs/validation.md`。

安装同版导出模板后：

```bash
godot --headless --path game --editor --import --quit
godot --headless --path game --export-release "Windows Desktop" ../builds/windows/relic_arpg.exe
```

先创建 `builds/windows/`。Windows 产物为内嵌资源的 `relic_arpg.exe`；工作流成功后可下载 `relic-arpg-m2-windows`。发行 smoke 使用正式 `Hub → ExpeditionRuntime` 场景流自动出发，验证导出包可以进入战斗。

## 保留的 M1 测试入口

`world/maps/combat_arena.tscn` 仍可单独运行：1/2 切换测试预设，R 重开 24 怪，F6 生成 100 怪。正式探险入口关闭这些调试快捷键，构筑来自真实穿戴与 Hub 装配。

```bash
godot --headless --path game res://debug/stress_test.tscn -- --stress-seconds=180 --preset=thunder
```

此压力场景验证 M1 战斗，未包含 M2 地面掉落或 D1 流血反馈。无窗口数据覆盖 CPU 与物理；目标机画面、中文字体、音效听感、手感和 GPU 性能仍待实机验证。每趟时长与经济曲线尚未经过玩家试玩调优。

## 文档

| 路径 | 内容 |
| --- | --- |
| `docs/plan.md` | MVP 与 Demo 完整规划 |
| `docs/tasks.md` | 阶段任务状态 |
| `docs/engineering.md` | 当前模块职责与规则 |
| `docs/hub_refactor.md` | 独立 Hub、旧 in_town 兼容边界与 Resource 存档下一步 |
| `docs/assets.md`、`docs/asset_sources.md` | 资产规范与来源 |
| `docs/validation.md` | 自动验证与人工试玩步骤 |
| `docs/work_log.md`、`known_trap.md` | 开发记录与实际问题 |

从本仓库空工程编写，未引入其他业务仓库代码或资源。
