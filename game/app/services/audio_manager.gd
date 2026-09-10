extends Node
## 播放 M0 界面与闪避提示音；短音由原生 WAV 资源生成。

var _player: AudioStreamPlayer
var _cue: AudioStreamWAV


## 生成带淡出的短音，避免依赖外部音效资产。
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "SFX"
	add_child(_player)
	_cue = AudioStreamWAV.new()
	_cue.format = AudioStreamWAV.FORMAT_16_BITS
	_cue.mix_rate = 22050
	var samples: int = 2205
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for index: int in range(samples):
		var envelope: float = sin(PI * float(index) / samples)
		var value: int = int(sin(TAU * 660.0 * index / 22050.0) * envelope * 4500.0)
		data.encode_s16(index * 2, value)
	_cue.data = data
	_player.stream = _cue


## 播放短提示；闪避可传入较低音高。
func play_cue(pitch: float = 1.0) -> void:
	_player.pitch_scale = pitch
	_player.play()
