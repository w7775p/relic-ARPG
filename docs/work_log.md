# 工作日志

| 日期 | 任务 | 实际改动 | 验证 | 遗留与下一项 |
| --- | --- | --- | --- | --- |
| 2026-09-09 | M0-01～05 | 从空仓库编写工程、四个服务、主菜单、设置、3D 操控场地、导航、位置存档、中文规范、阶段任务、Windows 导出和工作流 | Godot 4.7.2 无窗口导入、启动与 20 项断言通过；Windows 模板导出成功 | Windows 桌面试玩与视觉未验证；后续 M1 战斗与雷霆旋风 |

工作流的最终执行结果见对应提交的 Actions 页面，不能将已写入的流程视为已通过。

| 日期 | 任务 | 实际改动 | 验证 | 遗留与下一项 |
| --- | --- | --- | --- | --- |
| 2026-09-09 | M1-01～06 | 生命护甲、普攻旋风、能量、三类敌人与精英、闪电感电爆炸、两套预设、战斗 HUD、基础音画、重开与压力脚本 | 原 M0 20 项及 M1 26 项回归；3 分钟 100 怪数据见 m1_performance.md；Windows 状态见 M1 PR | 画面和手感待实机；M2 随机装备、掉落与完整存档 |

| 日期 | 任务 | 实际改动 | 验证 | 遗留与下一项 |
| --- | --- | --- | --- | --- |
| 2026-09-10 | M2-01～04 | 10 底材、12 词条、3 独特资源，实例生成、地面掉落、六槽装备、背包仓库、锁定出售、升级难度、整备循环、版本 2 完整探险存档 | Linux 实际场景回归；M0/M1 保留，M2 新增 46 项；Windows 导出与启动状态见本阶段 PR | 原生几何体占位；目标机视觉、手感、经济与每趟时长待试玩，Demo 后续 D1～D3 |

## P1_Task1：技能装配与被动

从最新 main 313ac7f 创建 feat/p1-task1-loadout，带入任务分支 5945669 的规范与任务卡。完成三个主动槽、六项固定被动、据点调整与属性显示、v3 存档和 v2 迁移。当前功能范围仅本卡。

完成检查：差异与中文注释检查通过；资源、UID 及新场景已纳入；123 项自动回归完成，旧档完整状态及下一次随机一致；保留原 M2 收益/身份回归。图形服务无法建立套接字，可见试玩未验收。架构、README、任务总表、任务卡与验证记录同步；新增真实 JSON 版本比较陷阱。Windows 导出与独立启动通过，结果见下方交付记录。

本轮交付：功能提交 `aaf8b2e7512c491601bc1426b890cd0cb7c9c6ba`，[PR #5](https://github.com/w7775p/relic-ARPG/pull/5)。对应 [Windows 工作流](https://github.com/w7775p/relic-ARPG/actions/runs/34543081309) 的回归、导出与独立启动全部通过；[下载 Windows 构建](https://github.com/w7775p/relic-ARPG/actions/runs/34543081309/artifacts/10178021093)。产物沿用工作流名称 relic-arpg-m2-windows，实际包含本卡功能。本次后续提交仅补验证交接文档，代码与已验证提交相同。可见试玩仍待验收。

## P1_Task2：流血横扫、战吼与恢复药剂

2026-09-11 从 P1_Task1 head `1ff89c7` 建立堆叠分支 `feat/p1-task2-bleed-skills`。完成流血横扫、三层有界流血快照、F 战吼、Q 恢复药剂、HUD 与基础反馈，并将完整探险存档升级到 v4；v2/v3 均可迁移到 v4。实际发现战吼临时护甲会被经验或装备属性重算覆盖，已修复并记录 `P1-02`。

功能验证提交 `0dc446a8fdcce1d014aba6ef8c82457afa3b60c3`。Windows GitHub Actions 使用官方 Godot `4.7.2.stable.official.ed1daf0bf`，M0 20、M1 26、M2 46、P1_Task1 31、P1_Task2 36，共 159 项回归全部通过；Windows 导出成功，导出包独立启动进入 `M2_EXPEDITION_BOOT_READY`。工作流：[run 34552955127](https://github.com/w7775p/relic-ARPG/actions/runs/34552955127)；构建：[artifact 10181489752](https://github.com/w7775p/relic-ARPG/actions/runs/34552955127/artifacts/10181489752)。

本轮交付：[PR #6](https://github.com/w7775p/relic-ARPG/pull/6)，base 为 `feat/p1-task1-loadout`。PR #5 合入后再将 base 调整为 `main`。可见画面、中文排版、声音和实际操作手感待人工试玩，任务状态为待验收。

### P1_Task2 人工验收：保存失败诊断补丁

2026-09-11 用户在 Windows 发布包点击保存后实际看到“保存失败”。自动回归此前只能证明 CI 临时用户目录可写，无法解释用户机器上的具体失败阶段，因此新增 F3 游戏内 DebugLog，常驻于 SceneRouter 下并读取 `user://logs/godot.log`；SaveManager 逐步输出结构校验、临时文件写入/flush、rename、绝对存档路径与错误码。首次实现放在 `debug/` 后被导出过滤规则排除，发布包独立启动捕获 preload 缺失，随后迁到 `ui/debug/`。

修正后的 [run 34557223053](https://github.com/w7775p/relic-ARPG/actions/runs/34557223053) 使用官方 Godot 4.7.2：原 159 项保持通过，新增 DebugLog 6 项通过，共 165 项；Windows 导出与发布包独立启动通过。构建：[artifact 10183010207](https://github.com/w7775p/relic-ARPG/actions/runs/34557223053/artifacts/10183010207)，SHA256 `e84b77a7188f6e79feb6beeff40fc58660501bebbcd22845048325a71d3d4cd4`。用户机器上的原始保存失败原因仍需使用此新包复现并读取 `[DEBUGLOG][ERROR]` 行后定位。

## Hub / in_town 场景拆分

2026-09-11 从最新 main `37750a5` 建立 `refactor/hub-scene`。按可独立验证子任务分别提交：InventoryPanel 地点能力接口、SceneRouter 一次性角色状态交接、独立 Hub 场景、Hub 驱动的 ExpeditionRuntime、正式路由切换、旧 JSON 自动保存解耦、HubFlow 回归和发行 smoke 适配。

正常新角色流程已使用 `MainMenu → Hub → ExpeditionRuntime → Hub`。Hub 负责背包、装备、仓库、出售、技能与被动整备；ExpeditionRuntime 负责战斗世界。撤离和死亡结束当前探险场景并切换回 Hub。旧 `expedition.gd` 中的 `in_town` 与 v4 JSON 据点快照仅保留给旧档兼容、历史回归和下一轮迁移输入，新据点服务禁止继续接入该分支。

代码验证提交 `fba5f85e423c5273e950dbc3e8a4b622ad01b2b9`。Windows [run 34574865158](https://github.com/w7775p/relic-ARPG/actions/runs/34574865158) 的全量场景回归、Windows 导出及导出包独立启动全部通过；构建 [artifact 10189231734](https://github.com/w7775p/relic-ARPG/actions/runs/34574865158/artifacts/10189231734)，SHA256 `e6a0b9a7dfc16a61c8b6b0a20ee27e1757042f3b2a4de87298d6b23151d9ae87`。

下一步为 Resource 存档重构：拆分 `PlayerProfileResource`、`RunStateResource`、`SaveGameResource`，将旧 `session.json` 作为一次性迁移输入；迁移和 Resource 回归完成后删除 `LEGACY_EXPEDITION`、运行期 `in_town` 及仅服务 JSON v4 的兼容代码。详细边界见 `docs/hub_refactor.md`。

## Resource 存档重构 S1（2026-09-11）

从 `30b85f0` 建立 `feat/resource-save`。新增角色、物品、经济、进度、据点五个 Resource 模块、嵌套实例/词条/装配、GameSession 和按依赖恢复的注册协议。基线原有回归通过；Godot 4.7.2 导入与 ResourceModel 13 项通过。现有玩法暂未切换；下一步为完整检查点存储和多槽位。进度见 `resource_save_task.md`。

## Resource 存档重构 S2（2026-09-12）

新增 SaveStore、可重建索引、槽位摘要、读回字段摘要；真实 Resource 写入/读回、多角色和手动槽隔离、自动最近三版、无效模块拒绝覆盖、索引重建通过。保存使用同目录 pending 文件，替换前保留旧文件恢复副本。旧系统仍运行，下一阶段统一接入正式业务和场景。

## Resource 存档重构 S3～S5（2026-09-12）

InventoryState 和 LoadoutState 改为所属 Resource 的事务入口；实例表以 ID 保存唯一归属，独特装备使用稳定内容 ID，掉落种子/状态/计数归物品模块。SceneRouter 一次性交接 GameSession。Hub 接入手动槽、自动保存、回退和保存后离场；正式探险直接继承 combat_arena，结算一次后切回 Hub。移除旧 expedition、SaveValidator、SessionSnapshot 及 JSON 保存。

模块类型切换与场景/回归存在编译依赖，因此 S3～S5 作为可运行集成提交。Godot 4.7.2 的九个实际场景验证全部通过（ResourceModel、ResourceStore、M0、M1、M2、Loadout、BleedSkills、HubFlow、DebugConsole）。保留物品、收益、技能时序规则测试；退休旧位置/战斗恢复及 JSON 迁移断言，新增完整 Hub 回退、新探险重建与去抖断言。后续故障、规模、Windows 与可见 UI 验证尚待执行。

## Resource 存档重构 S6a（2026-09-12）

新增七个隔离进程，实际制造临时文件不可写、正式文件替换失败、损坏正文、缺失内容 ID、索引失败、未提交 pending 和正常探险退出。验证失败时保留当前状态和旧档、手动选择回退、重试成功后离场、索引重建及读取不自动覆盖。补充旧模块版本一真实文件升级为版本二，保留原文件；索引成功路径直接更新摘要，避免每次保存重读全部正文。

实际发现 `.tres` 的浮点十进制舍入会误判读回失败，以及默认版本值被 ResourceSaver 省略会使后续升级失效；修复和回归见 `known_trap.md` SAVE-01/02。完整 `tools/verify.py` 在 Godot 4.7.2 通过导入、启动、10 个常规场景与 7 个故障进程。另测 10000 件装备：约 5.88 MB，保存 4869.63 ms，读取 2349.67 ms，测量时保留堆内存增量 95598572 字节（包含快照与恢复对象，不是峰值）。当前同步 `.tres` 在该规模存在明显停顿，后续大数据需求需另做性能阶段。可见 UI 和 Windows 验证待执行。

## Resource 存档重构 S6b：文档与 Windows 验证（2026-09-12）

代码提交 `dc6ab380a7e11ef1a10039dcaaaef370876aad26` 已同步远端；Windows [run 34716201490](https://github.com/w7775p/relic-ARPG/actions/runs/34716201490) 的全量回归、同版模板导出、独立包启动与上传全部成功。构建 [artifact 10304449478](https://github.com/w7775p/relic-ARPG/actions/runs/34716201490/artifacts/10304449478)，压缩产物 SHA256 `ccb21cb034526a1b13a2235bf5565591f24f9dc9a1a90edaacdc110e2db0944b`。

新增 save_system.md，同步 README、工程、Hub、总体计划、任务总表、验证与后续任务卡；将旧 JSON/战斗恢复要求改为已冻结的 Resource Hub 检查点、整体回退和新探险重建。已完成 P1 卡和历史验证保留历史标识；本轮未提前实现后续玩法。字段、路径、版本说明与代码核对，文档差异/链接检查后单独提交；人工可见验收仍待执行，下一项为最终差异检查和 PR。

## Resource 最终反馈修正（2026-09-12）

最终差异检查发现 Hub 的出发业务接口在保存失败时仍返回“已出发”，与底部失败状态冲突。改为只有场景切换开始才返回成功，否则返回实际失败消息。真实 pending 写入阻塞覆盖整备面板出发入口，五项故障断言通过；原菜单重试和旧文件保持继续通过。该修复单独提交，之后重新运行 Windows 全量回归和导出，最终交付以新包为准。

## Resource 最终交付（2026-09-12）

最终代码提交 `95d3a0f2269f237c84982eb2f90820db67b87299`，[PR #8](https://github.com/w7775p/relic-ARPG/pull/8)，base main、head feat/resource-save，未合并。对应 [Windows run 34716912163](https://github.com/w7775p/relic-ARPG/actions/runs/34716912163) 全量场景/故障回归、Windows 导出和独立包启动全部通过；构建 [artifact 10305120887](https://github.com/w7775p/relic-ARPG/actions/runs/34716912163/artifacts/10305120887)，压缩产物 SHA256 `048274d00ecab047fdb6523d21a62ddf9b6b082bce1f610aca3a184153a8f848`。

最终差异、脚本中文注释/制表符、资源引用、UID、文档相对链接检查通过；运行代码与测试入口不再引用旧 JSON/in_town/旧探险。功能子任务已分别提交；本次提交仅记录交付，已验证代码未变。可见界面、中文排版、音效听感和操作手感仍待 Windows 人工验收；万件规模同步文本停顿为已知性能限制，详见 save_system.md。下一步使用本轮新包按 validation.md 验收，评审及合并由用户决定。
