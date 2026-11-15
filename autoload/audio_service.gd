extends Node
## Sound effect playback. Effects are synthesized on a worker thread at
## startup so launch is never blocked; calls made before that are dropped.

const POOL_SIZE: int = 8
const SAVE_KEY_ENABLED: String = "sfx_enabled"

var sfx_enabled: bool = true

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _build_task: int = -1


func _ready() -> void:
	sfx_enabled = SaveService.get_bool(SAVE_KEY_ENABLED, true)
	for index: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_task = WorkerThreadPool.add_task(_build_streams)


func _exit_tree() -> void:
	# Never let the worker call back into a freed node on a quick exit.
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1


func set_enabled(value: bool) -> void:
	sfx_enabled = value
	SaveService.set_value(SAVE_KEY_ENABLED, value)
	SaveService.save_to_disk()


func is_ready() -> bool:
	return not _streams.is_empty()


func play_sfx(sfx_name: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx_enabled or not _streams.has(sfx_name):
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = _streams[sfx_name]
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.play()


func _build_streams() -> void:
	_on_streams_built.call_deferred(SfxSynth.build_all())


func _on_streams_built(streams: Dictionary[StringName, AudioStreamWAV]) -> void:
	_streams = streams
