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
