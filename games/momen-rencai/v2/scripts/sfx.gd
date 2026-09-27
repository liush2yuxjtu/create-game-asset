extends Node
## 音效与 BGM。合成音（tools/gen_audio.py）+ Kenney CC0 打击/界面音（借自 gdquest godot-open-rpg）。
## 录屏（Movie Maker）会把这里的声音一起录进视频。

const FILES := {
	"death": "sfx_death.wav", "awaken": "sfx_awaken.wav", "reveal": "sfx_reveal.wav", "blip": "sfx_blip.wav",
	"type": "sfx_type.wav", "heart": "sfx_heart.wav", "whoosh": "sfx_whoosh.wav", "coin": "sfx_coin.wav",
	"wrong": "sfx_wrong.wav",
	"slash": "chop.ogg", "hit": "impactWood_light_002.ogg", "ok": "confirmation_002.ogg", "err": "error_006.ogg",
	"door": "doorOpen_2.ogg", "drop": "drop_002.ogg",
}
var streams := {}
var players: Array = []
var bgm: AudioStreamPlayer
var muted := false
var _type_cd := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		muted = true   # 无头自测不出声，也避免退出时音频资源未释放
	for k in FILES:
		var s = load("res://assets/audio/" + FILES[k])
		if s:
			streams[k] = s
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	var b = load("res://assets/audio/bgm_loop.wav")
	if b is AudioStreamWAV:
		b.loop_mode = AudioStreamWAV.LOOP_FORWARD
		b.loop_begin = 0
		b.loop_end = b.data.size() / 2
	bgm.stream = b
	bgm.volume_db = -9.0
	AudioServer.set_bus_volume_db(0, -4.0)


func _process(d: float) -> void:
	_type_cd -= d


func play(k: String, vol_db := 0.0, pitch := 1.0) -> void:
	if muted or not streams.has(k):
		return
	if k == "type":
		if _type_cd > 0: return
		_type_cd = 0.045
	for p in players:
		if not p.playing:
			p.stream = streams[k]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return


func music(on: bool) -> void:
	if on and not bgm.playing and not muted:
		bgm.play()
	elif not on:
		bgm.stop()
