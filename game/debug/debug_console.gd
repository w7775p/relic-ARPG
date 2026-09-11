extends CanvasLayer
## 游戏内 DebugLog 控制台；F3 打开后实时读取 Godot 当前会话日志。

const LOG_PATH: String = "user://logs/godot.log"
const MAX_CHARS: int = 120000
const REFRESH_SEC: float = 0.25

var _panel: PanelContainer
var _text: TextEdit
var _refresh_remaining: float = 0.0


## 创建覆盖层并保持暂停时也能查看日志。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_build_ui()
	print("[DEBUGLOG][INFO] 游戏内控制台已启动；F3 打开/关闭")


## 控制台显示期间定时刷新当前日志文件。
func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = REFRESH_SEC
		refresh_log()


## F3 在任何场景与暂停状态下切换控制台。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console"):
		toggle_console()
		get_viewport().set_input_as_handled()


## 打开或关闭覆盖层；打开时立即读取最新日志。
func toggle_console() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_remaining = 0.0
		refresh_log()
		_text.grab_focus()
	else:
		_text.release_focus()


## 从 Godot 文件日志读取尾部内容，便于发布包直接排错。
func refresh_log() -> void:
	if _text == null:
		return
	var content: String = ""
	if FileAccess.file_exists(LOG_PATH):
		content = FileAccess.get_file_as_string(LOG_PATH)
	else:
		content = "日志文件尚未创建：%s" % ProjectSettings.globalize_path(LOG_PATH)
	if content.length() > MAX_CHARS:
		content = "[仅显示最后 %d 个字符]\n" % MAX_CHARS + content.right(MAX_CHARS)
	_text.text = content
	_text.scroll_vertical = _text.get_line_count()


## 使用原生 Control 构造只读控制台，避免增加额外场景依赖。
func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugConsolePanel"
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 24.0
	_panel.offset_top = 24.0
	_panel.offset_right = -24.0
	_panel.offset_bottom = -24.0
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var header: Label = Label.new()
	header.text = "DebugLog · F3 关闭 · Ctrl+C 可复制选中文本\n日志：%s" % ProjectSettings.globalize_path(LOG_PATH)
	rows.add_child(header)

	_text = TextEdit.new()
	_text.editable = false
	_text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0.0, 420.0)
	rows.add_child(_text)
