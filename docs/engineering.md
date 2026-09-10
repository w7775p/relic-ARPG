# 当前工程实现

引擎实测：`4.7.2.stable.official.ed1daf0bf`；导出模板：4.7.2 stable；语言：GDScript；插件：无。M0 使用兼容渲染器，原生几何体已足以验证操控与场景流程；M1 的闪电、爆炸与怪群负载确定后再评估 Forward+。目标 Windows 电脑型号、显卡与驱动待提供。

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
