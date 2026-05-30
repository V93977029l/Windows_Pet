class_name AudioManager
extends Node

## ============================================================================
## core/services/audio_manager.gd — 音频管理器
## ============================================================================
## 【架构定位】
##   统一管理游戏中的所有音频播放，提供音量控制、音效/背景音乐
##   分离、音频资源缓存等功能。其他模块通过 EventBus 发布
##   play_sound / play_music 事件来请求播放音频，而非直接调用。
##
## 【核心职责】
##   1. 音效（SFX）与背景音乐（BGM）的独立控制
##   2. 全局音量管理（主音量/SFX音量/BGM音量）
##   3. 音频资源缓存池（避免重复加载）
##   4. 通过 EventBus 接收播放请求
##
## 【使用方式】
##   外部模块发布事件:
##     EventBus.publish("play_sound", {"path": "res://path/to/sfx.wav"})
##     EventBus.publish("play_music", {"path": "res://path/to/bgm.ogg", "fade_in": 1.0})
##   直接调用（仅限 core 内部）:
##     AudioManager.play_sfx("res://path/to/sfx.wav")
##     AudioManager.play_bgm("res://path/to/bgm.ogg")
## ============================================================================

signal volume_changed(bus: String, value: float)

enum AudioBus { MASTER, SFX, BGM }

const BUS_NAMES := {
	AudioBus.MASTER: "Master",
	AudioBus.SFX: "SFX",
	AudioBus.BGM: "BGM"
}

var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var _audio_cache: Dictionary = {}
var _max_sfx_players: int = 8
var _master_volume: float = 1.0:
	set(v):
		_master_volume = clampf(v, 0.0, 1.0)
		_set_bus_volume(AudioBus.MASTER, _master_volume)
		volume_changed.emit("master", _master_volume)
var _sfx_volume: float = 1.0:
	set(v):
		_sfx_volume = clampf(v, 0.0, 1.0)
		_set_bus_volume(AudioBus.SFX, _sfx_volume)
		volume_changed.emit("sfx", _sfx_volume)
var _bgm_volume: float = 1.0:
	set(v):
		_bgm_volume = clampf(v, 0.0, 1.0)
		_set_bus_volume(AudioBus.BGM, _bgm_volume)
		volume_changed.emit("bgm", _bgm_volume)

func _ready() -> void:
	_setup_audio_buses()
	_setup_players()
	_connect_events()

func _setup_audio_buses() -> void:
	for bus_id in BUS_NAMES:
		var bus_name: String = BUS_NAMES[bus_id]
		var idx := AudioServer.get_bus_index(bus_name)
		if idx == -1:
			AudioServer.add_bus(AudioServer.get_bus_count())
			var new_idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(new_idx, bus_name)
			if bus_id == AudioBus.MASTER:
				AudioServer.set_bus_send(new_idx, "Master")
			else:
				AudioServer.set_bus_send(new_idx, BUS_NAMES[AudioBus.MASTER])

func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_NAMES[AudioBus.BGM]
	add_child(_bgm_player)

	for i in range(_max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAMES[AudioBus.SFX]
		add_child(player)
		_sfx_players.append(player)

func _connect_events() -> void:
	if has_node("/root/EventBus"):
		var eb := get_node("/root/EventBus")
		eb.subscribe("play_sound", _on_play_sound)
		eb.subscribe("play_music", _on_play_music)
		eb.subscribe("stop_music", _on_stop_music)

func _set_bus_volume(bus_id: AudioBus, value: float) -> void:
	var bus_name: String = BUS_NAMES[bus_id]
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db := linear_to_db(value) if value > 0.0 else -80.0
		AudioServer.set_bus_volume_db(idx, db)

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var oldest := _sfx_players[0]
	for player in _sfx_players:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	oldest.stop()
	return oldest

func _load_audio(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path]

	if not ResourceLoader.exists(path):
		push_error("[AudioManager] 音频资源不存在: " + path)
		return null

	var stream: AudioStream = load(path)
	if stream:
		_audio_cache[path] = stream
	return stream

## 播放音效
## @param path: 音频资源路径
## @param volume_db: 音量偏移（dB），默认 0
## @param pitch_scale: 音高缩放，默认 1.0
func play_sfx(path: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := _load_audio(path)
	if not stream:
		return

	var player := _get_available_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

## 播放背景音乐
## @param path: 音频资源路径
## @param fade_in: 淡入时间（秒），默认 0（立即播放）
func play_bgm(path: String, fade_in: float = 0.0) -> void:
	var stream := _load_audio(path)
	if not stream:
		return

	if fade_in > 0.0 and _bgm_player.playing:
		_bgm_player.stream = stream
		_bgm_player.volume_db = -40.0
		_bgm_player.play()
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", 0.0, fade_in)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = 0.0
		_bgm_player.play()

## 停止背景音乐
## @param fade_out: 淡出时间（秒），默认 0（立即停止）
func stop_bgm(fade_out: float = 0.0) -> void:
	if fade_out > 0.0 and _bgm_player.playing:
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", -40.0, fade_out)
		tween.tween_callback(_bgm_player.stop)
	else:
		_bgm_player.stop()

func _on_play_sound(payload: Dictionary) -> void:
	var path: String = payload.get("path", "")
	if path.is_empty():
		return
	play_sfx(path, payload.get("volume_db", 0.0), payload.get("pitch_scale", 1.0))

func _on_play_music(payload: Dictionary) -> void:
	var path: String = payload.get("path", "")
	if path.is_empty():
		return
	play_bgm(path, payload.get("fade_in", 0.0))

func _on_stop_music(payload: Dictionary) -> void:
	stop_bgm(payload.get("fade_out", 0.0))

## 设置主音量 (0.0 ~ 1.0)
func set_master_volume(value: float) -> void:
	_master_volume = value

## 设置音效音量 (0.0 ~ 1.0)
func set_sfx_volume(value: float) -> void:
	_sfx_volume = value

## 设置背景音乐音量 (0.0 ~ 1.0)
func set_bgm_volume(value: float) -> void:
	_bgm_volume = value

## 获取主音量
func get_master_volume() -> float:
	return _master_volume

## 获取音效音量
func get_sfx_volume() -> float:
	return _sfx_volume

## 获取背景音乐音量
func get_bgm_volume() -> float:
	return _bgm_volume

## 清除音频缓存（释放内存）
func clear_cache() -> void:
	_audio_cache.clear()

## 暂停所有音频
func pause_all() -> void:
	for player in _sfx_players:
		player.stream_paused = true
	_bgm_player.stream_paused = true

## 恢复所有音频
func resume_all() -> void:
	for player in _sfx_players:
		player.stream_paused = false
	_bgm_player.stream_paused = false
