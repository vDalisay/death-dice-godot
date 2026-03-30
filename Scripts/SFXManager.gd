extends Node
## Autoload: lightweight sound-effect bus. Play named cues from code.
## Sounds are generated programmatically until real audio files are added.
## Replace _generate_tone() calls with preloaded AudioStream resources later.

const MASTER_VOLUME_DB: float = -6.0
const MAX_POLYPHONY: int = 8

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

func _ready() -> void:
	for i: int in MAX_POLYPHONY:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = MASTER_VOLUME_DB
		add_child(player)
		_players.append(player)


func play_roll() -> void:
	_play_tone(220.0, 0.08, 0.6)


func play_bank() -> void:
	_play_tone(523.0, 0.1, 0.7)
	_play_tone_delayed(659.0, 0.1, 0.7, 0.06)
	_play_tone_delayed(784.0, 0.12, 0.8, 0.12)
	_play_tone_delayed(1047.0, 0.18, 0.9, 0.20)


func play_score_tick() -> void:
	_play_tone(880.0, 0.04, 0.35)


func play_bust() -> void:
	_play_tone(150.0, 0.25, 0.9)


func play_stage_clear() -> void:
	_play_tone(523.0, 0.1, 0.7)
	_play_tone_delayed(659.0, 0.1, 0.7, 0.1)
	_play_tone_delayed(784.0, 0.15, 0.8, 0.2)


func play_explode() -> void:
	_play_tone(440.0, 0.06, 0.5)


func play_close_call() -> void:
	_play_tone(370.0, 0.15, 0.6)
	_play_tone_delayed(330.0, 0.15, 0.6, 0.08)


func play_clean_roll() -> void:
	_play_tone(587.0, 0.1, 0.5)
	_play_tone_delayed(698.0, 0.1, 0.5, 0.08)


func play_shop_purchase() -> void:
	_play_tone(440.0, 0.08, 0.5)
	_play_tone_delayed(554.0, 0.08, 0.5, 0.06)


func play_jackpot() -> void:
	_play_tone(523.0, 0.1, 0.8)
	_play_tone_delayed(659.0, 0.1, 0.8, 0.08)
	_play_tone_delayed(784.0, 0.1, 0.8, 0.16)
	_play_tone_delayed(1047.0, 0.2, 0.9, 0.24)
	_play_tone_delayed(1319.0, 0.25, 1.0, 0.34)


func play_personal_best() -> void:
	_play_tone(698.0, 0.1, 0.7)
	_play_tone_delayed(880.0, 0.12, 0.8, 0.1)
	_play_tone_delayed(1047.0, 0.18, 0.9, 0.2)


func play_achievement_unlock() -> void:
	_play_tone(784.0, 0.08, 0.7)
	_play_tone_delayed(988.0, 0.1, 0.8, 0.08)
	_play_tone_delayed(1175.0, 0.14, 0.9, 0.18)


func play_shop_refresh() -> void:
	_play_tone(330.0, 0.06, 0.4)
	_play_tone_delayed(440.0, 0.06, 0.4, 0.05)


func play_double_down_win() -> void:
	_play_tone(523.0, 0.1, 0.8)
	_play_tone_delayed(659.0, 0.1, 0.8, 0.06)
	_play_tone_delayed(784.0, 0.1, 0.8, 0.12)
	_play_tone_delayed(1047.0, 0.15, 0.9, 0.20)
	_play_tone_delayed(1319.0, 0.2, 1.0, 0.30)
	_play_tone_delayed(1568.0, 0.25, 1.0, 0.42)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _play_tone(frequency: float, duration: float, volume: float) -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % MAX_POLYPHONY
	player.stream = stream
	player.volume_db = MASTER_VOLUME_DB + linear_to_db(volume)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var sample_count: int = int(duration * stream.mix_rate)
	var increment: float = frequency / stream.mix_rate
	var phase: float = 0.0
	for i: int in sample_count:
		var envelope: float = 1.0 - float(i) / float(sample_count)
		var sample: float = sin(phase * TAU) * envelope * 0.3
		playback.push_frame(Vector2(sample, sample))
		phase += increment
		if phase >= 1.0:
			phase -= 1.0


func _play_tone_delayed(frequency: float, duration: float, volume: float, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(
		func() -> void: _play_tone(frequency, duration, volume)
	)
